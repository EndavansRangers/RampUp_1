#!/bin/bash
set -euo pipefail

echo "=== Deploying Backend Helm chart ==="

# After cd charts/charts, the chart is at ./backend
CHART_DIR="./backend"
RELEASE_NAME="tunefy-backend"
NAMESPACE="tunefy-dev"

# These will be passed as arguments
IMAGE_TAG="$1"
COLOR_NEXT="$2"

echo "Working directory: $(pwd)"
echo "Chart directory: $CHART_DIR"
echo "Image tag: $IMAGE_TAG"
echo "Color: $COLOR_NEXT"

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
# Increased timeout to 5m for t3.small instances
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.tag="$IMAGE_TAG" \
  --set color="$COLOR_NEXT" \
  --set service.selector.colorLive="$COLOR_NEXT" \
  --values "$CHART_DIR/values-dev.yaml" \
  --timeout 5m \
  --wait \
  --atomic

echo "✓ Backend deployed successfully with color: $COLOR_NEXT"
