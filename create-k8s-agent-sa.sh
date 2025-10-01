#!/bin/bash
# Script to create Service Account for Octopus Kubernetes Agent
# This allows Octopus to connect directly to the Kubernetes API

set -euo pipefail

echo "=== Creating Octopus Deploy Service Account for Kubernetes Agent ==="
echo ""

# Create namespace for octopus if needed
kubectl create namespace octopus-system --dry-run=client -o yaml | kubectl apply -f -

# Create Service Account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: octopus-deploy
  namespace: octopus-system
---
apiVersion: v1
kind: Secret
metadata:
  name: octopus-deploy-token
  namespace: octopus-system
  annotations:
    kubernetes.io/service-account.name: octopus-deploy
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: octopus-deploy
rules:
  # Full cluster admin for deployments
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: octopus-deploy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: octopus-deploy
subjects:
  - kind: ServiceAccount
    name: octopus-deploy
    namespace: octopus-system
EOF

echo ""
echo "✓ Service Account created"
echo ""

# Wait for secret to be created
echo "Waiting for token secret to be populated..."
sleep 3

# Get the token
TOKEN=$(kubectl get secret octopus-deploy-token -n octopus-system -o jsonpath='{.data.token}' | base64 -d)

# Get cluster info
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_CERT=$(kubectl get secret octopus-deploy-token -n octopus-system -o jsonpath='{.data.ca\.crt}')

echo "=== Kubernetes Agent Configuration ==="
echo ""
echo "Service Account: octopus-deploy"
echo "Namespace: octopus-system"
echo ""
echo "API Server URL:"
echo "$API_SERVER"
echo ""
echo "CA Certificate (base64):"
echo "$CA_CERT"
echo ""
echo "Service Account Token:"
echo "$TOKEN"
echo ""
echo "================================================================"
echo "Next Steps:"
echo "1. Go to Octopus UI: Infrastructure > Deployment Targets"
echo "2. Click 'Add Deployment Target' > 'Kubernetes Agent'"
echo "3. Enter the following:"
echo "   - Name: k8s-dev-cluster"
echo "   - Environment: Dev"
echo "   - Target Tags: k8s-deployer"
echo "   - API URL: $API_SERVER"
echo "   - Token: (use the token above)"
echo "   - Skip TLS verification: Yes (or upload CA cert)"
echo "================================================================"
echo ""
