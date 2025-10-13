# 🚀 Jira Auto Task Creator

Script bash para crear tareas en Jira automáticamente desde archivos YAML individuales organizados por usuario.

## 📋 Características

- ✅ Creación automática de tareas en Jira
- 🔐 Configuración segura mediante archivo YAML
- 👤 Organización de tareas por usuario (email)
- 📁 Sistema de carpetas unprocessed/processed
- 📝 Sistema de logs automático (un archivo por día)
- 🎨 CLI con colores (teal, verde, rojo, naranja)
- 📊 Resumen de tareas creadas
- ⚡ Soporte para múltiples tipos de issues (Task, Story, Bug, etc.)
- 🎯 Configuración de prioridades

## 🛠️ Requisitos

- Bash shell
- `curl` (incluido en macOS por defecto)
- Cuenta de Jira con acceso a la API
- Token de API de Jira

## 📝 Configuración

### 1. Generar un API Token de Jira

1. Ve a [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Haz clic en "Create API token"
3. Dale un nombre (ej: "Auto Task Creator")
4. Copia el token generado

### 2. Configurar el archivo `config.yml`

Edita el archivo `config.yml` con tus credenciales:

```yaml
jira:
  url: "https://tu-dominio.atlassian.net"
  email: "tu-email@ejemplo.com"
  api_token: "tu-token-de-api-aqui"
  project_key: "PROJ"  # Clave del proyecto donde se crearán las tareas

# Las tareas se leen desde la carpeta 'unprocessed/{email}/'
# Después de procesarse, se mueven a 'processed/{email}/'
```

### 3. Crear archivos de tareas

El script organiza las tareas por usuario usando el email del `config.yml`. Crea archivos `.yml` en la carpeta `unprocessed/{tu-email}/`:

**Estructura de carpetas:**
```
jira-auto-task/
├── unprocessed/
│   └── tu-email@ejemplo.com/
│       ├── tarea-1.yml
│       ├── tarea-2.yml
│       └── bug-critico.yml
├── processed/
│   └── tu-email@ejemplo.com/
│       ├── tarea-1-2025-10-13-14-30-45.yml
│       └── tarea-2-2025-10-13-14-31-50.yml
├── logs/
│   ├── 2025-10-13.log
│   └── 2025-10-14.log
└── config.yml
```

> **Nota:** Los archivos procesados incluyen un timestamp (fecha y hora) al final del nombre para llevar registro de cuándo se crearon en Jira.

**Ejemplo de archivo de tarea** (`unprocessed/tu-email@ejemplo.com/implementar-login.yml`):
```yaml
summary: "Implementar autenticación de usuarios"
description: "Crear sistema de login con JWT y refresh tokens"
issue_type: "Task"
priority: "High"
```

### 4. Dar permisos de ejecución al script

```bash
chmod +x create-jira-tasks.sh
```

## 🚀 Uso

Ejecuta el script:

```bash
./create-jira-tasks.sh
```

El script:
1. Leerá la configuración de `config.yml`
2. Creará automáticamente las carpetas `unprocessed/{email}` y `processed/{email}`
3. Se conectará a Jira usando tus credenciales
4. Procesará cada archivo `.yml` en `unprocessed/{email}/`
5. Creará las tareas en Jira
6. Moverá los archivos procesados a `processed/{email}/` agregando timestamp al nombre (YYYY-MM-DD-HH-MM-SS)
7. Mostrará el progreso con colores en el terminal
8. Proporcionará enlaces directos a las tareas creadas

**Ejemplo de archivo procesado:**
- Original: `implementar-login.yml`
- Procesado: `implementar-login-2025-10-13-14-30-45.yml`

## 📝 Sistema de Logs

El script genera logs automáticamente en la carpeta `logs/`:

- **Un archivo por día**: `YYYY-MM-DD.log`
- **Formato de línea**: `[timestamp] [LEVEL] mensaje`
- **Niveles de log**: INFO, SUCCESS, WARN, ERROR

**Ejemplo de log** (`logs/2025-10-13.log`):
```
[2025-10-13 14:30:15] [INFO] Iniciando script de creación de tareas en Jira
[2025-10-13 14:30:15] [INFO] Archivo de log: /path/to/logs/2025-10-13.log
[2025-10-13 14:30:16] [INFO] Configuración - URL: https://example.atlassian.net, Email: user@example.com, Proyecto: SCRUM
[2025-10-13 14:30:16] [INFO] Procesando archivo: tarea-1.yml
[2025-10-13 14:30:16] [INFO] Summary: Implementar login | Type: Task | Priority: High
[2025-10-13 14:30:18] [SUCCESS] Tarea creada exitosamente - Issue Key: SCRUM-123 | Summary: Implementar login | URL: https://example.atlassian.net/browse/SCRUM-123
[2025-10-13 14:30:18] [INFO] Archivo procesado movido: tarea-1.yml -> tarea-1-2025-10-13-14-30-18.yml
[2025-10-13 14:30:20] [INFO] Resumen final - Tareas creadas: 1, Tareas con errores: 0
[2025-10-13 14:30:20] [INFO] Script finalizado exitosamente
[2025-10-13 14:30:20] [INFO] ==========================================

```

Los logs son útiles para:
- Auditoría de tareas creadas
- Debugging de errores
- Historial de ejecuciones
- Tracking de issue keys creados

## 🎨 Colores del CLI

- **Teal/Cyan** 🔵: Información general
- **Verde** 🟢: Operaciones exitosas
- **Rojo** 🔴: Errores
- **Naranja** 🟠: Advertencias y warnings

## 📊 Tipos de Issues Soportados

Puedes usar cualquier tipo de issue que tenga tu proyecto Jira:
- `Task` - Tarea
- `Story` - Historia de usuario
- `Bug` - Error
- `Epic` - Épica
- `Subtask` - Subtarea

## 🎯 Prioridades Disponibles

- `Highest` - Más alta
- `High` - Alta
- `Medium` - Media
- `Low` - Baja
- `Lowest` - Más baja

## 👥 Múltiples Usuarios

El sistema organiza las tareas por email del usuario. Si trabajas con múltiples cuentas de Jira:

1. Cambia el email en `config.yml`
2. Ejecuta el script
3. Se creará automáticamente una nueva carpeta para ese usuario
4. Cada usuario tiene sus propias carpetas `unprocessed/` y `processed/`

## ⚠️ Notas de Seguridad

- **NO** compartas el archivo `config.yml` con tus credenciales
- Agrega `config.yml` a tu `.gitignore` si usas control de versiones
- El API token tiene los mismos permisos que tu cuenta de Jira
- Revoca los tokens que no uses desde tu panel de Atlassian
- Las carpetas de tareas también están en `.gitignore` para proteger información sensible

## 🔧 Ejemplo de `.gitignore`

```
config.yml
logs/*.log
unprocessed/*
processed/*
```

## 🐛 Solución de Problemas

### Error: "No se encontró el archivo de configuración"
- Asegúrate de que `config.yml` está en el mismo directorio que el script

### Error: "No hay tareas para procesar"
- Verifica que tienes archivos `.yml` en `unprocessed/{tu-email}/`
- El script crea automáticamente las carpetas con tu email del `config.yml`

### Error HTTP 401
- Verifica que tu email y API token son correctos
- Asegúrate de que el token no ha expirado

### Error HTTP 400
- Revisa que el `project_key` es correcto
- Verifica que el tipo de issue existe en tu proyecto
- Comprueba que la prioridad es válida

### Error: "Faltan credenciales"
- Asegúrate de que todos los campos en `config.yml` están completos
- Verifica que no hay errores de sintaxis en el YAML

### Las tareas no se mueven a processed/
- Si hubo un error al crear la tarea, el archivo permanece en `unprocessed/` para reintentarlo
- Revisa los mensajes de error en el terminal

## 📚 Recursos

- [Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/)
- [Jira API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens)

## 📄 Licencia

MIT

