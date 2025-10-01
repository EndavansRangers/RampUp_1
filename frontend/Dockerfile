# ---------- Stage 1: Build ----------
FROM node:18-alpine AS build
WORKDIR /app



# Instalar dependencias con lockfile
COPY package*.json ./
RUN npm ci --no-audit --fund=false

# Copiar código
COPY . .

# Variables de entorno para el build (CRA expone REACT_APP_*)
ARG REACT_APP_BACKEND_URL
ARG REACT_APP_FRONTEND_URL
ARG REACT_APP_GOOGLE_KEY
ENV REACT_APP_BACKEND_URL=${REACT_APP_BACKEND_URL}
ENV REACT_APP_FRONTEND_URL=${REACT_APP_FRONTEND_URL}
ENV REACT_APP_GOOGLE_KEY=${REACT_APP_GOOGLE_KEY}

# Ajustes de build en CI (evitar ESLint/preflight y warnings como errores)
ENV CI=false \
    DISABLE_ESLINT_PLUGIN=true \
    SKIP_PREFLIGHT_CHECK=true

# Construir artefactos (CRA -> build/)
RUN npm run build

# ---------- Stage 2: Nginx ----------
FROM nginx:alpine
# Fallback SPA (React Router)
RUN echo 'server {' > /etc/nginx/conf.d/default.conf && \
    echo '  listen 80;' >> /etc/nginx/conf.d/default.conf && \
    echo '  server_name _;' >> /etc/nginx/conf.d/default.conf && \
    echo '  root /usr/share/nginx/html;' >> /etc/nginx/conf.d/default.conf && \
    echo '  location / { try_files $uri /index.html; }' >> /etc/nginx/conf.d/default.conf && \
    echo '}' >> /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/ /usr/share/nginx/html/
EXPOSE 80
