# 🚀 Jira Auto Task Creator

Sistema completo para la gestión automatizada de tareas en Jira con integración de OpenAI para refinamiento de requerimientos.

## 📋 Características

- ✅ **Creación automática de tareas en Jira** desde archivos YAML
- 🤖 **Refinamiento con OpenAI** para mejorar descripciones de tareas
- 🔐 **Configuración segura** mediante archivo YAML organizado
- 👤 **Organización por usuario** (email) en carpetas separadas
- 📁 **Sistema de carpetas** unprocessed/processed/without-formatting
- 📝 **Sistema de logs automático** (un archivo por día)
- 🎨 **CLI con colores** (teal, verde, rojo, naranja)
- 📊 **Resumen detallado** de operaciones realizadas
- ⚡ **Soporte completo** para tipos de issues (Task, Story, Bug, Epic, etc.)
- 🎯 **Configuración de prioridades** personalizable

## 🏗️ Estructura del Proyecto

```
jira-auto-task/
├── 📁 task/                          # Carpeta principal de tareas
│   ├── 📁 unprocessed/               # Tareas pendientes de procesar
│   │   └── 📁 {email}/               # Organizadas por usuario
│   │       ├── 📄 tarea-1.yml        # Archivos de tareas individuales
│   │       └── 📄 tarea-2.yml
│   ├── 📁 processed/                 # Tareas ya creadas en Jira
│   │   └── 📁 {email}/               # Con timestamp en el nombre
│   │       ├── 📄 tarea-1-2025-10-13-14-30-45.yml
│   │       └── 📄 tarea-2-2025-10-13-14-31-12.yml
│   └── 📁 without-formatting/        # Tareas para refinar con OpenAI
│       └── 📁 {email}/               # Descripciones simples
│           └── 📄 tarea-simple.yml
├── 📁 logs/                          # Logs diarios del sistema
│   ├── 📄 2025-10-13.log
│   └── 📄 2025-10-14.log
├── 📄 initialize.sh                  # Script de inicialización
├── 📄 create-tasks.sh                # Script principal para crear tareas
├── 📄 refine-tasks.sh                # Script para refinar con OpenAI
├── 📄 config.yml                     # Configuración principal (credenciales)
├── 📄 config-example.yml             # Ejemplo de configuración
└── 📄 README.md                      # Este archivo
```

### 📂 Explicación de Carpetas

- **`task/unprocessed/`**: Contiene tareas pendientes de ser creadas en Jira. Cada usuario tiene su subcarpeta.
- **`task/processed/`**: Archivos de tareas ya procesadas, movidos automáticamente con timestamp.
- **`task/without-formatting/`**: Tareas con solo descripción simple para refinar con OpenAI (la IA genera automáticamente summary, tipo y prioridad).
- **`logs/`**: Archivos de log diarios con toda la actividad del sistema.

### 🔧 Scripts Disponibles

- **`initialize.sh`**: Script de inicialización que verifica e instala todas las dependencias necesarias.
- **`create-tasks.sh`**: Script principal que lee tareas de `unprocessed/` y las crea en Jira.
- **`refine-tasks.sh`**: Refina tareas de `without-formatting/` usando OpenAI y las guarda en `unprocessed/`.

## 🛠️ Requisitos

- Bash shell
- `curl` (incluido en macOS por defecto)
- `jq` (para parsing de JSON)
- Cuenta de Jira con acceso a la API
- Token de API de Jira
- API Key de OpenAI (opcional, para refinamiento)

## 🚀 Inicio Rápido

### 1. Inicialización Automática

Ejecuta el script de inicialización para verificar e instalar todas las dependencias:

```bash
./initialize.sh
```

Este script:
- ✅ Verifica e instala todas las dependencias necesarias
- 📁 Crea la estructura de directorios requerida
- ⚙️ Configura los archivos de configuración
- 🔧 Otorga permisos de ejecución a los scripts
- 🌐 Verifica la conectividad a las APIs
- 📋 Muestra un resumen completo del sistema

## 📝 Configuración

### 1. Generar credenciales

