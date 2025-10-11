#!/bin/bash
# Rollback Helper Script - Backend Blue/Green
# Este script facilita el rollback instantáneo cambiando el service selector

set -e

TARGET_COLOR="${1}"
NAMESPACE="${2:-tunefy-dev}"

if [ -z "$TARGET_COLOR" ]; then
    echo "❌ Error: Debe especificar el color de rollback"
    echo "   Uso: $0 <blue|green> [namespace]"
    exit 1
fi

if [ "$TARGET_COLOR" != "blue" ] && [ "$TARGET_COLOR" != "green" ]; then
    echo "❌ Error: Color debe ser 'blue' o 'green'"
    exit 1
fi

echo "=================================================="
echo "  Backend Blue/Green Rollback"
echo "=================================================="
echo "Rollback al color: $TARGET_COLOR"
echo "Namespace: $NAMESPACE"
echo ""

# Verificar estado actual
CURRENT_LIVE=$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.spec.selector.colorLive}' 2>/dev/null || echo "none")

if [ "$CURRENT_LIVE" = "none" ]; then
    echo "❌ Error: Service 'backend' no existe en namespace $NAMESPACE"
    exit 1
fi

echo "ℹ️  Color actualmente LIVE: $CURRENT_LIVE"

if [ "$CURRENT_LIVE" = "$TARGET_COLOR" ]; then
    echo "⚠️  El color $TARGET_COLOR ya está activo, no hay nada que hacer"
    exit 0
fi

# Verificar que el deployment target existe y está listo
echo ""
echo "🔍 Verificando deployment $TARGET_COLOR..."
if ! kubectl get deployment "tunefy-backend-$TARGET_COLOR" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Deployment tunefy-backend-$TARGET_COLOR no existe"
    exit 1
fi

READY_REPLICAS=$(kubectl get deployment "tunefy-backend-$TARGET_COLOR" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$READY_REPLICAS" = "0" ]; then
    echo "❌ Error: No hay replicas listas en tunefy-backend-$TARGET_COLOR"
    kubectl get deployment "tunefy-backend-$TARGET_COLOR" -n "$NAMESPACE"
    exit 1
fi

echo "✅ Deployment $TARGET_COLOR tiene $READY_REPLICAS replicas listas"
echo ""

# Hacer el switch
echo "🔄 Haciendo rollback (switch del service)..."
kubectl patch svc backend -n "$NAMESPACE" -p "{\"spec\":{\"selector\":{\"colorLive\":\"$TARGET_COLOR\"}}}"

echo "✅ Rollback completado"
echo ""

# Verificar
echo "📊 Estado actual:"
kubectl get svc backend -n "$NAMESPACE"
NEW_LIVE=$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.spec.selector.colorLive}')
echo "   Selector nuevo: colorLive=$NEW_LIVE"
echo ""

echo "📊 Pods recibiendo tráfico ahora:"
kubectl get pods -n "$NAMESPACE" -l app=tunefy-backend,colorLive=true --show-labels
echo ""

echo "=================================================="
echo "  ✅ Rollback Exitoso"
echo "=================================================="
echo "Service 'backend' ahora apunta a: $TARGET_COLOR"
echo "Tráfico enrutado a deployment: tunefy-backend-$TARGET_COLOR"
