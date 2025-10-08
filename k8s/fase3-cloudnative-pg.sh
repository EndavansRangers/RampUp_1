#!/bin/bash
set -e

echo "=========================================="
echo "FASE 3: CloudNativePG Operator"
echo "=========================================="
echo ""

# Verificar conectividad
echo "📡 Verificando conectividad con el cluster..."
if ! kubectl get nodes &>/dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi
echo "✅ Conectado al cluster"
echo ""

# Verificar que existe StorageClass
echo "🔍 Verificando StorageClass..."
if ! kubectl get storageclass gp3 &>/dev/null; then
    echo "❌ Error: StorageClass 'gp3' no encontrado"
    echo "   Ejecuta primero la Fase 1"
    exit 1
fi
echo "✅ StorageClass 'gp3' encontrado"
echo ""

# Verificar namespace tunefy-dev
echo "🔍 Verificando namespace tunefy-dev..."
if ! kubectl get namespace tunefy-dev &>/dev/null; then
    echo "📝 Creando namespace tunefy-dev..."
    kubectl create namespace tunefy-dev
    kubectl label namespace tunefy-dev environment=dev
fi
echo "✅ Namespace tunefy-dev listo"
echo ""

# PASO 1: Instalar CloudNativePG Operator
echo "📦 PASO 1: Instalando CloudNativePG Operator..."
echo ""

# Verificar si ya está instalado
if kubectl get deployment -n cnpg-system cnpg-controller-manager &>/dev/null; then
    echo "⚠️ CloudNativePG Operator ya está instalado"
    echo "🔄 Actualizando a última versión..."
    kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-1.22.0.yaml
else
    echo "📥 Instalando CloudNativePG Operator v1.22.0..."
    kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-1.22.0.yaml
fi

echo ""
echo "⏳ Esperando a que el operador esté listo (60s)..."
sleep 10
kubectl wait --for=condition=available deployment/cnpg-controller-manager \
    -n cnpg-system \
    --timeout=60s 2>/dev/null || echo "   (puede tardar un poco más...)"

echo "✅ CloudNativePG Operator instalado"
echo ""

# PASO 2: Verificar instalación
echo "🔍 PASO 2: Verificando instalación del operador..."
echo ""
echo "Namespace cnpg-system:"
kubectl get all -n cnpg-system
echo ""

# PASO 3: Crear Secret con credenciales de PostgreSQL
echo "🔐 PASO 3: Creando Secret para PostgreSQL..."

# Generar passwords aleatorios si no existen
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
APP_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tunefy-db-credentials
  namespace: tunefy-dev
type: Opaque
stringData:
  username: tunefy_user
  password: $APP_PASSWORD
  postgres-password: $POSTGRES_PASSWORD
EOF

echo "✅ Secret creado: tunefy-db-credentials"
echo ""
echo "📝 Credenciales generadas:"
echo "   Username: tunefy_user"
echo "   App Password: $APP_PASSWORD"
echo "   Postgres Password: $POSTGRES_PASSWORD"
echo ""
echo "⚠️ GUARDA ESTAS CREDENCIALES - Las necesitarás para configurar el backend"
echo ""

# PASO 4: Crear PostgreSQL Cluster
echo "🗄️ PASO 4: Creando PostgreSQL Cluster..."
echo ""

cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: tunefy-db
  namespace: tunefy-dev
spec:
  instances: 2
  imageName: ghcr.io/cloudnative-pg/postgresql:16.1
  
  # Storage configuration
  storage:
    storageClass: gp3
    size: 10Gi
  
  # Bootstrap configuration
  bootstrap:
    initdb:
      database: tunefy
      owner: tunefy_user
      secret:
        name: tunefy-db-credentials
  
  # Resource limits
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  # Monitoring
  monitoring:
    enablePodMonitor: true
  
  # PostgreSQL configuration
  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"
      work_mem: "4MB"
    pg_hba:
      - host all all all scram-sha-256
  
  # High Availability
  primaryUpdateStrategy: unsupervised
  
  # Backup configuration (opcional - requiere S3)
  # backup:
  #   barmanObjectStore:
  #     destinationPath: s3://tunefy-backups/postgresql
  #     s3Credentials:
  #       accessKeyId:
  #         name: aws-credentials
  #         key: ACCESS_KEY_ID
  #       secretAccessKey:
  #         name: aws-credentials
  #         key: SECRET_ACCESS_KEY
  #     wal:
  #       compression: gzip
  #   retentionPolicy: "30d"
EOF

