#!/bin/bash
set -euo pipefail

echo "=== Deploying Backend Helm chart ==="

# Chart is in current directory after Octopus extracts
CHART_DIR="charts/backend"
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

# Deploy using Helm
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.tag="$IMAGE_TAG" \
  --set color="$COLOR_NEXT" \
  --set service.selector.colorLive="$COLOR_NEXT" \
  --values "$CHART_DIR/values-dev.yaml" \
  --timeout 5m \
  --wait

echo "✓ Backend deployed successfully with color: $COLOR_NEXT"
