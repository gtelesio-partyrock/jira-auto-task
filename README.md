# 🚀 Jira Auto Task Creator

Sistema completo para la gestión automatizada de tareas en Jira con integración de OpenAI para refinamiento de requerimientos y creación automática de subtareas reales.

## 📋 Características

- ✅ **Creación automática de tareas en Jira** desde archivos YAML
- 🎯 **Subtareas reales** - Crea Stories con subtareas verdaderas en Jira
- 🤖 **Refinamiento con OpenAI** para mejorar descripciones de tareas
- 📝 **Template optimizado** - Genera subtareas específicas y no redundantes
- 🔐 **Configuración segura** mediante archivo YAML organizado
- 👤 **Organización por usuario** (email) en carpetas separadas
- 📁 **Sistema de carpetas** unprocessed/processed/without-formatting
- 📝 **Sistema de logs automático** (un archivo por día)
- 🎨 **CLI con colores** (teal, verde, rojo, naranja)
- 📊 **Resumen detallado** de operaciones realizadas
- ⚡ **Soporte completo** para tipos de issues (Task, Story, Bug, Epic, etc.)
- 🎯 **Configuración de prioridades** personalizable
- 🔗 **Jerarquía real** - Subtareas vinculadas a la tarea principal

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
├── 📄 generate-jira-yaml.sh          # Script principal para crear tareas y subtareas
├── 📄 create-tasks.sh                # Script original (respaldo)
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
- **`generate-jira-yaml.sh`**: Script principal que crea Stories con subtareas reales en Jira.
- **`create-tasks.sh`**: Script original (mantenido como respaldo).
- **`refine-tasks.sh`**: Refina tareas de `without-formatting/` usando OpenAI con template optimizado.

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

### Crear tareas con subtareas reales en Jira

1. **Crear archivos de tareas** en `task/unprocessed/{tu-email}/`:

```yaml
# task/unprocessed/tu-email@ejemplo.com/implementar-microservicio-usuarios.yml
summary: "Implementar Microservicio de Gestión de Usuarios"
description: "Descripción y Objetivo:
Desarrollar un microservicio completo para la gestión de usuarios del sistema.

Alcance:
1. Crear API REST para CRUD de usuarios.
2. Implementar sistema de autenticación JWT.
3. Desarrollar middleware de autorización por roles.
4. Crear base de datos de usuarios con PostgreSQL.
5. Implementar validaciones de datos de entrada.
6. Crear documentación de la API con Swagger.
7. Desarrollar tests unitarios y de integración.
8. Configurar logging y monitoreo.

Criterios de aceptación:
1. La API debe responder en menos de 200ms para operaciones de lectura.
2. El sistema debe soportar hasta 1000 usuarios concurrentes.
3. Las contraseñas deben encriptarse con bcrypt.
4. Los tokens JWT deben expirar en 24 horas.
5. Debe incluir roles: admin, user, moderator.
6. Las validaciones deben cubrir email, teléfono y datos personales.
7. La documentación debe estar disponible en /docs.
8. Los tests deben tener cobertura mínima del 90%.

Entregables:
1. Código fuente del microservicio.
2. Documentación Swagger de la API.
3. Tests unitarios y de integración.
4. Configuración de base de datos.
5. Sistema de logging y monitoreo."
issue_type: "Story"
priority: "High"
```

2. **Ejecutar el script principal**:

```bash
./generate-jira-yaml.sh
```

3. **Resultado**: Se creará una Story principal con subtareas reales vinculadas en Jira.

### Refinar tareas con OpenAI (Template Optimizado)

1. **Crear tareas simples** en `task/without-formatting/{tu-email}/` (solo description):

```yaml
# task/without-formatting/tu-email@ejemplo.com/tarea-simple.yml
description: "Desarrollar sistema de gestión de eventos para PartyRock que incluya creación de eventos, gestión de tickets, sistema de pagos, chat en tiempo real, notificaciones push, geolocalización, categorización de eventos, sistema de calificaciones, reportes de analytics, integración con redes sociales, sistema de invitaciones, gestión de horarios, validación de capacidad, sistema de descuentos y promociones."
```

2. **Refinar con OpenAI**:

```bash
./refine-tasks.sh
```

3. **Resultado**: El template optimizado genera:
   - **Descripción y Objetivo** - Texto descriptivo
   - **Alcance** - Lista numerada de subtareas específicas y no redundantes
   - **Criterios de aceptación** - Lista numerada de condiciones
   - **Entregables** - Lista numerada de entregables

4. **Las tareas refinadas** aparecerán en `task/unprocessed/{tu-email}/` listas para crear en Jira.
5. **Los archivos originales** se eliminan automáticamente de `without-formatting/` después del procesamiento exitoso.

## 📊 Formato de Archivos de Tarea

### Formato Estándar (para crear directamente en Jira)

```yaml
summary: "Título de la tarea"
description: "Descripción y Objetivo:
[Descripción detallada del requerimiento y objetivo principal]

Alcance:
1. [Primera subtarea específica]
2. [Segunda subtarea específica]
3. [Tercera subtarea específica]

Criterios de aceptación:
1. [Primer criterio específico]
2. [Segundo criterio específico]
3. [Tercer criterio específico]

Entregables:
1. [Primer entregable específico]
2. [Segundo entregable específico]
3. [Tercer entregable específico]"
issue_type: "Story"  # Story para permitir subtareas reales
priority: "High"     # Highest, High, Medium, Low, Lowest
```

