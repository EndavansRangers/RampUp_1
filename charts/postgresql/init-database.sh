#!/bin/bash
set -euo pipefail

echo "=== Initializing PostgreSQL Database Schema ==="

NAMESPACE="tunefy-dev"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=120s

# Get the PostgreSQL pod name
POSTGRES_POD=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo "Using PostgreSQL pod: $POSTGRES_POD"

# Check if tables already exist
echo "Checking if database schema already exists..."
TABLE_COUNT=$(kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- psql -U tunefy_user -d tunefy -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "✓ Database schema already exists ($TABLE_COUNT tables found)"
    echo "Skipping schema initialization"
else
    echo "Initializing database schema..."
    
    # Copy database setup script to pod
    kubectl cp database_setup.sql "$NAMESPACE/$POSTGRES_POD:/tmp/database_setup.sql"
    
    # Execute the script
    kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- psql -U tunefy_user -d tunefy -f /tmp/database_setup.sql
    
    echo "✓ Database schema initialized successfully"
fi

# Verify tables exist
echo "Verifying database tables..."
kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- psql -U tunefy_user -d tunefy -c "\dt"

echo "✓ PostgreSQL database initialization completed"

