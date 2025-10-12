# ---------- Stage 1: Build ----------
FROM node:18-alpine AS build
WORKDIR /app



# Instalar dependencias con lockfile
COPY package*.json ./
RUN npm ci --no-audit --fund=false

# Copiar código
COPY . .

# Variables de entorno para el build (CRA expone REACT_APP_*)
ARG REACT_APP_BACKEND_URL=/api
ARG REACT_APP_FRONTEND_URL
ARG REACT_APP_GOOGLE_KEY=AIzaSyAAL1GtGXpN3NEgcbRUqQvEzNaRMk740uM
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
# Configuración nginx con proxy al backend usando resolver dinámico
RUN echo 'resolver 10.96.0.10 valid=10s;' > /etc/nginx/conf.d/default.conf && \
    echo 'resolver_timeout 5s;' >> /etc/nginx/conf.d/default.conf && \
    echo 'server {' >> /etc/nginx/conf.d/default.conf && \
    echo '  listen 80;' >> /etc/nginx/conf.d/default.conf && \
    echo '  server_name _;' >> /etc/nginx/conf.d/default.conf && \
    echo '  root /usr/share/nginx/html;' >> /etc/nginx/conf.d/default.conf && \
    echo '  # Proxy API requests to backend service (priority with ^~ prefix)' >> /etc/nginx/conf.d/default.conf && \
    echo '  location ^~ /api {' >> /etc/nginx/conf.d/default.conf && \
    echo '    set $backend "tunefy-backend-service.default.svc.cluster.local";' >> /etc/nginx/conf.d/default.conf && \
    echo '    rewrite ^/api(.*)$ $1 break;' >> /etc/nginx/conf.d/default.conf && \
    echo '    proxy_pass http://$backend;' >> /etc/nginx/conf.d/default.conf && \
    echo '    proxy_http_version 1.1;' >> /etc/nginx/conf.d/default.conf && \
    echo '    proxy_set_header Host $host;' >> /etc/nginx/conf.d/default.conf && \
    echo '    proxy_set_header X-Real-IP $remote_addr;' >> /etc/nginx/conf.d/default.conf && \
    echo '    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /etc/nginx/conf.d/default.conf && \
    echo '  }' >> /etc/nginx/conf.d/default.conf && \
    echo '  # SPA fallback for client-side routing' >> /etc/nginx/conf.d/default.conf && \
    echo '  location / { try_files $uri /index.html; }' >> /etc/nginx/conf.d/default.conf && \
    echo '}' >> /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/ /usr/share/nginx/html/
EXPOSE 80
