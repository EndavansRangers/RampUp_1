#!/bin/bash
# Fix para ambiente de desarrollo - DNS de CoreDNS no funciona
# Este script parchea el pod del frontend para usar la IP del backend directamente

NAMESPACE="tunefy-dev"
BACKEND_IP="10.99.25.161:3001"

echo "🔧 Fixing frontend nginx config to use backend IP directly..."
echo "   Backend IP: $BACKEND_IP"

# Get frontend pod
FRONTEND_POD=$(kubectl get pods -n $NAMESPACE -l app=tunefy-frontend -o jsonpath='{.items[0].metadata.name}')

if [ -z "$FRONTEND_POD" ]; then
  echo "❌ Frontend pod not found"
  exit 1
fi

echo "   Frontend pod: $FRONTEND_POD"

# Patch nginx config
kubectl exec -n $NAMESPACE $FRONTEND_POD -- sed -i \
  's|tunefy-backend-service\.default\.svc\.cluster\.local|'"$BACKEND_IP"'|g' \
  /etc/nginx/conf.d/default.conf

# Reload nginx
kubectl exec -n $NAMESPACE $FRONTEND_POD -- nginx -s reload

echo "✅ Frontend nginx config fixed!"
echo "   Testing backend connection..."

# Test
kubectl exec -n $NAMESPACE $FRONTEND_POD -- wget -O- -T 5 http://localhost/api/health 2>&1 | grep -q "healthy"

if [ $? -eq 0 ]; then
  echo "✅ Backend connection working!"
else
  echo "⚠️  Backend connection test failed, but config was updated"
fi
