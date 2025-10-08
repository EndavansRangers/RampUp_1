#!/bin/bash
set -e

echo "=========================================="
echo "Creating Kubernetes ServiceAccount for Octopus"
echo "=========================================="

# Create namespace if it doesn't exist
kubectl create namespace tunefy-dev --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: octopus-deploy
  namespace: tunefy-dev
---
apiVersion: v1
kind: Secret
metadata:
  name: octopus-deploy-token
  namespace: tunefy-dev
  annotations:
    kubernetes.io/service-account.name: octopus-deploy
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: octopus-deploy-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: octopus-deploy-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: octopus-deploy-role
subjects:
- kind: ServiceAccount
  name: octopus-deploy
  namespace: tunefy-dev
EOF

echo ""
echo "Waiting for secret to be created..."
sleep 5

echo ""
echo "=========================================="
echo "Kubernetes Configuration for Octopus"
echo "=========================================="
echo ""

# Get the token
TOKEN=$(kubectl get secret octopus-deploy-token -n tunefy-dev -o jsonpath='{.data.token}' | base64 -d)

# Get the CA certificate
CA_CERT=$(kubectl get secret octopus-deploy-token -n tunefy-dev -o jsonpath='{.data.ca\.crt}')

# Get the API server URL
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

echo "API Server URL:"
echo "$API_SERVER"
echo ""
echo "CA Certificate (base64):"
echo "$CA_CERT"
echo ""
echo "Service Account Token:"
echo "$TOKEN"
echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "To configure Octopus:"
echo "1. Go to Infrastructure → Accounts"
echo "2. Add Account → Token"
echo "3. Name: kubernetes-tunefy-dev"
echo "4. Token: (paste the token above)"
echo ""
echo "Then go to Infrastructure → Deployment Targets"
echo "5. Add Deployment Target → Kubernetes Cluster"
echo "6. Display Name: tunefy-k8s-cluster"
echo "7. Environments: dev"
echo "8. Roles: k8s"
echo "9. Authentication: Token"
echo "10. Kubernetes cluster URL: $API_SERVER"
echo "11. Account: kubernetes-tunefy-dev"
echo "12. Skip TLS verification: Yes (or paste CA cert)"
echo ""
