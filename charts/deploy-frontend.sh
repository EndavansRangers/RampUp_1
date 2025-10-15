set -euo pipefail

CHART_DIR="./frontend"
RELEASE_NAME="tunefy-frontend"
NAMESPACE="tunefy-dev"
IMAGE_TAG="$1"

echo "=== Deploy FE (no rollback) ==="

# Si hay release en pending-*, limpiamos y seguimos SIN rollback
if helm ls -n "$NAMESPACE" -a 2>/dev/null | awk '$1=="'"$RELEASE_NAME"'" && $8 ~ /pending/ {found=1} END{exit !found}'; then
  echo "Stuck release detected → uninstall + purge history"
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --wait --timeout 180s || true
  kubectl -n "$NAMESPACE" delete secret -l owner=helm,name="$RELEASE_NAME" || true
  sleep 3
fi

# Upgrade/Install SIN --atomic (no hay rollback automático)
set +e
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  -n "$NAMESPACE" --create-namespace \
  --values "$CHART_DIR/values-dev.yaml" \
  --set image.tag="$IMAGE_TAG" \
  --timeout 8m --wait --wait-for-jobs
RC=$?
set -e

if [ $RC -ne 0 ]; then
  echo "❌ Helm failed (rc=$RC). Dumping diagnostics..."
  kubectl -n "$NAMESPACE" get deploy,rs,pods -l app=tunefy-frontend -o wide || true
  kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp | tail -n 80 || true
  exit $RC
fi

echo "✓ FE deployed (no rollback)"
