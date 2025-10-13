#!/bin/bash

##############################################################################
# Script para crear tareas en Jira automáticamente
# Lee tareas individuales desde la carpeta 'unprocessed/'
# Después de procesarlas, las mueve a 'processed/'
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
UNPROCESSED_DIR="$SCRIPT_DIR/unprocessed"
PROCESSED_DIR="$SCRIPT_DIR/processed"
LOGS_DIR="$SCRIPT_DIR/logs"

# Crear directorio de logs si no existe
mkdir -p "$LOGS_DIR"

# Archivo de log del día
LOG_FILE="$LOGS_DIR/$(date +"%Y-%m-%d").log"

# Verificar que existe el archivo de configuración
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "No se encontró el archivo de configuración: $CONFIG_FILE"
    exit 1
fi

# Verificar que existen los directorios
if [ ! -d "$UNPROCESSED_DIR" ]; then
    print_warning "No existe la carpeta 'unprocessed/', creándola..."
    mkdir -p "$UNPROCESSED_DIR"
fi

if [ ! -d "$PROCESSED_DIR" ]; then
    print_warning "No existe la carpeta 'processed/', creándola..."
    mkdir -p "$PROCESSED_DIR"
fi

print_header "═══════════════════════════════════════════════════════"
print_header "    🚀 Jira Auto Task Creator"
print_header "═══════════════════════════════════════════════════════"
echo ""

write_log "INFO" "Iniciando script de creación de tareas en Jira"
write_log "INFO" "Archivo de log: ${LOG_FILE}"

# Leer configuración de Jira
print_info "Leyendo configuración..."

# Extraer valores del YAML usando una estrategia más simple
JIRA_URL=$(grep "url:" "$CONFIG_FILE" | sed 's/.*url:[[:space:]]*"\([^"]*\)".*/\1/')
JIRA_EMAIL=$(grep "email:" "$CONFIG_FILE" | sed 's/.*email:[[:space:]]*"\([^"]*\)".*/\1/')
JIRA_TOKEN=$(grep "api_token:" "$CONFIG_FILE" | sed 's/.*api_token:[[:space:]]*"\([^"]*\)".*/\1/')
PROJECT_KEY=$(grep "project_key:" "$CONFIG_FILE" | sed 's/.*project_key:[[:space:]]*"\([^"]*\)".*/\1/')

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

# Función para leer un valor de un archivo YAML
read_yaml_value() {
    local file=$1
    local key=$2
    grep "^${key}:" "$file" | cut -d'"' -f2
}

# Función para crear una tarea en Jira
create_jira_issue() {
    local task_file=$1
    local task_name=$(basename "$task_file")
    
    # Leer los datos del archivo YAML
    local summary=$(read_yaml_value "$task_file" "summary")
    local description=$(read_yaml_value "$task_file" "description")
    local issue_type=$(read_yaml_value "$task_file" "issue_type")
    local priority=$(read_yaml_value "$task_file" "priority")
    
    # Valores por defecto
    issue_type=${issue_type:-"Task"}
    priority=${priority:-"Medium"}
    description=${description:-"Sin descripción"}
    
    if [ -z "$summary" ]; then
        print_error "El archivo ${task_name} no tiene un 'summary' válido"
        return 1
    fi
    
    print_info "Procesando: ${BOLD}${task_name}${NC}"
    print_info "Tarea: ${summary}"
    
    write_log "INFO" "Procesando archivo: ${task_name}"
    write_log "INFO" "Summary: ${summary} | Type: ${issue_type} | Priority: ${priority}"
    
    # Preparar el JSON para la API de Jira
    # Escapar comillas y saltos de línea en los textos
    summary_escaped=$(echo "$summary" | sed 's/"/\\"/g' | tr '\n' ' ')
    description_escaped=$(echo "$description" | sed 's/"/\\"/g' | tr '\n' ' ')
    
    # Crear descripción en formato Atlassian Document Format (ADF)
    DESCRIPTION_ADF=$(cat <<EOF
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "${description_escaped}"
        }
      ]
    }
  ]
}
EOF
)
    
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
        
        # Agregar timestamp al nombre del archivo
        TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
        FILE_NAME="${task_name%.yml}"  # Remover extensión .yml
        NEW_FILE_NAME="${FILE_NAME}-${TIMESTAMP}.yml"
        
        # Mover el archivo a la carpeta processed del usuario con timestamp
        mv "$task_file" "$USER_PROCESSED_DIR/${NEW_FILE_NAME}"
        print_success "Archivo movido a processed/${JIRA_EMAIL}/${NEW_FILE_NAME}"
        
        write_log "INFO" "Archivo procesado movido: ${task_name} -> ${NEW_FILE_NAME}"
        
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

# Contar archivos en unprocessed del usuario
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
    echo "  issue_type: \"Task\""
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
print_info "Revisa las tareas en Jira: ${JIRA_URL}/browse/${PROJECT_KEY}"
print_info "Log guardado en: ${BOLD}${LOG_FILE}${NC}"
echo ""

write_log "INFO" "Script finalizado exitosamente"
write_log "INFO" "=========================================="
echo "" >> "$LOG_FILE"
