#!/bin/bash
set -euo pipefail

echo "=== Deploying Frontend Helm chart ==="

# Chart is in current directory after Octopus extracts
CHART_DIR="charts/frontend"
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

# Deploy using Helm
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.tag="$IMAGE_TAG" \
  --values "$CHART_DIR/values-dev.yaml" \
  --timeout 5m \
  --wait

echo "✓ Frontend deployed successfully"
