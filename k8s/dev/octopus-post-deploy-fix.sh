#!/bin/bash
# Este script debe ejecutarse cada vez que Octopus despliega el frontend en dev
# Lo puedes agregar como un step adicional en el proceso de deployment de Octopus

set -e

echo "🔧 Applying DNS fix to frontend deployment in dev..."

# Variables
NAMESPACE="tunefy-dev"
DEPLOYMENT="tunefy-frontend"

# Get backend ClusterIP
BACKEND_IP=$(kubectl get svc backend -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "   Backend ClusterIP: $BACKEND_IP"

# Wait for deployment to be ready
echo "   Waiting for deployment to be ready..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s

# Get the new pod
FRONTEND_POD=$(kubectl get pods -n $NAMESPACE -l app=tunefy-frontend -o jsonpath='{.items[0].metadata.name}')
echo "   Frontend pod: $FRONTEND_POD"

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/$FRONTEND_POD -n $NAMESPACE --timeout=120s

# Give nginx a moment to fully start
sleep 5

# Apply the fix
echo "   Patching nginx configuration..."
kubectl exec -n $NAMESPACE $FRONTEND_POD -- sh -c "
  sed -i 's|backend\.tunefy-dev\.svc\.cluster\.local|$BACKEND_IP:3001|g' /etc/nginx/conf.d/default.conf &&
  sed -i 's|tunefy-backend-service\.default\.svc\.cluster\.local|$BACKEND_IP:3001|g' /etc/nginx/conf.d/default.conf &&
  cat /etc/nginx/conf.d/default.conf | grep backend &&
  nginx -s reload
"

echo "✅ DNS fix applied successfully!"

# Test the connection
echo "🧪 Testing backend connection via frontend..."
FRONTEND_ALB="k8s-tunefyde-tunefyfr-798b6aea21-1369834460.us-east-1.elb.amazonaws.com"

for i in {1..10}; do
  if curl -k -s -f https://$FRONTEND_ALB/api/health | grep -q "healthy"; then
    echo "✅ Backend is reachable through frontend!"
    exit 0
  fi
  echo "   Attempt $i/10 - waiting..."
  sleep 3
done

echo "⚠️  Could not verify backend connection, but config was applied"
exit 0
