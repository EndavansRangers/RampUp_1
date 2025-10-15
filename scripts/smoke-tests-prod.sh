#!/bin/bash
set -e

COLOR=$1
NAMESPACE=${2:-default}

if [ -z "$COLOR" ]; then
  echo "Usage: $0 <blue|green> [namespace]"
  exit 1
fi

echo "Running smoke tests for color: $COLOR in namespace: $NAMESPACE"

# Obtener IP de un pod del color especificado
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=tunefy-backend,color=$COLOR -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo "ERROR: No pods found for color $COLOR in namespace $NAMESPACE"
  exit 1
fi

echo "Testing pod: $POD_NAME"

# Test 1: Health endpoint
echo ""
echo "Test 1: Health Check..."
HEALTH_RESPONSE=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health 2>/dev/null)

if [ "$HEALTH_RESPONSE" != "200" ]; then
  echo "FAILED: Health check returned HTTP $HEALTH_RESPONSE (expected 200)"
  exit 1
fi
echo "PASSED: Health check returned HTTP 200"

# Test 2: Playlist endpoint (debe retornar array vacío o data válida)
echo ""
echo "Test 2: Playlist Endpoint..."
PLAYLIST_CODE=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:3001/api/playlist?sessionId=smoke-test-$(date +%s)" 2>/dev/null)

if [ "$PLAYLIST_CODE" != "200" ]; then
  echo "FAILED: Playlist endpoint returned HTTP $PLAYLIST_CODE (expected 200)"
  exit 1
fi

PLAYLIST_RESPONSE=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s "http://localhost:3001/api/playlist?sessionId=smoke-test-$(date +%s)" 2>/dev/null)

# Verificar que sea JSON válido (debe ser un array)
if ! echo "$PLAYLIST_RESPONSE" | grep -q '\['; then
  echo "WARNING: Playlist response is not a JSON array (might be an error response)"
  echo "Response: $PLAYLIST_RESPONSE"
  # No fallar por esto, puede ser normal si la sesión no existe
fi
echo "PASSED: Playlist endpoint returned HTTP 200"

# Test 3: Database connectivity
echo ""
echo "Test 3: Database Connectivity..."
DB_TEST=$(kubectl exec -n $NAMESPACE $POD_NAME -- sh -c 'node -e "const { Pool } = require(\"pg\"); const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASSWORD }); pool.query(\"SELECT 1 as test\").then(res => { console.log(\"DB_OK:\", res.rows[0].test); process.exit(0); }).catch(err => { console.error(\"DB_ERROR:\", err.message); process.exit(1); });"' 2>&1)

if ! echo "$DB_TEST" | grep -q "DB_OK"; then
  echo "❌ FAILED: Database connection test failed"
  echo "Error: $DB_TEST"
  exit 1
fi
echo "PASSED: Database connectivity (result: $(echo "$DB_TEST" | grep -o "DB_OK: [0-9]*"))"

# Test 4: Verificar que el pod tenga el label de color correcto
echo ""
echo "Test 4: Verify Pod Color Label..."
POD_COLOR=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.color}' 2>/dev/null)

if [ "$POD_COLOR" != "$COLOR" ]; then
  echo "FAILED: Pod has color label '$POD_COLOR' but expected '$COLOR'"
  exit 1
fi
echo "PASSED: Pod has correct color label: $POD_COLOR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All smoke tests passed for color: $COLOR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
