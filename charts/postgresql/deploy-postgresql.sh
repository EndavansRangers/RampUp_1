#!/bin/bash
set -euo pipefail

echo "=== Deploying PostgreSQL StatefulSet ==="

NAMESPACE="tunefy-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Apply the StatefulSet
echo "Applying PostgreSQL StatefulSet..."
kubectl apply -f "$SCRIPT_DIR/postgres-statefulset.yaml"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL pod to be ready (this may take up to 2 minutes)..."
kubectl wait --for=condition=ready pod/postgres-0 -n "$NAMESPACE" --timeout=120s

# Verify PostgreSQL is running
echo "Verifying PostgreSQL status..."
kubectl get statefulset postgres -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l app=postgres
kubectl get svc tunefy-db-rw -n "$NAMESPACE"

echo "✓ PostgreSQL deployed successfully"





