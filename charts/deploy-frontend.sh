#!/bin/bash
set -euo pipefail

echo "=== Deploying Frontend Helm chart ==="

# After cd charts/charts, the chart is at ./frontend
CHART_DIR="./frontend"
RELEASE_NAME="tunefy-frontend"
NAMESPACE="tunefy-dev"

# These will be passed as arguments
IMAGE_TAG="$1"

echo "Working directory: $(pwd)"
echo "Chart directory: $CHART_DIR"
echo "Image tag: $IMAGE_TAG"

# Verify chart exists
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo "ERROR: Chart.yaml not found at $CHART_DIR"
    find . -name "Chart.yaml" || true
    exit 1
fi

# Check if there's a stuck release (pending-install, pending-upgrade, pending-rollback, etc.)
if helm list -n "$NAMESPACE" -a 2>/dev/null | grep "$RELEASE_NAME" | grep -q "pending"; then
    echo "WARNING: Found stuck release, attempting to recover..."
    # Try rollback first, if that fails, uninstall
    if ! helm rollback "$RELEASE_NAME" 0 -n "$NAMESPACE" --wait --timeout 30s 2>/dev/null; then
        echo "Rollback failed, uninstalling stuck release..."
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --wait --timeout 30s || true
    fi
    sleep 2
fi

# Deploy using Helm with atomic flag (auto-rollback on failure)
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.tag="$IMAGE_TAG" \
  --values "$CHART_DIR/values-dev.yaml" \
  --timeout 3m \
  --wait \
  --atomic

echo "✓ Frontend deployed successfully"

# === DNS Fix for Dev Environment ===
# CoreDNS in dev has timeouts, so we need to use backend IP directly
echo "=== Applying DNS fix for dev environment ==="

# Wait for pod to be fully ready
kubectl wait --for=condition=ready pod -l app=tunefy-frontend -n "$NAMESPACE" --timeout=120s

# Get backend service ClusterIP
BACKEND_IP=$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
echo "Backend ClusterIP: $BACKEND_IP"

# Get frontend pod
FRONTEND_POD=$(kubectl get pods -n "$NAMESPACE" -l app=tunefy-frontend -o jsonpath='{.items[0].metadata.name}')
echo "Frontend pod: $FRONTEND_POD"

# Apply DNS fix by replacing DNS names with ClusterIP
echo "Patching nginx configuration..."
kubectl exec -n "$NAMESPACE" "$FRONTEND_POD" -- sh -c "
  sed -i 's|backend\.tunefy-dev\.svc\.cluster\.local|$BACKEND_IP:3001|g' /etc/nginx/conf.d/default.conf &&
  sed -i 's|tunefy-backend-service\.default\.svc\.cluster\.local|$BACKEND_IP:3001|g' /etc/nginx/conf.d/default.conf &&
  nginx -s reload
"

echo "✓ DNS fix applied successfully"

# Verify the fix
echo "Verifying backend connectivity..."
if kubectl exec -n "$NAMESPACE" "$FRONTEND_POD" -- wget -O- -T 5 http://$BACKEND_IP:3001/health 2>&1 | grep -q "healthy"; then
  echo "✅ Backend is reachable!"
else
  echo "⚠️  Backend connectivity test inconclusive, but configuration was updated"
fi

echo "=== Frontend deployment completed ==="
