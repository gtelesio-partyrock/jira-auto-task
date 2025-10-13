#!/bin/bash

# Script de inicialización para Jira Auto Task Creator
# Verifica e instala todas las dependencias necesarias

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

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para instalar dependencias en macOS
install_dependencies() {
    local missing_deps=()
    
    # Verificar curl
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    # Verificar jq
    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    # Verificar git
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    # Verificar base64
    if ! command_exists base64; then
        missing_deps+=("base64")
    fi
    
    # Verificar awk
    if ! command_exists awk; then
        missing_deps+=("awk")
    fi
    
    # Verificar sed
    if ! command_exists sed; then
        missing_deps+=("sed")
    fi
    
    # Verificar grep
    if ! command_exists grep; then
        missing_deps+=("grep")
    fi
    
    # Verificar cut
    if ! command_exists cut; then
        missing_deps+=("cut")
    fi
    
    # Verificar find
    if ! command_exists find; then
        missing_deps+=("find")
    fi
    
    # Verificar mkdir
    if ! command_exists mkdir; then
        missing_deps+=("mkdir")
    fi
    
    # Verificar rm
    if ! command_exists rm; then
        missing_deps+=("rm")
    fi
    
    # Verificar mv
    if ! command_exists mv; then
        missing_deps+=("mv")
    fi
    
    # Verificar date
    if ! command_exists date; then
        missing_deps+=("date")
    fi
    
    # Verificar mktemp
    if ! command_exists mktemp; then
        missing_deps+=("mktemp")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "Todas las dependencias básicas están disponibles"
        return 0
    fi
    
    print_warning "Faltan las siguientes dependencias: ${missing_deps[*]}"
    
    # Detectar el sistema operativo
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Sistema detectado: macOS"
        
        # Verificar si Homebrew está instalado
        if ! command_exists brew; then
            print_warning "Homebrew no está instalado. Instalando Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Agregar Homebrew al PATH si es necesario
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
        
        print_info "Instalando dependencias con Homebrew..."
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "jq")
                    print_info "Instalando jq..."
                    brew install jq
                    ;;
                "curl"|"git"|"base64"|"awk"|"sed"|"grep"|"cut"|"find"|"mkdir"|"rm"|"mv"|"date"|"mktemp")
                    print_warning "$dep debería estar disponible en macOS por defecto"
                    ;;
                *)
                    print_warning "Dependencia desconocida: $dep"
                    ;;
            esac
        done
        
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_info "Sistema detectado: Linux"
        
        # Detectar el gestor de paquetes
        if command_exists apt-get; then
            print_info "Usando apt-get para instalar dependencias..."
            sudo apt-get update
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "jq")
                        sudo apt-get install -y jq
                        ;;
                    "curl"|"git"|"base64"|"awk"|"sed"|"grep"|"cut"|"find"|"mkdir"|"rm"|"mv"|"date"|"mktemp")
                        print_warning "$dep debería estar disponible en Linux por defecto"
                        ;;
                esac
            done
        elif command_exists yum; then
            print_info "Usando yum para instalar dependencias..."
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "jq")
                        sudo yum install -y jq
                        ;;
                    "curl"|"git"|"base64"|"awk"|"sed"|"grep"|"cut"|"find"|"mkdir"|"rm"|"mv"|"date"|"mktemp")
                        print_warning "$dep debería estar disponible en Linux por defecto"
                        ;;
                esac
            done
        else
            print_error "No se pudo detectar el gestor de paquetes. Instala manualmente: ${missing_deps[*]}"
            return 1
        fi
        
    else
        print_error "Sistema operativo no soportado: $OSTYPE"
        print_info "Instala manualmente las siguientes dependencias: ${missing_deps[*]}"
        return 1
    fi
}

# Función para verificar la estructura de directorios
setup_directories() {
    print_info "Verificando estructura de directorios..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Crear directorios necesarios
    local dirs=(
        "task"
        "task/unprocessed"
        "task/processed"
        "task/without-formatting"
        "logs"
    )
    
    for dir in "${dirs[@]}"; do
        local full_path="$script_dir/$dir"
        if [ ! -d "$full_path" ]; then
            print_info "Creando directorio: $dir"
            mkdir -p "$full_path"
        else
            print_success "Directorio existe: $dir"
        fi
    done
    
    # Crear archivos .gitkeep
    local gitkeep_dirs=(
        "task/unprocessed"
        "task/processed"
        "task/without-formatting"
        "logs"
    )
    
    for dir in "${gitkeep_dirs[@]}"; do
        local gitkeep_file="$script_dir/$dir/.gitkeep"
        if [ ! -f "$gitkeep_file" ]; then
            print_info "Creando .gitkeep en: $dir"
            touch "$gitkeep_file"
        fi
    done
}

