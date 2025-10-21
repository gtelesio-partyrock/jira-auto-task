#!/bin/bash

# Script para refinar tareas usando OpenAI API
# Lee archivos YAML de without-formatting y genera versiones refinadas en unprocessed

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
TEAL='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con colores
print_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

print_warning() {
    echo -e "${ORANGE}⚠️  ${1}${NC}"
}

print_info() {
    echo -e "${TEAL}ℹ️  ${1}${NC}"
}

print_header() {
    echo -e "${BOLD}${TEAL}${1}${NC}"
}

# Directorios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yml"
WITHOUT_FORMATTING_DIR="$SCRIPT_DIR/task/without-formatting"
UNPROCESSED_DIR="$SCRIPT_DIR/task/unprocessed"
LOGS_DIR="$SCRIPT_DIR/logs"

# Crear directorio de logs si no existe
mkdir -p "$LOGS_DIR"

# Archivo de log del día
LOG_FILE="$LOGS_DIR/$(date +%Y-%m-%d).log"

# Función para escribir logs
write_log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}" >> "$LOG_FILE"
}

# Función para leer configuración
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Archivo de configuración no encontrado: $CONFIG_FILE"
        exit 1
    fi

    # Leer configuración
    OPENAI_API_KEY=$(grep -A 5 "openai:" "$CONFIG_FILE" | grep "api_key:" | sed 's/.*api_key:[[:space:]]*"\([^"]*\)".*/\1/')
    JIRA_EMAIL=$(grep -A 5 "jira:" "$CONFIG_FILE" | grep "email:" | sed 's/.*email:[[:space:]]*"\([^"]*\)".*/\1/')

    if [ -z "$OPENAI_API_KEY" ]; then
        print_error "openai.api_key no encontrado en $CONFIG_FILE"
        exit 1
    fi

    if [ -z "$JIRA_EMAIL" ]; then
        print_error "email no encontrado en $CONFIG_FILE"
        exit 1
    fi

    print_success "Configuración cargada correctamente"
    write_log "INFO" "Configuración - OpenAI API Key: ${OPENAI_API_KEY:0:10}..., Email: $JIRA_EMAIL"
}

# Función para leer un valor de un archivo YAML
read_yaml_value() {
    local file=$1
    local key=$2
    grep "^${key}:" "$file" | cut -d'"' -f2
}

# Función para leer la descripción de un archivo YAML
read_yaml_description() {
    local file=$1
    # Leer la línea que contiene description: y extraer el valor entre comillas
    grep "^description:" "$file" | sed 's/^description:[[:space:]]*"\(.*\)"$/\1/'
}

# Función para llamar a OpenAI API
call_openai_api() {
    local prompt="$1"
    
    # Crear archivo temporal para el JSON
    local temp_json=$(mktemp)
    
    # Crear el JSON de manera más segura
    cat > "$temp_json" << EOF
{
    "model": "gpt-4",
    "messages": [
        {
            "role": "system",
            "content": "Eres un experto en gestión de proyectos. Refina descripciones de tareas para Jira con estructura clara, alcance, entregables y criterios de aceptación."
        },
        {
            "role": "user",
            "content": "$prompt"
        }
    ],
    "max_tokens": 2000,
    "temperature": 0.7
}
EOF
    
    # Hacer la llamada a la API
    local response=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d @"$temp_json")
    
    # Limpiar archivo temporal
    rm "$temp_json"
    
    # Verificar si hay error en la respuesta
    if echo "$response" | grep -q '"error"'; then
        local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | sed 's/"message":"//g' | sed 's/"$//g')
        echo "ERROR: $error_msg" >&2
        return 1
    fi
    
    # Verificar si la respuesta está vacía
    if [ -z "$response" ]; then
        echo "ERROR: Respuesta vacía de OpenAI API" >&2
        return 1
    fi
    
    # Extraer el contenido de la respuesta usando jq si está disponible, o sed como fallback
    local content
    if command -v jq >/dev/null 2>&1; then
        content=$(echo "$response" | jq -r '.choices[0].message.content')
    else
        # Fallback usando sed para extraer el contenido
        content=$(echo "$response" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
    fi
    
    if [ -z "$content" ]; then
        echo "ERROR: No se pudo extraer contenido de la respuesta" >&2
        echo "DEBUG: Respuesta completa: $response" >&2
        return 1
    fi
    
    echo "$content"
}

