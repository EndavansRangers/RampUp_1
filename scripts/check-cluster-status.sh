#!/bin/bash
# Check Kubernetes cluster status

set -euo pipefail

echo "🔍 Checking Kubernetes Cluster Status..."
echo ""

# Check if we need to SSH or if we're already on Control Plane
if command -v kubectl &> /dev/null; then
  echo "✅ kubectl found, checking cluster..."
  kubectl get nodes
  echo ""
  kubectl get pods -n tunefy-dev
else
  echo "⚠️  kubectl not found. Please run this script on the Control Plane."
  echo ""
  echo "To SSH to Control Plane:"
  echo "  ssh -i ~/.ssh/tunefy-dev-key.pem -o 'ProxyCommand=ssh -i ~/.ssh/tunefy-dev-key.pem -W %h:%p -q ubuntu@<BASTION_IP>' ubuntu@<CP_IP>"
fi