# Función para verificar archivos de configuración
check_config_files() {
    print_info "Verificando archivos de configuración..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_file="$script_dir/config.yml"
    local config_example="$script_dir/config-example.yml"
    
    # Verificar config-example.yml
    if [ ! -f "$config_example" ]; then
        print_error "Archivo config-example.yml no encontrado"
        return 1
    else
        print_success "config-example.yml encontrado"
    fi
    
    # Verificar config.yml
    if [ ! -f "$config_file" ]; then
        print_warning "config.yml no encontrado. Copiando desde config-example.yml..."
        cp "$config_example" "$config_file"
        print_success "config.yml creado desde config-example.yml"
        print_warning "IMPORTANTE: Edita config.yml con tus credenciales antes de usar los scripts"
    else
        print_success "config.yml encontrado"
    fi
}

# Función para verificar permisos de ejecución
check_script_permissions() {
    print_info "Verificando permisos de ejecución..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local scripts=("create-tasks.sh" "refine-tasks.sh")
    
    for script in "${scripts[@]}"; do
        local script_path="$script_dir/$script"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                print_success "$script tiene permisos de ejecución"
            else
                print_info "Otorgando permisos de ejecución a $script"
                chmod +x "$script_path"
                print_success "Permisos de ejecución otorgados a $script"
            fi
        else
            print_error "Script no encontrado: $script"
            return 1
        fi
    done
}

# Función para verificar conectividad
check_connectivity() {
    print_info "Verificando conectividad..."
    
    # Verificar conectividad a internet
    if curl -s --max-time 10 https://www.google.com >/dev/null 2>&1; then
        print_success "Conectividad a internet: OK"
    else
        print_warning "No se pudo verificar la conectividad a internet"
    fi
    
    # Verificar conectividad a OpenAI API
    if curl -s --max-time 10 https://api.openai.com >/dev/null 2>&1; then
        print_success "Conectividad a OpenAI API: OK"
    else
        print_warning "No se pudo verificar la conectividad a OpenAI API"
    fi
}

# Función para mostrar resumen final
show_summary() {
    print_header "═══════════════════════════════════════════════════════"
    print_header "    🎉 Inicialización Completada"
    print_header "═══════════════════════════════════════════════════════"
    
    print_success "Sistema preparado para usar Jira Auto Task Creator"
    echo
    print_info "Scripts disponibles:"
    echo "  • ./create-tasks.sh    - Crear tareas en Jira"
    echo "  • ./refine-tasks.sh    - Refinar tareas con OpenAI"
    echo
    print_info "Estructura de directorios:"
    echo "  • task/unprocessed/     - Tareas listas para crear en Jira"
    echo "  • task/processed/       - Tareas ya creadas en Jira"
    echo "  • task/without-formatting/ - Tareas simples para refinar"
    echo "  • logs/                - Archivos de log diarios"
    echo
    print_warning "IMPORTANTE: Edita config.yml con tus credenciales antes de usar los scripts"
    echo
    print_info "Para comenzar:"
    echo "  1. Edita config.yml con tus credenciales de Jira y OpenAI"
    echo "  2. Crea tareas simples en task/without-formatting/{tu-email}/"
    echo "  3. Ejecuta ./refine-tasks.sh para refinar las tareas"
    echo "  4. Ejecuta ./create-tasks.sh para crear las tareas en Jira"
    echo
}

# Función principal
main() {
    print_header "═══════════════════════════════════════════════════════"
    print_header "    🚀 Jira Auto Task Creator - Inicialización"
    print_header "═══════════════════════════════════════════════════════"
    
    # Verificar sistema operativo
    print_info "Sistema operativo: $OSTYPE"
    
    # Instalar dependencias
    print_info "Verificando e instalando dependencias..."
    if ! install_dependencies; then
        print_error "Error al instalar dependencias"
        exit 1
    fi
    
    # Configurar directorios
    print_info "Configurando estructura de directorios..."
    if ! setup_directories; then
        print_error "Error al configurar directorios"
        exit 1
    fi
    
    # Verificar archivos de configuración
    print_info "Verificando archivos de configuración..."
    if ! check_config_files; then
        print_error "Error al verificar archivos de configuración"
        exit 1
    fi
    
    # Verificar permisos de scripts
    print_info "Verificando permisos de scripts..."
    if ! check_script_permissions; then
        print_error "Error al verificar permisos de scripts"
        exit 1
    fi
    
    # Verificar conectividad
    print_info "Verificando conectividad..."
    check_connectivity
    
    # Mostrar resumen
    show_summary
}

# Ejecutar función principal
main "$@"