# Función para refinar una tarea
refine_task() {
    local task_file=$1
    local task_name=$(basename "$task_file" .yml)
    
    print_info "Procesando: ${BOLD}$task_name.yml${NC}"
    
    # Leer solo la descripción del archivo YAML
    local description=$(read_yaml_description "$task_file")
    
    if [ -z "$description" ]; then
        print_error "El archivo ${task_name}.yml no tiene una 'description' válida"
        return 1
    fi
    
    print_info "Procesando descripción: ${description:0:50}..."
    write_log "INFO" "Procesando archivo: $task_name.yml"
    write_log "INFO" "Description: ${description:0:100}..."
    
    # Crear prompt para OpenAI con template específico para subtareas
    local prompt="Refina esta descripción de tarea para Jira:

$description

Genera una tarea completa siguiendo este formato específico:

TÍTULO: [título claro y conciso]
TIPO: [Task/Story/Bug/Epic]
PRIORIDAD: [Highest/High/Medium/Low/Lowest]
DESCRIPCIÓN: [descripción estructurada con las siguientes secciones:]

Descripción y Objetivo
[Descripción detallada del requerimiento y objetivo principal]

Alcance
[Lista numerada (1., 2., 3., etc.) de SUBTAREAS ESPECÍFICAS Y NO REDUNDANTES que se pueden extraer del requerimiento principal. Cada subtarea debe ser una tarea concreta y específica que contribuya al cumplimiento del objetivo principal. Evita repetir información entre subtareas.]

Criterios de aceptación
[Lista numerada (1., 2., 3., etc.) de condiciones específicas que deben cumplirse para considerar la tarea completada]

Entregables
[Lista numerada (1., 2., 3., etc.) de lo que se debe entregar]

IMPORTANTE: Las subtareas en el Alcance deben ser:
- Específicas y concretas
- No redundantes entre sí
- Extraíbles como tareas independientes
- Contribuyentes al objetivo principal
- Enumeradas con números (1., 2., 3., etc.)

Formato de respuesta:
TÍTULO: [título]
TIPO: [tipo]
PRIORIDAD: [prioridad]
DESCRIPCIÓN:
Descripción y Objetivo
[descripción]

Alcance
1. [Primera subtarea específica y concreta]
2. [Segunda subtarea específica y concreta]
3. [Tercera subtarea específica y concreta]
[etc...]

Criterios de aceptación
1. [Primer criterio específico]
2. [Segundo criterio específico]
3. [Tercer criterio específico]
[etc...]

Entregables
1. [Primer entregable específico]
2. [Segundo entregable específico]
3. [Tercer entregable específico]
[etc...]"

    print_info "Enviando a OpenAI para refinamiento..."
    write_log "INFO" "Enviando tarea a OpenAI API para refinamiento"
    
    # Llamar a OpenAI API
    local refined_content=$(call_openai_api "$prompt")
    local api_exit_code=$?
    
    if [ $api_exit_code -ne 0 ] || [ -z "$refined_content" ]; then
        print_error "Error al obtener respuesta de OpenAI API (exit code: $api_exit_code)"
        write_log "ERROR" "Error al obtener respuesta de OpenAI API para $task_name.yml (exit code: $api_exit_code)"
        write_log "DEBUG" "Respuesta de API: $refined_content"
        return 1
    fi
    
    print_success "Respuesta recibida de OpenAI"
    write_log "SUCCESS" "Respuesta recibida de OpenAI para $task_name.yml"
    
    # Extraer campos de la respuesta de OpenAI
    local extracted_summary=$(echo "$refined_content" | grep -i "^TÍTULO:" | sed 's/^TÍTULO:[[:space:]]*//' | sed 's/^[[:space:]]*//')
    local extracted_type=$(echo "$refined_content" | grep -i "^TIPO:" | sed 's/^TIPO:[[:space:]]*//' | sed 's/^[[:space:]]*//')
    local extracted_priority=$(echo "$refined_content" | grep -i "^PRIORIDAD:" | sed 's/^PRIORIDAD:[[:space:]]*//' | sed 's/^[[:space:]]*//')
    
    # Extraer la descripción limpia (sin los prefijos TÍTULO, TIPO, PRIORIDAD, DESCRIPCIÓN)
    local clean_description=$(echo "$refined_content" | sed '/^TÍTULO:/d' | sed '/^TIPO:/d' | sed '/^PRIORIDAD:/d' | sed 's/^DESCRIPCIÓN:[[:space:]]*//' | sed '/^$/d' | sed 's/^[[:space:]]*//')
    
    # Valores por defecto si no se extraen correctamente
    extracted_summary=${extracted_summary:-"Tarea generada por IA"}
    extracted_type=${extracted_type:-"Task"}
    extracted_priority=${extracted_priority:-"Medium"}
    
    # Crear archivo refinado en unprocessed
    local output_file="$UNPROCESSED_DIR/$JIRA_EMAIL/${task_name}-refinado.yml"
    
    # Convertir la respuesta de OpenAI a formato YAML
    echo "summary: \"$extracted_summary\"" > "$output_file"
    echo "description: \"$clean_description\"" >> "$output_file"
    echo "issue_type: \"$extracted_type\"" >> "$output_file"
    echo "priority: \"$extracted_priority\"" >> "$output_file"
    
    print_success "Archivo refinado creado: ${BOLD}${task_name}-refinado.yml${NC}"
    write_log "SUCCESS" "Archivo refinado creado: $output_file"
    
    # Eliminar el archivo original de without-formatting
    rm "$task_file"
    print_success "Archivo original eliminado: ${BOLD}$task_name.yml${NC}"
    write_log "SUCCESS" "Archivo original eliminado: $task_file"
    
    return 0
}