echo "✅ PostgreSQL Cluster creado: tunefy-db"
echo ""

# PASO 5: Esperar a que el cluster esté listo
echo "⏳ PASO 5: Esperando a que PostgreSQL esté listo..."
echo "   Esto puede tardar 2-3 minutos (descargando imagen, creando PVCs, iniciando pods)..."
echo ""

# Monitorear el progreso
for i in {1..12}; do
    echo "   Intento $i/12..."
    
    # Verificar pods
    POD_STATUS=$(kubectl get pods -n tunefy-dev -l cnpg.io/cluster=tunefy-db -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    READY_PODS=$(kubectl get pods -n tunefy-dev -l cnpg.io/cluster=tunefy-db --field-selector=status.phase=Running 2>/dev/null | grep -c "Running" || echo "0")
    
    echo "   Pods Running: $READY_PODS/2"
    
    if [ "$READY_PODS" -eq 2 ]; then
        echo "   ✅ Ambos pods están Running"
        break
    fi
    
    if [ $i -lt 12 ]; then
        sleep 15
    fi
done

echo ""

# PASO 6: Verificar estado del cluster
echo "🔍 PASO 6: Verificando estado del cluster PostgreSQL..."
echo ""

echo "Pods de PostgreSQL:"
kubectl get pods -n tunefy-dev -l cnpg.io/cluster=tunefy-db
echo ""

echo "PVCs creados:"
kubectl get pvc -n tunefy-dev
echo ""

echo "Services creados:"
kubectl get svc -n tunefy-dev -l cnpg.io/cluster=tunefy-db
echo ""

echo "Cluster status:"
kubectl get cluster -n tunefy-dev tunefy-db
echo ""

# PASO 7: Mostrar información de conexión
echo "📋 PASO 7: Información de Conexión"
echo "=========================================="
echo ""
echo "🔌 Connection Endpoints:"
echo ""
echo "Read-Write (Primary):"
echo "  Host: tunefy-db-rw.tunefy-dev.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: tunefy"
echo "  User: tunefy_user"
echo "  Password: (ver secret tunefy-db-credentials)"
echo ""
echo "Read-Only (Replicas):"
echo "  Host: tunefy-db-ro.tunefy-dev.svc.cluster.local"
echo "  Port: 5432"
echo ""
echo "Read (Any instance):"
echo "  Host: tunefy-db-r.tunefy-dev.svc.cluster.local"
echo "  Port: 5432"
echo ""

# PASO 8: Crear ConfigMap con info de conexión
echo "📝 PASO 8: Creando ConfigMap con configuración de DB..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: tunefy-db-config
  namespace: tunefy-dev
data:
  DB_HOST: "tunefy-db-rw.tunefy-dev.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "tunefy"
  DB_USER: "tunefy_user"
EOF

echo "✅ ConfigMap creado: tunefy-db-config"
echo ""

# Verificación final
echo "=========================================="
echo "✅ FASE 3 COMPLETADA"
echo "=========================================="
echo ""
echo "📊 Resumen:"
echo "  • CloudNativePG Operator: Instalado en namespace cnpg-system"
echo "  • PostgreSQL Cluster: tunefy-db (2 instancias)"
echo "  • Storage: 2x 10Gi PVCs (gp3)"
echo "  • Services: 3 endpoints (rw, ro, r)"
echo "  • Secret: tunefy-db-credentials"
echo "  • ConfigMap: tunefy-db-config"
echo ""

# Obtener el password para mostrarlo
APP_PASS=$(kubectl get secret tunefy-db-credentials -n tunefy-dev -o jsonpath='{.data.password}' | base64 -d)
echo "🔑 Credenciales (GUÁRDALAS):"
echo "   Username: tunefy_user"
echo "   Password: $APP_PASS"
echo ""

echo "📝 Variables de entorno para el Backend:"
echo "   DB_HOST=tunefy-db-rw.tunefy-dev.svc.cluster.local"
echo "   DB_PORT=5432"
echo "   DB_NAME=tunefy"
echo "   DB_USER=tunefy_user"
echo "   DB_PASSWORD=$APP_PASS"
echo ""

echo "🧪 Para probar la conexión:"
echo "   kubectl run -it --rm debug --image=postgres:16 --restart=Never -n tunefy-dev -- \\"
echo "     psql -h tunefy-db-rw.tunefy-dev.svc.cluster.local -U tunefy_user -d tunefy"
echo ""

echo "✅ PostgreSQL listo para recibir conexiones del Backend"
echo ""
