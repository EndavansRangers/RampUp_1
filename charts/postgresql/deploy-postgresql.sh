#!/bin/bash
set -euo pipefail

echo "=== Deploying PostgreSQL StatefulSet ==="

NAMESPACE="tunefy-dev"

# Determine the correct path for the PostgreSQL files
# In Octopus, the charts package is extracted to charts/charts/
if [ -d "charts/postgresql" ]; then
    CHART_DIR="charts/postgresql"
elif [ -d "postgresql" ]; then
    CHART_DIR="postgresql"
else
    echo "❌ ERROR: Cannot find PostgreSQL chart directory"
    echo "Current directory: $(pwd)"
    echo "Directory contents:"
    ls -la
    exit 1
fi

echo "Using chart directory: $CHART_DIR"

# Apply PostgreSQL StatefulSet and Services
echo "Applying PostgreSQL StatefulSet..."
# Use hostPath version for better compatibility
kubectl apply -f "$CHART_DIR/postgres-hostpath.yaml" --namespace "$NAMESPACE"

# Wait for PostgreSQL pod to be ready
echo "Waiting for PostgreSQL pod to be ready (this may take up to 2 minutes)..."
kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=120s

# Verify PostgreSQL is running
echo "Verifying PostgreSQL status..."
kubectl get deployment postgres -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l app=postgres
kubectl get svc tunefy-db-rw -n "$NAMESPACE"

# Initialize database schema if needed
echo "Initializing database schema..."
if [ -f "$CHART_DIR/init-database.sh" ]; then
    bash "$CHART_DIR/init-database.sh"
else
    echo "⚠️  Database initialization script not found, skipping..."
fi

echo "✓ PostgreSQL deployment completed successfully"