# Función principal
main() {
    print_header "═══════════════════════════════════════════════════════"
    print_header "    🤖 OpenAI Task Refiner"
    print_header "═══════════════════════════════════════════════════════"
    
    # Cargar configuración
    print_info "Cargando configuración..."
    load_config
    
    # Verificar directorios
    if [ ! -d "$WITHOUT_FORMATTING_DIR" ]; then
        print_error "Directorio without-formatting no encontrado: $WITHOUT_FORMATTING_DIR"
        exit 1
    fi
    
    # Crear directorio unprocessed si no existe
    mkdir -p "$UNPROCESSED_DIR/$JIRA_EMAIL"
    
    # Buscar archivos YAML en without-formatting
    local task_files=($(find "$WITHOUT_FORMATTING_DIR" -name "*.yml" -type f))
    
    if [ ${#task_files[@]} -eq 0 ]; then
        print_warning "No se encontraron archivos YAML en $WITHOUT_FORMATTING_DIR"
        write_log "WARNING" "No se encontraron archivos YAML en $WITHOUT_FORMATTING_DIR"
        exit 0
    fi
    
    print_header "Tareas a refinar: ${#task_files[@]}"
    write_log "INFO" "=== Tareas a refinar: ${#task_files[@]} ==="
    
    local success_count=0
    local error_count=0
    
    # Procesar cada archivo
    for task_file in "${task_files[@]}"; do
        if refine_task "$task_file"; then
            ((success_count++))
        else
            ((error_count++))
        fi
        echo
    done
    
    # Resumen final
    print_header "═══════════════════════════════════════════════════════"
    print_header "    📊 Resumen"
    print_header "═══════════════════════════════════════════════════════"
    
    print_success "Tareas refinadas exitosamente: ${BOLD}$success_count${NC}"
    if [ $error_count -gt 0 ]; then
        print_error "Tareas con errores: ${BOLD}$error_count${NC}"
    fi
    
    print_info "Archivos refinados guardados en: ${BOLD}$UNPROCESSED_DIR/$JIRA_EMAIL/${NC}"
    print_info "Log guardado en: ${BOLD}$LOG_FILE${NC}"
    
    write_log "INFO" "Resumen final - Tareas refinadas: $success_count, Tareas con errores: $error_count"
    write_log "INFO" "Script finalizado exitosamente"
    write_log "INFO" "=========================================="
}

# Ejecutar función principal
main "$@"
