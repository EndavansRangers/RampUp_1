#!/bin/bash
# Deployment script for kube-prometheus-stack monitoring
# Deploys Prometheus, Grafana, Alertmanager and related components

set -e

NAMESPACE="monitoring"
RELEASE_NAME="mon"
HELM_REPO="prometheus-community"
CHART_NAME="kube-prometheus-stack"
VALUES_FILE="values-dev.yaml"
SERVICEMONITORS_FILE="servicemonitors.yaml"

echo "======================================"
echo "  Deploying Monitoring Stack (Dev)   "
echo "======================================"

# 1. Add and update Helm repository
echo ""
echo "[1/5] Adding Helm repository..."
helm repo add ${HELM_REPO} https://prometheus-community.github.io/helm-charts || true
helm repo update

# 2. Create monitoring namespace
echo ""
echo "[2/5] Creating namespace '${NAMESPACE}'..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# 3. Deploy kube-prometheus-stack
echo ""
echo "[3/5] Installing/Upgrading ${CHART_NAME}..."
echo "  - Release: ${RELEASE_NAME}"
echo "  - Namespace: ${NAMESPACE}"
echo "  - Values: ${VALUES_FILE}"
echo ""

helm upgrade --install ${RELEASE_NAME} ${HELM_REPO}/${CHART_NAME} \
  --namespace ${NAMESPACE} \
  --values ${VALUES_FILE} \
  --atomic \
  --timeout 10m \
  --wait

# 4. Apply ServiceMonitors for Tunefy services
echo ""
echo "[4/5] Applying ServiceMonitors..."
kubectl apply -f ${SERVICEMONITORS_FILE}

# 5. Wait for all pods to be ready
echo ""
echo "[5/5] Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
  --all \
  --namespace=${NAMESPACE} \
  --timeout=300s || true

# Display deployment status
echo ""
echo "======================================"
echo "  Deployment Summary"
echo "======================================"
echo ""
echo "Pods in monitoring namespace:"
kubectl get pods -n ${NAMESPACE} -o wide

echo ""
echo "Services in monitoring namespace:"
kubectl get svc -n ${NAMESPACE}

echo ""
echo "Ingress (Grafana ALB):"
kubectl get ingress -n ${NAMESPACE}

echo ""
echo "ServiceMonitors in tunefy-dev:"
kubectl get servicemonitors -n tunefy-dev

echo ""
echo "======================================"
echo "  Access Information"
echo "======================================"
echo ""
echo "Grafana:"
echo "  - Get ALB URL: kubectl get ingress -n monitoring"
echo "  - User: admin"
echo "  - Password: admin"
echo ""
echo "Prometheus (internal access):"
echo "  - Port-forward: kubectl -n monitoring port-forward svc/mon-kube-prometheus-stack-prometheus 9090:9090"
echo "  - Then visit: http://localhost:9090"
echo ""
echo "Alertmanager (internal access):"
echo "  - Port-forward: kubectl -n monitoring port-forward svc/mon-kube-prometheus-stack-alertmanager 9093:9093"
echo "  - Then visit: http://localhost:9093"
echo ""
echo "======================================"
echo "  Deployment Complete!"
echo "======================================"
