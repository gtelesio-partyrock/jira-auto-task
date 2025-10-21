#!/bin/bash

##############################################################################
# Script para generar archivos YAML compatibles con Jira Y crear tareas
# Lee tareas desde la carpeta 'unprocessed/' y:
# 1. Genera archivos YAML en formato compatible con Jira
# 2. Crea las tareas directamente en Jira
# 3. Crea las subtareas automáticamente
##############################################################################

# Colores para el CLI
TEAL='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Función para escribir en el log
write_log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Función para imprimir mensajes con colores
print_info() {
    echo -e "${TEAL}ℹ ${NC}${1}"
    write_log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}${1}"
    write_log "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}${1}"
    write_log "ERROR" "$1"
}

print_warning() {
    echo -e "${ORANGE}⚠ ${NC}${1}"
    write_log "WARN" "$1"
}

print_header() {
    echo -e "${BOLD}${TEAL}${1}${NC}"
    write_log "INFO" "=== ${1} ==="
}

# Directorios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yml"
TASK_DIR="$SCRIPT_DIR/task"
UNPROCESSED_DIR="$TASK_DIR/unprocessed"
PROCESSED_DIR="$TASK_DIR/processed"
JIRA_COMPATIBLE_DIR="$TASK_DIR/jira-compatible"
LOGS_DIR="$SCRIPT_DIR/logs"

# Crear directorios si no existen
mkdir -p "$JIRA_COMPATIBLE_DIR"
mkdir -p "$LOGS_DIR"

# Archivo de log del día
LOG_FILE="$LOGS_DIR/$(date +"%Y-%m-%d").log"

write_log "INFO" "Iniciando script de generación YAML y creación de tareas en Jira"

# Verificar que existe el archivo de configuración
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "No se encontró el archivo de configuración: $CONFIG_FILE"
    exit 1
fi

# Leer configuración de Jira
print_info "Leyendo configuración..."

# Extraer valores del YAML con la nueva estructura organizada
JIRA_URL=$(grep -A 5 "jira:" "$CONFIG_FILE" | grep "url:" | sed 's/.*url:[[:space:]]*"\([^"]*\)".*/\1/')
JIRA_EMAIL=$(grep -A 5 "jira:" "$CONFIG_FILE" | grep "email:" | sed 's/.*email:[[:space:]]*"\([^"]*\)".*/\1/')
JIRA_TOKEN=$(grep -A 5 "jira:" "$CONFIG_FILE" | grep "api_token:" | sed 's/.*api_token:[[:space:]]*"\([^"]*\)".*/\1/')
PROJECT_KEY=$(grep -A 5 "jira:" "$CONFIG_FILE" | grep "project_key:" | sed 's/.*project_key:[[:space:]]*"\([^"]*\)".*/\1/')

# Validar credenciales
if [ -z "$JIRA_URL" ] || [ -z "$JIRA_EMAIL" ] || [ -z "$JIRA_TOKEN" ] || [ -z "$PROJECT_KEY" ]; then
    print_error "Faltan credenciales en el archivo de configuración"
    print_warning "Asegúrate de configurar: url, email, api_token y project_key"
    exit 1
fi

print_success "Configuración cargada correctamente"
print_info "URL: ${JIRA_URL}"
print_info "Email: ${JIRA_EMAIL}"
print_info "Proyecto: ${PROJECT_KEY}"
echo ""

write_log "INFO" "Configuración - URL: ${JIRA_URL}, Email: ${JIRA_EMAIL}, Proyecto: ${PROJECT_KEY}"

# Crear subdirectorios con el email del usuario
USER_UNPROCESSED_DIR="$UNPROCESSED_DIR/$JIRA_EMAIL"
USER_PROCESSED_DIR="$PROCESSED_DIR/$JIRA_EMAIL"

if [ ! -d "$USER_UNPROCESSED_DIR" ]; then
    print_info "Creando carpeta para el usuario: unprocessed/${JIRA_EMAIL}"
    mkdir -p "$USER_UNPROCESSED_DIR"
fi

if [ ! -d "$USER_PROCESSED_DIR" ]; then
    print_info "Creando carpeta para el usuario: processed/${JIRA_EMAIL}"
    mkdir -p "$USER_PROCESSED_DIR"
fi

# Crear autenticación base64
AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_TOKEN}" | base64)

print_header "═══════════════════════════════════════════════════════"
print_header "    🚀 Generador YAML + Creador de Tareas Jira"
print_header "═══════════════════════════════════════════════════════"
echo ""

# Función para leer un valor de un archivo YAML
read_yaml_value() {
    local file=$1
    local key=$2
    grep "^${key}:" "$file" | cut -d'"' -f2
}

