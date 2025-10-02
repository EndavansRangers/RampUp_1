#!/bin/bash
set -euo pipefail

echo "=== Deploying PostgreSQL Helm chart ==="

# After cd charts/charts, the chart is at ./postgresql
CHART_DIR="./postgresql"
RELEASE_NAME="tunefy-postgresql"
NAMESPACE="tunefy-dev"

echo "Working directory: $(pwd)"
echo "Chart directory: $CHART_DIR"

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
  --values "$CHART_DIR/values-dev.yaml" \
  --timeout 8m \
  --wait \
  --atomic

echo "✓ PostgreSQL deployed successfully"

# Wait a bit for PostgreSQL to be fully ready
echo "Waiting for PostgreSQL to be fully ready..."
kubectl wait --for=condition=ready pod -l app=tunefy-postgresql -n "$NAMESPACE" --timeout=180s

echo "✓ PostgreSQL is ready"
