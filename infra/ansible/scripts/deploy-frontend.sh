#!/bin/bash
# Octopus Deploy Helper Script - Frontend Rolling Deployment
# Este script simplifica el deployment del frontend con rolling updates

set -e

# Variables de Octopus (pueden ser pasadas como argumentos o env vars)
VERSION="${1:-${OCTOPUS_RELEASE_NUMBER:-0.0.0-local}}"
NAMESPACE="${2:-${OCTOPUS_NAMESPACE:-tunefy-dev}}"
CHART_PATH="${3:-/tmp/charts/frontend}"

echo "=================================================="
echo "  Frontend Rolling Deployment"
echo "=================================================="
echo "Version: $VERSION"
echo "Namespace: $NAMESPACE"
echo "Chart Path: $CHART_PATH"
echo ""

# Verificar que el chart existe
if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Error: Chart no encontrado en $CHART_PATH"
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "⚠️  Namespace $NAMESPACE no existe, creándolo..."
    kubectl create namespace "$NAMESPACE"
fi

# Verificar que el secret de ECR existe
if ! kubectl get secret ecr-creds -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Secret ecr-creds no existe en namespace $NAMESPACE"
    echo "   Ejecutar: /tmp/setup-ecr-pull-secret.sh"
    exit 1
fi

echo "✅ Pre-checks completados"
echo ""

# Deploy con Helm
echo "🚀 Desplegando Frontend..."
helm upgrade --install tunefy-frontend "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --values "$CHART_PATH/values-dev.yaml" \
    --set image.tag="$VERSION" \
    --wait \
    --timeout 5m

echo ""
echo "✅ Frontend desplegado exitosamente"
echo ""

# Verificar el deployment
echo "📊 Estado del Deployment:"
kubectl get deployment tunefy-frontend -n "$NAMESPACE"
echo ""

echo "📊 Pods:"
kubectl get pods -n "$NAMESPACE" -l app=tunefy-frontend
echo ""

echo "📊 Service:"
kubectl get svc tunefy-frontend -n "$NAMESPACE"
echo ""

echo "📊 Ingress:"
kubectl get ingress tunefy-frontend -n "$NAMESPACE"
echo ""

# Obtener el ALB URL
ALB_URL=$(kubectl get ingress tunefy-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$ALB_URL" != "pending" ] && [ -n "$ALB_URL" ]; then
    echo "🌐 ALB URL: http://$ALB_URL"
else
    echo "⏳ ALB aún no está listo, verificar en unos minutos"
fi

echo ""
echo "=================================================="
echo "  ✅ Deployment Completado"
echo "=================================================="
