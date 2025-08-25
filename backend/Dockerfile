# Backend Dockerfile, usamos una imagen base de node 18 y esta sobre alpine linux (es una version ligera)
FROM node:18-alpine

# Crear directorio de trabajo
WORKDIR /app

# Copiar package.json y package-lock.json, aqui se hace antes para temas de cache
COPY package*.json ./

# Instalar dependencias del package.json aqui solo las de produccion 
RUN npm ci --only=production

# Copiar el resto de archivos al directorio de trabajo 
COPY . .

# Exponer el puerto que es donde esta la api (servicio del backend)
EXPOSE 3001

# Comando para iniciar la aplicación
CMD ["node", "server.cjs"]