#### API Token de Jira
1. Ve a [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Haz clic en "Create API token"
3. Dale un nombre (ej: "Auto Task Creator")
4. Copia el token generado

#### API Key de OpenAI (opcional)
1. Ve a [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Crea una nueva API key
3. Copia la clave generada

### 2. Configurar el archivo `config.yml`

Copia `config-example.yml` a `config.yml` y completa con tus credenciales:

```yaml
# Configuración de APIs y servicios
# =================================

# Configuración de Jira
jira:
  url: "https://tu-dominio.atlassian.net"
  email: "tu-email@ejemplo.com"
  api_token: "tu-token-de-api-de-jira-aqui"
  project_key: "PROJ"

# Configuración de OpenAI (opcional)
openai:
  api_key: "tu-api-key-de-openai-aqui"
  model: "gpt-4"
  max_tokens: 2000
  temperature: 0.7

# Configuración de directorios
directories:
  task_folder: "task"
  unprocessed: "task/unprocessed"
  processed: "task/processed"
  without_formatting: "task/without-formatting"
  logs: "logs"
```

## 🚀 Uso

### Crear tareas en Jira

1. **Crear archivos de tareas** en `task/unprocessed/{tu-email}/`:

```yaml
# task/unprocessed/tu-email@ejemplo.com/implementar-login.yml
summary: "Implementar autenticación de usuarios"
description: "Crear sistema de login con JWT y refresh tokens

Alcance:
- Implementar endpoint de login
- Crear middleware de autenticación
- Configurar refresh tokens
- Validar credenciales

Entregables:
- Endpoint POST /auth/login
- Middleware de autenticación
- Documentación de API

Criterios de aceptación:
- Login funcional con email/password
- Tokens JWT seguros
- Refresh token automático"
issue_type: "Task"
priority: "High"
```

2. **Ejecutar el script**:

```bash
./create-tasks.sh
```

### Refinar tareas con OpenAI

1. **Crear tareas simples** en `task/without-formatting/{tu-email}/` (solo description):

```yaml
# task/without-formatting/tu-email@ejemplo.com/tarea-simple.yml
description: "Necesito un dashboard para mostrar estadísticas de usuarios y ventas. Debe ser fácil de usar y mostrar gráficos en tiempo real."
```

2. **Refinar con OpenAI**:

```bash
./refine-tasks.sh
```

3. **Las tareas refinadas** aparecerán en `task/unprocessed/{tu-email}/` listas para crear en Jira.
4. **Los archivos originales** se eliminan automáticamente de `without-formatting/` después del procesamiento exitoso.

## 📊 Formato de Archivos de Tarea

Cada archivo `.yml` debe contener:

```yaml
summary: "Título de la tarea"
description: "Descripción detallada con:
- Alcance específico
- Entregables claros
- Criterios de aceptación"
issue_type: "Task"  # Task, Story, Bug, Epic, etc.
priority: "Medium"  # Highest, High, Medium, Low, Lowest
```

## 🎨 Salida del CLI

El sistema usa colores para facilitar la lectura:

- 🔵 **Teal**: Información general y headers
- 🟢 **Verde**: Operaciones exitosas
- 🔴 **Rojo**: Errores
- 🟠 **Naranja**: Advertencias

## 📝 Sistema de Logs

- **Ubicación**: `logs/YYYY-MM-DD.log`
- **Formato**: `[YYYY-MM-DD HH:MM:SS] [LEVEL] mensaje`
- **Niveles**: INFO, SUCCESS, WARNING, ERROR
- **Rotación**: Un archivo por día

## 🔄 Flujo de Trabajo

1. **Crear tareas simples** en `without-formatting/` (solo description)
2. **Refinar con OpenAI** → `unprocessed/` (archivo original se elimina)
3. **Crear en Jira** → `processed/` (con timestamp)

## 🛡️ Seguridad

- Las credenciales se almacenan en `config.yml` (no versionado)
- Los logs no contienen información sensible
- Los archivos procesados mantienen historial con timestamps

## 📈 Ejemplos de Uso

### Tarea simple refinada por OpenAI

**Entrada** (`without-formatting/`):
```yaml
summary: "Mejorar performance"
description: "La app va lenta"
```

**Salida** (`unprocessed/`):
```yaml
summary: "Mejorar performance"
description: "Optimizar el rendimiento de la aplicación para mejorar la experiencia del usuario.

Alcance:
- Identificar cuellos de botella en el código
- Optimizar consultas a la base de datos
- Implementar caché para consultas frecuentes
- Reducir el tiempo de carga de páginas

Entregables:
- Análisis de performance actual
- Código optimizado
- Documentación de mejoras implementadas

Criterios de aceptación:
- Tiempo de carga reducido en 50%
- Consultas de BD optimizadas
- Caché funcionando correctamente"
```

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

---

**Desarrollado para automatizar la gestión de tareas en Jira**