# Función para leer la descripción multilínea de un archivo YAML
read_yaml_description() {
    local file=$1
    
    # Usar un enfoque simple: extraer líneas entre description: y el siguiente campo
    local raw_description=""
    local in_description=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^description:[[:space:]]* ]]; then
            in_description=1
            # Extraer el contenido después de description: "
            raw_description=$(echo "$line" | sed 's/^description:[[:space:]]*"//')
            continue
        fi
        
        # Si estamos en la descripción y encontramos el siguiente campo, parar
        if [ $in_description -eq 1 ] && [[ "$line" =~ ^issue_type: ]] || [[ "$line" =~ ^priority: ]]; then
            break
        fi
        
        # Si estamos en la descripción, agregar la línea
        if [ $in_description -eq 1 ]; then
            raw_description="${raw_description}${line}"$'\n'
        fi
    done < "$file"
    
    # Quitar la comilla final si existe
    raw_description=$(echo "$raw_description" | sed 's/"$//')
    
    # Eliminar prefijos de OpenAI: TÍTULO:, TIPO:, PRIORIDAD:, DESCRIPCIÓN:
    raw_description=$(echo "$raw_description" | \
    sed 's/^TÍTULO:[[:space:]]*//' | \
    sed 's/^TIPO:[[:space:]]*//' | \
    sed 's/^PRIORIDAD:[[:space:]]*//' | \
    sed 's/^DESCRIPCIÓN:[[:space:]]*//')
    
    echo "$raw_description"
}

# Función para separar el texto principal de las listas numeradas
parse_description_and_subtasks() {
    local description=$1
    local temp_file=$(mktemp)
    
    # Convertir \n a saltos de línea reales y guardar en archivo temporal
    echo -e "$description" > "$temp_file"
    
    local main_description=""
    local subtasks=()
    
    # Leer línea por línea
    while IFS= read -r line; do
        # Detectar si es un elemento de lista numerada (1., 2., 3., etc.)
        if [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+ ]]; then
            # Extraer el texto después del número
            local subtask_text=$(echo "$line" | sed 's/^[[:space:]]*[0-9]\+\.\s*//')
            subtasks+=("$subtask_text")
        else
            # Es parte de la descripción principal
            if [ -n "$line" ]; then
                if [ -n "$main_description" ]; then
                    main_description="${main_description}\n${line}"
                else
                    main_description="$line"
                fi
            fi
        fi
    done < "$temp_file"
    
    rm "$temp_file"
    
    # Retornar en formato: main_description|subtask1|subtask2|...
    local result="$main_description"
    for subtask in "${subtasks[@]}"; do
        result="${result}|${subtask}"
    done
    
    echo "$result"
}

# Función para generar archivo YAML compatible con Jira
generate_jira_compatible_yaml() {
    local task_file=$1
    local output_file=$2
    
    # Leer los datos del archivo YAML original
    local summary=$(read_yaml_value "$task_file" "summary")
    local raw_description=$(read_yaml_description "$task_file")
    local issue_type=$(read_yaml_value "$task_file" "issue_type")
    local priority=$(read_yaml_value "$task_file" "priority")
    
    # Valores por defecto
    issue_type=${issue_type:-"Story"}
    priority=${priority:-"Medium"}
    
    # Separar descripción principal de subtareas
    local parsed_data=$(parse_description_and_subtasks "$raw_description")
    local main_description=$(echo "$parsed_data" | cut -d'|' -f1)
    local subtasks=()
    
    # Extraer subtareas
    if [[ "$parsed_data" == *"|"* ]]; then
        IFS='|' read -ra PARTS <<< "$parsed_data"
        for i in "${!PARTS[@]}"; do
            if [ $i -gt 0 ] && [ -n "${PARTS[$i]}" ]; then
                subtasks+=("${PARTS[$i]}")
            fi
        done
    fi
    
    # Crear archivo YAML compatible con Jira
    cat > "$output_file" <<EOF
summary: "${summary}"
description: |
${main_description}
issue_type: "${issue_type}"
priority: "${priority}"
subtasks:
EOF
    
    # Agregar subtareas si existen
    for subtask in "${subtasks[@]}"; do
        if [ -n "$subtask" ]; then
            echo "  - \"${subtask}\"" >> "$output_file"
        fi
    done
    
    echo "Archivo YAML compatible generado: $output_file"
}

