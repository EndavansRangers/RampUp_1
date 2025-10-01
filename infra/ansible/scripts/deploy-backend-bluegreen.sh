#!/bin/bash
# Octopus Deploy Helper Script - Backend Blue/Green Deployment
# Este script implementa el flujo completo blue/green

set -e

# Variables de Octopus
VERSION="${1:-${OCTOPUS_RELEASE_NUMBER:-0.0.0-local}}"
COLOR="${2:-${BACKEND_COLOR:-blue}}"
NAMESPACE="${3:-${OCTOPUS_NAMESPACE:-tunefy-dev}}"
CHART_PATH="${4:-/tmp/charts/backend}"
DO_SWITCH="${5:-${DO_SWITCH:-false}}"  # Si es true, hace el switch del service

echo "=================================================="
echo "  Backend Blue/Green Deployment"
echo "=================================================="
echo "Version: $VERSION"
echo "Target Color: $COLOR"
echo "Namespace: $NAMESPACE"
echo "Chart Path: $CHART_PATH"
echo "Auto Switch: $DO_SWITCH"
echo ""

# Validaciones
if [ "$COLOR" != "blue" ] && [ "$COLOR" != "green" ]; then
    echo "❌ Error: COLOR debe ser 'blue' o 'green'"
    exit 1
fi

if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Error: Chart no encontrado en $CHART_PATH"
    exit 1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "⚠️  Namespace $NAMESPACE no existe, creándolo..."
    kubectl create namespace "$NAMESPACE"
fi

if ! kubectl get secret ecr-creds -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Secret ecr-creds no existe en namespace $NAMESPACE"
    exit 1
fi

echo "✅ Pre-checks completados"
echo ""

# Determinar el color actual del service
CURRENT_LIVE=$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.spec.selector.colorLive}' 2>/dev/null || echo "none")
if [ "$CURRENT_LIVE" = "none" ]; then
    echo "ℹ️  Service 'backend' no existe aún, será creado"
    CURRENT_LIVE="blue"  # Default inicial
else
    echo "ℹ️  Color actualmente LIVE: $CURRENT_LIVE"
fi

# Determinar el color opuesto
if [ "$CURRENT_LIVE" = "blue" ]; then
    INACTIVE_COLOR="green"
else
    INACTIVE_COLOR="blue"
fi

echo "ℹ️  Color inactivo (target): $INACTIVE_COLOR"
echo ""

# Step 1: Deploy a la versión nueva (color target)
echo "🚀 Step 1: Desplegando versión $VERSION al color $COLOR..."
if [ "$DO_SWITCH" = "false" ]; then
    # Deploy sin cambiar el service (mantiene selector en color actual)
    helm upgrade --install tunefy-backend "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --values "$CHART_PATH/values-dev.yaml" \
        --set image.tag="$VERSION" \
        --set color="$COLOR" \
        --set service.selector.colorLive="$CURRENT_LIVE" \
        --wait \
        --timeout 5m
else
    # Deploy Y switch del service al nuevo color
    helm upgrade --install tunefy-backend "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --values "$CHART_PATH/values-dev.yaml" \
        --set image.tag="$VERSION" \
        --set color="$COLOR" \
        --set service.selector.colorLive="$COLOR" \
        --wait \
        --timeout 5m
fi

echo "✅ Deployment completado"
echo ""

# Step 2: Verificar el nuevo deployment
echo "📊 Estado de Deployments:"
kubectl get deployment -n "$NAMESPACE" -l app=tunefy-backend
echo ""

echo "📊 Pods del color $COLOR:"
kubectl get pods -n "$NAMESPACE" -l app=tunefy-backend,color="$COLOR"
echo ""

# Step 3: Health check del nuevo color
echo "🏥 Health Check del color $COLOR..."
POD_NAME=$(kubectl get pod -n "$NAMESPACE" -l app=tunefy-backend,color="$COLOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    echo "❌ Error: No se encontraron pods para el color $COLOR"
    exit 1
fi

echo "   Testing pod: $POD_NAME"
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -f -s http://localhost:3001/health >/dev/null 2>&1; then
    echo "✅ Health check exitoso en color $COLOR"
else
    echo "❌ Health check falló en color $COLOR"
    exit 1
fi
echo ""

# Step 4: Mostrar estado del service
echo "📊 Service Backend:"
kubectl get svc backend -n "$NAMESPACE"
LIVE_COLOR=$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.spec.selector.colorLive}')
echo "   Selector actual: colorLive=$LIVE_COLOR"
echo ""

# Step 5: Información del switch
if [ "$DO_SWITCH" = "true" ]; then
    echo "✅ SWITCH COMPLETADO: Service ahora apunta a color $COLOR"
    echo ""
    echo "📊 Pods recibiendo tráfico (colorLive=$COLOR):"
    kubectl get pods -n "$NAMESPACE" -l app=tunefy-backend,colorLive=true
else
    echo "⏸️  SWITCH NO REALIZADO: Service sigue apuntando a color $CURRENT_LIVE"
    echo ""
    echo "   Para hacer el switch, ejecutar:"
    echo "   $0 $VERSION $COLOR $NAMESPACE $CHART_PATH true"
    echo ""
    echo "   O desde Helm directamente:"
    echo "   helm upgrade tunefy-backend $CHART_PATH \\"
    echo "     --namespace $NAMESPACE \\"
    echo "     --set image.tag=$VERSION \\"
    echo "     --set color=$COLOR \\"
    echo "     --set service.selector.colorLive=$COLOR"
fi

echo ""

# Step 6: Ingress info
echo "📊 Ingress:"
kubectl get ingress tunefy-backend -n "$NAMESPACE"
ALB_URL=$(kubectl get ingress tunefy-backend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$ALB_URL" != "pending" ] && [ -n "$ALB_URL" ]; then
    echo "🌐 ALB URL: http://$ALB_URL/api"
else
    echo "⏳ ALB aún no está listo"
fi

echo ""
echo "=================================================="
echo "  ✅ Deployment Completado"
echo "=================================================="
