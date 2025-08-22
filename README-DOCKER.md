# 🎵 Tunefy - Guía de Docker

Esta guía te ayudará a ejecutar Tunefy usando Docker y Docker Compose.

## 📋 Requisitos Previos

- **Docker Desktop** instalado y ejecutándose
- **Docker Compose** (incluido con Docker Desktop)
- **Git** (para clonar el repositorio)

### Instalación de Docker Desktop:
- **Windows/Mac**: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux**: [Docker Engine](https://docs.docker.com/engine/install/) + [Docker Compose](https://docs.docker.com/compose/install/)

## 🚀 Inicio Rápido

### Opción 1: Script automático (Recomendado)

**Windows:**
```bash
start.bat
```

**Linux/Mac:**
```bash
chmod +x start.sh
./start.sh
```

### Opción 2: Comandos manuales

```bash
# 1. Construir las imágenes
docker-compose build

# 2. Iniciar todos los servicios
docker-compose up -d

# 3. Ver logs (opcional)
docker-compose logs -f
```

## 🔗 URLs de Acceso

Una vez iniciado, podrás acceder a:

- **🎵 Aplicación Frontend**: http://localhost
- **🔗 API Backend**: http://localhost:3001
- **📊 Health Check**: http://localhost:3001/health
- **🗄️ Base de Datos**: localhost:5432

## 📦 Servicios Incluidos

### 🎯 Frontend (React)
- **Puerto**: 80
- **Tecnología**: React + Nginx
- **Características**: 
  - Build optimizado para producción
  - Compresión gzip
  - Configuración para SPA (Single Page Application)

### ⚙️ Backend (Node.js)
- **Puerto**: 3001
- **Tecnología**: Express.js
- **Características**:
  - API REST completa
  - Integración con PostgreSQL
  - Health checks

### 🗄️ Base de Datos (PostgreSQL)
- **Puerto**: 5432
- **Usuario**: tunefy_user
- **Base de datos**: tunefy
- **Características**:
  - Inicialización automática con scripts SQL
  - Datos persistentes con volúmenes de Docker
  - Health checks

## 🛠️ Comandos Útiles

### Gestión de servicios
```bash
# Iniciar servicios
docker-compose up -d

# Detener servicios
docker-compose down

# Reiniciar un servicio específico
docker-compose restart backend

# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f backend
```

### Desarrollo y debugging
```bash
# Ejecutar comandos dentro de un contenedor
docker-compose exec backend sh
docker-compose exec database psql -U tunefy_user -d tunefy

# Reconstruir una imagen específica
docker-compose build backend
docker-compose build frontend

# Ver estado de los servicios
docker-compose ps

# Ver uso de recursos
docker stats
```

### Limpieza
```bash
# Detener y eliminar contenedores
docker-compose down

# Eliminar también volúmenes (¡CUIDADO! Se perderán los datos)
docker-compose down -v

# Limpiar imágenes no utilizadas
docker image prune

# Limpieza completa del sistema Docker
docker system prune -a
```

## 🔧 Configuración

### Variables de Entorno

Las variables se configuran automáticamente en `docker-compose.yml`, pero puedes modificar:

#### Backend:
- `PGHOST`: Host de la base de datos
- `PGUSER`: Usuario de PostgreSQL
- `PGDATABASE`: Nombre de la base de datos
- `AI21_TOKEN`: Token para el servicio AI21
- `GOOGLE_KEY`: Clave de la API de Google/YouTube

#### Frontend:
- `REACT_APP_BACKEND_URL`: URL del backend
- `REACT_APP_GOOGLE_KEY`: Clave de Google para el frontend

### Puertos Personalizados

Para cambiar puertos, modifica `docker-compose.yml`:

```yaml
services:
  frontend:
    ports:
      - "8080:80"  # Cambiar puerto del frontend a 8080
  
  backend:
    ports:
      - "3002:3001"  # Cambiar puerto del backend a 3002
```

## 🐛 Solución de Problemas

### Problema: "Port already in use"
```bash
# Ver qué proceso usa el puerto
netstat -tulpn | grep :80

# Detener servicios conflictivos
docker-compose down
```

### Problema: Base de datos no conecta
```bash
# Verificar estado de la base de datos
docker-compose exec database pg_isready -U tunefy_user

# Ver logs de la base de datos
docker-compose logs database

# Reiniciar solo la base de datos
docker-compose restart database
```

### Problema: Backend no responde
```bash
# Verificar health check
curl http://localhost:3001/health

# Ver logs del backend
docker-compose logs backend

# Verificar conectividad con la base de datos
docker-compose exec backend node -e "
const { Pool } = require('pg');
const pool = new Pool({
  user: 'tunefy_user',
  host: 'database',
  database: 'tunefy',
  password: 'tunefy_pass',
  port: 5432,
});
pool.query('SELECT NOW()', (err, res) => {
  console.log(err ? err : res.rows[0]);
  process.exit();
});
"
```

### Problema: Frontend no carga
```bash
# Verificar que nginx esté corriendo
docker-compose exec frontend nginx -t

# Ver logs del frontend
docker-compose logs frontend

# Reconstruir imagen del frontend
docker-compose build frontend
docker-compose up -d frontend
```

## 📊 Monitoreo

### Health Checks
Todos los servicios incluyen health checks:

```bash
# Ver estado de salud
docker-compose ps

# Verificar health check manualmente
curl http://localhost:3001/health
curl http://localhost
```

### Logs Estructurados
```bash
# Ver todos los logs
docker-compose logs

# Filtrar por servicio y tiempo
docker-compose logs --since="1h" backend

# Seguir logs en tiempo real con timestamps
docker-compose logs -f -t
```

## 🚢 Despliegue en Producción

Para producción, considera:

1. **Usar imágenes específicas** en lugar de `latest`
2. **Configurar secrets** para passwords y tokens
3. **Usar volúmenes externos** para persistencia
4. **Configurar proxy reverso** (nginx/traefik)
5. **Implementar SSL/TLS**
6. **Configurar backup** de la base de datos

### Ejemplo de configuración de producción:
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  database:
    image: postgres:15-alpine
    volumes:
      - /var/lib/postgresql/data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## 📝 Notas Adicionales

- Los datos de PostgreSQL se persisten en un volumen Docker
- Los scripts SQL se ejecutan automáticamente al crear la base de datos
- El frontend se sirve a través de nginx optimizado para producción
- Todos los servicios están en la misma red Docker para comunicación interna
- Los health checks aseguran que los servicios estén funcionando correctamente

## 🆘 Soporte

Si encuentras problemas:

1. Verifica que Docker Desktop esté ejecutándose
2. Asegúrate de que los puertos 80, 3001 y 5432 estén disponibles
3. Revisa los logs: `docker-compose logs`
4. Prueba reiniciar los servicios: `docker-compose restart`

¡Feliz desarrollo! 🎵