# Función para crear una subtarea en Jira
create_jira_subtask() {
    local parent_key=$1
    local subtask_summary=$2
    local project_key=$3
    local auth=$4
    local jira_url=$5
    
    # Escapar comillas en el summary
    local summary_escaped=$(echo "$subtask_summary" | sed 's/"/\\"/g')
    
    # Crear descripción simple para la subtarea
    local description_adf='{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Subtarea del requerimiento principal"}]}]}'
    
    local json_payload=$(cat <<EOF
{
  "fields": {
    "project": {
      "key": "${project_key}"
    },
    "summary": "${summary_escaped}",
    "description": ${description_adf},
    "issuetype": {
      "id": "10002"
    },
    "parent": {
      "key": "${parent_key}"
    }
  }
}
EOF
)
    
    write_log "DEBUG" "Creando subtarea: ${subtask_summary}"
    write_log "DEBUG" "Parent Key: ${parent_key}"
    write_log "DEBUG" "Project Key: ${project_key}"
    write_log "DEBUG" "JSON Payload: ${json_payload}"
    
    # Hacer la petición a la API de Jira
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Basic ${auth}" \
        -H "Content-Type: application/json" \
        -d "${json_payload}" \
        "${jira_url}/rest/api/3/issue")
    
    # Separar el código de estado HTTP
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    write_log "DEBUG" "HTTP Code: ${http_code}"
    write_log "DEBUG" "Response Body: ${body}"
    
    if [ "$http_code" -eq 201 ]; then
        local subtask_key=$(echo "$body" | grep -o '"key":"[^"]*' | sed 's/"key":"//')
        write_log "SUCCESS" "Subtarea creada exitosamente: ${subtask_key}"
        echo "$subtask_key"
        return 0
    else
        write_log "ERROR" "Error al crear subtarea - HTTP ${http_code}"
        write_log "ERROR" "Response: ${body}"
        
        # Intentar mostrar el mensaje de error de Jira
        local error_msg=$(echo "$body" | grep -o '"errorMessages":\[[^]]*\]' | sed 's/"errorMessages":\[//;s/\]//')
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$body" | grep -o '"message":"[^"]*' | sed 's/"message":"//')
        fi
        if [ ! -z "$error_msg" ]; then
            write_log "ERROR" "Mensaje de Jira: ${error_msg}"
        fi
        
        return 1
    fi
}

# Función para crear una tarea en Jira
create_jira_issue() {
    local task_file=$1
    local task_name=$(basename "$task_file")
    
    # Leer los datos del archivo YAML
    local summary=$(read_yaml_value "$task_file" "summary")
    local raw_description=$(read_yaml_description "$task_file")
    local issue_type=$(read_yaml_value "$task_file" "issue_type")
    local priority=$(read_yaml_value "$task_file" "priority")
    
    # Valores por defecto
    issue_type=${issue_type:-"Story"}
    priority=${priority:-"Medium"}
    raw_description=${raw_description:-"Sin descripción"}
    
    write_log "DEBUG" "Datos extraídos - Summary: $summary | Type: $issue_type | Priority: $priority"
    write_log "DEBUG" "Descripción completa: $raw_description"
    
    if [ -z "$summary" ]; then
        print_error "El archivo ${task_name} no tiene un 'summary' válido"
        return 1
    fi
    
    print_info "Procesando: ${BOLD}${task_name}${NC}"
    print_info "Tarea: ${summary}"
    
    write_log "INFO" "Procesando archivo: ${task_name}"
    write_log "INFO" "Summary: ${summary} | Type: ${issue_type} | Priority: ${priority}"
    
    # Separar descripción principal de subtareas
    local parsed_data=$(parse_description_and_subtasks "$raw_description")
    local main_description=$(echo "$parsed_data" | cut -d'|' -f1)
    local subtasks=()
    
    # Extraer subtareas (todo lo que viene después del primer |)
    if [[ "$parsed_data" == *"|"* ]]; then
        IFS='|' read -ra PARTS <<< "$parsed_data"
        for i in "${!PARTS[@]}"; do
            if [ $i -gt 0 ] && [ -n "${PARTS[$i]}" ]; then
                subtasks+=("${PARTS[$i]}")
            fi
        done
    fi
    
    write_log "INFO" "Descripción principal: $main_description"
    write_log "INFO" "Subtareas encontradas: ${#subtasks[@]}"
    
    # Preparar el JSON para la API de Jira
    # Escapar comillas en el summary
    summary_escaped=$(echo "$summary" | sed 's/"/\\"/g')
    
    # Crear descripción en formato ADF con saltos de línea mejorados
    TEMP_FILE=$(mktemp)
    echo "$main_description" > "$TEMP_FILE"
    
    DESCRIPTION_ADF='{"type":"doc","version":1,"content":['
    
    # Procesar cada línea del archivo temporal
    first_paragraph=true
    previous_was_list_item=false
    
    while IFS= read -r line; do
        # Si la línea no está vacía, crear un párrafo
        if [ -n "$line" ]; then
            if [ "$first_paragraph" = true ]; then
                first_paragraph=false
            else
                DESCRIPTION_ADF="${DESCRIPTION_ADF},"
            fi
            
            # Detectar si es un elemento de lista
            local is_list_item=false
            if [[ "$line" =~ ^[[:space:]]*[-*] ]] || [[ "$line" =~ ^[[:space:]]*[0-9]+\. ]]; then
                is_list_item=true
            fi
            
            # Escapar comillas en la línea
            escaped_line=$(echo "$line" | sed 's/"/\\"/g')
            
            # Si es un elemento de lista, agregar párrafo de separación antes
            if [ "$is_list_item" = true ]; then
                DESCRIPTION_ADF="${DESCRIPTION_ADF},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"────────────────────────────────────────\"}]}"
            fi
            
            # Agregar párrafo ADF
            DESCRIPTION_ADF="${DESCRIPTION_ADF}{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"${escaped_line}\"}]}"
            
            # Si es un elemento de lista, agregar párrafo de separación después
            if [ "$is_list_item" = true ]; then
                DESCRIPTION_ADF="${DESCRIPTION_ADF},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"────────────────────────────────────────\"}]}"
            fi
            
            # Actualizar estado
            previous_was_list_item=$is_list_item
        fi
    done < "$TEMP_FILE"

    DESCRIPTION_ADF="${DESCRIPTION_ADF}]}"
    
    # Limpiar archivo temporal
    rm "$TEMP_FILE"
    
    JSON_PAYLOAD=$(cat <<EOF
{
  "fields": {
    "project": {
      "key": "${PROJECT_KEY}"
    },
    "summary": "${summary_escaped}",
    "description": ${DESCRIPTION_ADF},
    "issuetype": {
      "name": "${issue_type}"
    },
    "priority": {
      "name": "${priority}"
    }
  }
}
EOF
)
    
    # Hacer la petición a la API de Jira
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Basic ${AUTH}" \
        -H "Content-Type: application/json" \
        -d "${JSON_PAYLOAD}" \
        "${JIRA_URL}/rest/api/3/issue")
    
    # Separar el código de estado HTTP
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 201 ]; then
        ISSUE_KEY=$(echo "$BODY" | grep -o '"key":"[^"]*' | sed 's/"key":"//')
        print_success "Tarea creada: ${BOLD}${ISSUE_KEY}${NC} - ${summary}"
        echo "           ${TEAL}→${NC} ${JIRA_URL}/browse/${ISSUE_KEY}"
        
        write_log "SUCCESS" "Tarea creada exitosamente - Issue Key: ${ISSUE_KEY} | Summary: ${summary} | URL: ${JIRA_URL}/browse/${ISSUE_KEY}"
        
        # Crear subtareas si existen
        local subtasks_created=0
        if [ ${#subtasks[@]} -gt 0 ]; then
            print_info "Creando ${#subtasks[@]} subtareas..."
            
            for subtask in "${subtasks[@]}"; do
                if [ -n "$subtask" ]; then
                    local subtask_key=$(create_jira_subtask "$ISSUE_KEY" "$subtask" "$PROJECT_KEY" "$AUTH" "$JIRA_URL")
                    if [ $? -eq 0 ] && [ -n "$subtask_key" ]; then
                        print_success "  ✓ Subtarea creada: ${BOLD}${subtask_key}${NC} - ${subtask}"
                        write_log "SUCCESS" "Subtarea creada: ${subtask_key} - ${subtask}"
                        ((subtasks_created++))
                    else
                        print_warning "  ⚠ Error al crear subtarea: ${subtask}"
                        write_log "ERROR" "Error al crear subtarea: ${subtask}"
                    fi
                    
                    # Pequeña pausa entre subtareas
                    sleep 0.5
                fi
            done
            
            print_info "Subtareas creadas: ${subtasks_created}/${#subtasks[@]}"
        fi
        
        # Agregar timestamp al nombre del archivo
        TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
        FILE_NAME="${task_name%.yml}"  # Remover extensión .yml
        NEW_FILE_NAME="${FILE_NAME}-${TIMESTAMP}.yml"
        JIRA_COMPATIBLE_NAME="${FILE_NAME}-jira-compatible-${TIMESTAMP}.yml"
        
        # Generar archivo YAML compatible con Jira (comentado - no necesario)
        # generate_jira_compatible_yaml "$task_file" "$JIRA_COMPATIBLE_DIR/${JIRA_COMPATIBLE_NAME}"
        
        # Mover el archivo original a la carpeta processed del usuario con timestamp
        mv "$task_file" "$USER_PROCESSED_DIR/${NEW_FILE_NAME}"
        print_success "Archivo movido a processed/${JIRA_EMAIL}/${NEW_FILE_NAME}"
        # print_success "Archivo YAML compatible generado: ${JIRA_COMPATIBLE_NAME}"
        
        write_log "INFO" "Archivo procesado movido: ${task_name} -> ${NEW_FILE_NAME}"
        # write_log "INFO" "Archivo YAML compatible generado: ${JIRA_COMPATIBLE_NAME}"
        write_log "INFO" "Resumen: Tarea principal + ${subtasks_created} subtareas creadas"
        
        return 0
    else
        print_error "Error al crear la tarea desde: ${task_name}"
        print_warning "HTTP ${HTTP_CODE}"
        
        write_log "ERROR" "Fallo al crear tarea - Archivo: ${task_name} | HTTP Code: ${HTTP_CODE}"
        
        # Intentar mostrar el mensaje de error de Jira
        ERROR_MSG=$(echo "$BODY" | grep -o '"errorMessages":\[[^]]*\]' | sed 's/"errorMessages":\[//;s/\]//')
        if [ -z "$ERROR_MSG" ]; then
            ERROR_MSG=$(echo "$BODY" | grep -o '"message":"[^"]*' | sed 's/"message":"//')
        fi
        if [ ! -z "$ERROR_MSG" ]; then
            print_warning "Mensaje: ${ERROR_MSG}"
            write_log "ERROR" "Mensaje de Jira: ${ERROR_MSG}"
        fi
        
        # Log del cuerpo de respuesta completo para debugging
        write_log "ERROR" "Response Body: ${BODY}"
        
        # El archivo permanece en unprocessed para reintentarlo después
        print_warning "El archivo permanece en unprocessed/${JIRA_EMAIL}/ para reintentar"
        
        return 1
    fi
}

# Buscar archivos en unprocessed del usuario
TASK_FILES=("$USER_UNPROCESSED_DIR"/*.yml)
TASK_COUNT=0

# Verificar si hay archivos
if [ -e "${TASK_FILES[0]}" ]; then
    TASK_COUNT=${#TASK_FILES[@]}
fi

if [ $TASK_COUNT -eq 0 ]; then
    print_warning "No hay tareas para procesar en la carpeta 'unprocessed/${JIRA_EMAIL}/'"
    print_info "Agrega archivos .yml en la carpeta 'unprocessed/${JIRA_EMAIL}/' con el formato:"
    echo ""
    echo "  summary: \"Nombre de la tarea\""
    echo "  description: \"Descripción detallada\""
    echo "  issue_type: \"Story\""
    echo "  priority: \"Medium\""
    echo ""
    exit 0
fi

print_header "Tareas a procesar: ${TASK_COUNT}"
echo ""

# Procesar cada archivo
CREATED=0
FAILED=0

for task_file in "${TASK_FILES[@]}"; do
    if [ -f "$task_file" ]; then
        if create_jira_issue "$task_file"; then
            ((CREATED++))
        else
            ((FAILED++))
        fi
        echo ""
        
        # Pequeña pausa para no saturar la API
        sleep 1
    fi
done

# Resumen final
echo ""
print_header "═══════════════════════════════════════════════════════"
print_header "    📊 Resumen"
print_header "═══════════════════════════════════════════════════════"
echo ""

print_success "Tareas creadas exitosamente: ${BOLD}${CREATED}${NC}"

write_log "INFO" "Resumen final - Tareas creadas: ${CREATED}, Tareas con errores: ${FAILED}"

if [ $FAILED -gt 0 ]; then
    print_error "Tareas con errores: ${BOLD}${FAILED}${NC}"
    print_warning "Revisa los archivos que permanecen en 'unprocessed/${JIRA_EMAIL}/'"
fi

echo ""
print_info "Tareas procesadas movidas a: ${BOLD}processed/${JIRA_EMAIL}/${NC}"
# print_info "Archivos YAML compatibles generados en: ${BOLD}jira-compatible/${NC}"
print_info "Revisa las tareas en Jira: ${JIRA_URL}/browse/${PROJECT_KEY}"
print_info "Log guardado en: ${BOLD}${LOG_FILE}${NC}"
echo ""

write_log "INFO" "Script finalizado exitosamente"
write_log "INFO" "=========================================="
echo "" >> "$LOG_FILE"