### Formato Simple (para refinar con OpenAI)

```yaml
description: "Descripción simple del requerimiento que será refinada por OpenAI"
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

### Opción 1: Flujo Completo con OpenAI
1. **Crear tareas simples** en `without-formatting/` (solo description)
2. **Refinar con OpenAI** → `unprocessed/` (archivo original se elimina)
3. **Crear Story con subtareas** → `processed/` (con timestamp)

### Opción 2: Flujo Directo
1. **Crear tareas completas** en `unprocessed/` (formato estándar)
2. **Crear Story con subtareas** → `processed/` (con timestamp)

### Resultado Final
- ✅ **Story principal** creada en Jira
- ✅ **Subtareas reales** vinculadas a la Story
- ✅ **Jerarquía correcta** en Jira
- ✅ **Archivos procesados** movidos a `processed/`

## 🛡️ Seguridad

- Las credenciales se almacenan en `config.yml` (no versionado)
- Los logs no contienen información sensible
- Los archivos procesados mantienen historial con timestamps

## 🆕 Mejoras Implementadas

### ✅ Subtareas Reales en Jira
- **Stories con subtareas verdaderas** - No más tareas independientes con prefijos
- **Jerarquía correcta** - Subtareas vinculadas a la Story principal
- **ID correcto** - Usa el tipo de issue "Subtask" (ID: 10002) de Jira
- **Navegación fácil** - Estructura clara en la interfaz de Jira

### ✅ Template Optimizado de OpenAI
- **Subtareas específicas** - Genera tareas concretas y no redundantes
- **Numeración consistente** - Todas las secciones usan listas numeradas
- **Formato estructurado** - Descripción y Objetivo, Alcance, Criterios, Entregables
- **Extraíbles** - Cada subtarea puede ser una tarea independiente

### ✅ Scripts Optimizados
- **`generate-jira-yaml.sh`** - Script principal para crear Stories con subtareas
- **`refine-tasks.sh`** - Template mejorado para OpenAI
- **`create-tasks.sh`** - Mantenido como respaldo
- **Eliminación de archivos innecesarios** - No genera archivos YAML compatibles

## 📈 Ejemplos de Uso

### Tarea simple refinada por OpenAI

**Entrada** (`without-formatting/`):
```yaml
description: "Implementar sistema de notificaciones en tiempo real para PartyRock que incluya notificaciones push, email, SMS, webhooks, configuración de preferencias de usuario, plantillas personalizables, programación de envíos, tracking de entregas, analytics de engagement, integración con servicios externos, sistema de colas, retry automático, logging detallado y dashboard de administración."
```

**Salida** (`unprocessed/`):
```yaml
summary: "Implementación del sistema de notificaciones en tiempo real para PartyRock"
description: "Descripción y Objetivo:
El objetivo es desarrollar e implementar un sistema de notificaciones en tiempo real para PartyRock para mejorar la comunicación con los usuarios y aumentar su compromiso.

Alcance:
1. Diseño de la arquitectura del sistema de notificaciones.
2. Implementar notificaciones push.
3. Implementar notificaciones por email.
4. Implementar notificaciones por SMS.
5. Implementar webhooks.
6. Crear sistema de configuración de preferencias de usuario.
7. Implementar plantillas personalizables de notificaciones.
8. Crear sistema de programación de envío de notificaciones.
9. Implementar el tracking de entregas.
10. Implementar analytics de engagement.
11. Integrar con servicios externos.
12. Diseñar e implementar sistema de colas.
13. Implementar retry automático.
14. Implementar logging detallado.
15. Crear dashboard de administración.

Criterios de aceptación:
1. Las notificaciones push, email, SMS, y webhooks son enviadas correctamente.
2. Los usuarios pueden configurar sus preferencias de notificaciones.
3. Las plantillas de notificaciones pueden ser personalizadas.
4. El sistema de programación de envío de notificaciones funciona correctamente.
5. El tracking de entregas y analytics de engagement están correctamente implementados.
6. El sistema de colas, retry automático y logging detallado funcionan correctamente.
7. El dashboard de administración permite un control y seguimiento adecuado del sistema.

Entregables:
1. Documentación detallada del diseño de la arquitectura del sistema.
2. Código fuente de la implementación del sistema de notificaciones.
3. Documentación y manual del usuario para la configuración de preferencias y uso del sistema.
4. Informes de pruebas y resultados que demuestren el correcto funcionamiento del sistema."
issue_type: "Epic"
priority: "High"
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

**Desarrollado para automatizar la gestión de tareas en Jira con subtareas reales y refinamiento inteligente con OpenAI**

## 🎯 Características Principales

- 🎯 **Subtareas Reales** - Crea Stories con subtareas verdaderas en Jira
- 🤖 **IA Optimizada** - Template mejorado para generar subtareas específicas
- 🔗 **Jerarquía Correcta** - Subtareas vinculadas a la Story principal
- 📝 **Formato Estructurado** - Alcance, Criterios y Entregables numerados
- ⚡ **Flujo Eficiente** - Desde descripción simple hasta tareas en Jira