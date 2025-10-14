#!/bin/bash
# Script de migración de deployment único a Blue/Green
# Para ejecutar en el control plane de producción (i-0f12ff5d9cb9ae302)
# Ejecutar como: sudo -u ubuntu bash migrate-to-bluegreen.sh

set -e

NAMESPACE="default"
CURRENT_DEPLOYMENT="tunefy-backend"
SERVICE_NAME="tunefy-backend-service"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Migración a Blue/Green Deployment - Producción"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Obtener imagen actual
echo "📦 Step 1: Obteniendo imagen actual del deployment..."
CURRENT_IMAGE=$(kubectl get deployment $CURRENT_DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "   Imagen actual: $CURRENT_IMAGE"
echo ""

# 2. Crear deployment Blue con la imagen actual
echo "🔵 Step 2: Creando deployment Blue..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tunefy-backend-blue
  namespace: $NAMESPACE
  labels:
    app: tunefy-backend
    color: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tunefy-backend
      color: blue
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: tunefy-backend
        color: blue
        colorLive: "true"  # Blue será el activo inicialmente
    spec:
      imagePullSecrets:
      - name: ecr-registry
      containers:
      - name: backend
        image: $CURRENT_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3001
          name: http
          protocol: TCP
        env:
        - name: NODE_ENV
          value: production
        - name: PORT
          value: "3001"
        - name: COLOR
          value: "blue"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: port
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: dbname
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: password
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 1
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 1
          failureThreshold: 3
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
EOF

echo "   Esperando que Blue esté listo..."
kubectl rollout status deployment/tunefy-backend-blue -n $NAMESPACE --timeout=5m
echo "   ✅ Deployment Blue creado y listo"
echo ""

# 3. Crear deployment Green en standby
echo "🟢 Step 3: Creando deployment Green (standby)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tunefy-backend-green
  namespace: $NAMESPACE
  labels:
    app: tunefy-backend
    color: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tunefy-backend
      color: green
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: tunefy-backend
        color: green
        colorLive: "false"  # Green en standby
    spec:
      imagePullSecrets:
      - name: ecr-registry
      containers:
      - name: backend
        image: $CURRENT_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3001
          name: http
          protocol: TCP
        env:
        - name: NODE_ENV
          value: production
        - name: PORT
          value: "3001"
        - name: COLOR
          value: "green"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: port
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: dbname
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-db
              key: password
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 1
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 1
          failureThreshold: 3
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
EOF

echo "   Esperando que Green esté listo..."
kubectl rollout status deployment/tunefy-backend-green -n $NAMESPACE --timeout=5m
echo "   ✅ Deployment Green creado y listo"
echo ""

# 4. Actualizar Service para usar selector colorLive
echo "🔀 Step 4: Actualizando Service con selector Blue/Green..."
kubectl patch service $SERVICE_NAME -n $NAMESPACE -p '{"spec":{"selector":{"app":"tunefy-backend","colorLive":"true"}}}'
echo "   ✅ Service actualizado (selector: app=tunefy-backend, colorLive=true)"
echo ""

# 5. Verificar que el tráfico fluye correctamente
echo "🧪 Step 5: Verificando tráfico..."
sleep 5

# Test desde dentro del cluster
TEST_POD=$(kubectl get pods -n $NAMESPACE -l app=tunefy-backend,colorLive=true -o jsonpath='{.items[0].metadata.name}')
echo "   Pod activo con colorLive=true: $TEST_POD"

# Verificar health check
HEALTH_CHECK=$(kubectl exec -n $NAMESPACE $TEST_POD -- curl -s http://localhost:3001/health 2>/dev/null || echo "FAILED")
if [[ "$HEALTH_CHECK" == *"ok"* ]] || [[ "$HEALTH_CHECK" == *"healthy"* ]]; then
  echo "   ✅ Health check OK"
else
  echo "   ⚠️  Health check response: $HEALTH_CHECK"
fi
echo ""

# 6. Mostrar estado actual
echo "📊 Step 6: Estado actual de los deployments..."
kubectl get deployments -n $NAMESPACE -l app=tunefy-backend -o wide
echo ""
kubectl get pods -n $NAMESPACE -l app=tunefy-backend -o wide
echo ""

# 7. Eliminar deployment viejo
echo "🗑️  Step 7: ¿Eliminar deployment viejo '$CURRENT_DEPLOYMENT'? (y/n)"
read -r CONFIRM

if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
  echo "   Eliminando deployment viejo..."
  kubectl delete deployment $CURRENT_DEPLOYMENT -n $NAMESPACE
  echo "   ✅ Deployment viejo eliminado"
else
  echo "   ⚠️  Deployment viejo NO eliminado. Recuerda eliminarlo manualmente después de validar:"
  echo "      kubectl delete deployment $CURRENT_DEPLOYMENT -n $NAMESPACE"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Migración completada exitosamente!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Resumen:"
echo "   - Deployment Blue: ACTIVO (colorLive=true)"
echo "   - Deployment Green: STANDBY (colorLive=false)"
echo "   - Service: $SERVICE_NAME (selector: colorLive=true)"
echo "   - Imagen: $CURRENT_IMAGE"
echo ""
echo "🔄 Próximos pasos:"
echo "   1. Actualizar Octopus deployment process para usar Blue/Green"
echo "   2. Probar deployment con nueva versión"
echo "   3. Verificar switch de tráfico"
echo ""
