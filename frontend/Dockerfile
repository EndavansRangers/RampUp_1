# Frontend Dockerfile - Multi-stage build

# Etapa 1: Build de la aplicación React
FROM node:18-alpine as build

# Crear directorio de trabajo
WORKDIR /app

# Recibir args desde el build
ARG REACT_APP_BACKEND_URL
ARG REACT_APP_FRONTEND_URL
ARG REACT_APP_GOOGLE_KEY

# Disponibles para npm build
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL \
    REACT_APP_FRONTEND_URL=$REACT_APP_FRONTEND_URL \
    REACT_APP_GOOGLE_KEY=$REACT_APP_GOOGLE_KEY


# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar dependencias
RUN npm ci

# Copiar archivos fuente
COPY . .

# Construir la aplicación para producción
RUN npm run build

# Etapa 2: Servir con nginx
FROM nginx:alpine

# Copiar archivos construidos desde la etapa anterior
COPY --from=build /app/build /usr/share/nginx/html

# Exponer puerto 80
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]
