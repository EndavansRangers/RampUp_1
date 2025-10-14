# Tunefy Backend - Configuración de Base de Datos

Este directorio contiene los scripts necesarios para configurar la base de datos PostgreSQL para la aplicación Tunefy.

## Archivos incluidos

- `database_setup.sql` - Script SQL para crear las tablas y estructuras necesarias
- `setup.ps1` - Script de PowerShell para automatizar la configuración completa
- `.env.example` - Plantilla del archivo de configuración de variables de entorno

## Requisitos previos

1. **PostgreSQL** instalado y funcionando
   - Descargar desde: https://www.postgresql.org/download/
   - Asegurar que `psql` esté disponible en el PATH

2. **Node.js y npm** instalados
   - Descargar desde: https://nodejs.org/

## Configuración automática (Recomendado)

Ejecuta el script de PowerShell para configuración automática:

```powershell
# Navegar al directorio backend
cd backend

# Ejecutar script de configuración
.\setup.ps1
```

Este script:
- Verifica que PostgreSQL esté instalado
- Crea la base de datos `tunefy`
- Crea el usuario `tunefy_user`
- Ejecuta el script SQL para crear las tablas
- Genera el archivo `.env` con la configuración

## Configuración manual

### 1. Crear base de datos y usuario

```sql
-- Conectar como administrador de PostgreSQL
psql -U postgres

-- Crear usuario
CREATE USER tunefy_user WITH PASSWORD 'tu_password';

-- Crear base de datos
CREATE DATABASE tunefy OWNER tunefy_user;

-- Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE tunefy TO tunefy_user;
ALTER USER tunefy_user CREATEDB;
```

### 2. Crear tablas

```bash
# Conectar a la base de datos y ejecutar el script
psql -U tunefy_user -d tunefy -f database_setup.sql
```

### 3. Configurar variables de entorno

```bash
# Copiar plantilla
cp .env.example .env

# Editar el archivo .env con tus credenciales
```

## Estructura de la base de datos

### Tabla `merged_songs`
Almacena todas las canciones agregadas por los usuarios.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | SERIAL | Clave primaria |
| user_id | VARCHAR(255) | ID del usuario |
| song_name | VARCHAR(500) | Nombre de la canción |
| artist_name | VARCHAR(500) | Nombre del artista |
| popularity | INTEGER | Valor de popularidad (0-100) |
| votes | INTEGER | Contador de votos |
| created_at | TIMESTAMP | Fecha de creación |
| updated_at | TIMESTAMP | Fecha de actualización |

### Tabla `top_songs`
Almacena las 20 canciones más populares.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | SERIAL | Clave primaria |
| user_id | VARCHAR(255) | ID del usuario |
| song_name | VARCHAR(500) | Nombre de la canción |
| artist_name | VARCHAR(500) | Nombre del artista |
| popularity | INTEGER | Valor de popularidad |
| created_at | TIMESTAMP | Fecha de creación |

## Variables de entorno necesarias

```env
# Base de datos
PGHOST=localhost
PGUSER=tunefy_user
PGDATABASE=tunefy
PGPASSWORD=tu_password
PGPORT=5432

# Servidor
PORT=3001
NODE_ENV=development

# Frontend
REACT_server_FRONTEND_URL=localhost:3000

# AI21 (opcional)
AI21_TOKEN=tu_token_aqui
```

## Instalación de dependencias

```bash
npm install
```

## Iniciar el servidor

```bash
npm start
```

## Verificación

Para verificar que todo está funcionando:

1. El servidor debe iniciar sin errores en el puerto 3001
2. Puedes probar los endpoints:
   - `GET http://localhost:3001/playlist` - Obtener playlist
   - `POST http://localhost:3001/create-session` - Crear sesión

## Solución de problemas

### Error de conexión a la base de datos
- Verificar que PostgreSQL esté ejecutándose
- Verificar credenciales en el archivo `.env`
- Verificar que el usuario tenga permisos sobre la base de datos

### Puerto en uso
- Cambiar el puerto en la variable `PORT` del archivo `.env`


