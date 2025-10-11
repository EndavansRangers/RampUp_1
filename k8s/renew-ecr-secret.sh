#!/bin/bash
set -e

export KUBECONFIG=/home/ubuntu/.kube/config
export AWS_DEFAULT_REGION=us-east-1

echo "[$(date)] Starting ECR credential renewal..."

# Get fresh ECR token
TOKEN=$(aws ecr get-login-password --region us-east-1)

if [ -z "$TOKEN" ]; then
  echo "[$(date)] ERROR: Failed to get ECR token"
  exit 1
fi

# Delete old secret
kubectl delete secret ecr-registry -n default --ignore-not-found=true
echo "[$(date)] Deleted old secret"

# Create new secret
kubectl create secret docker-registry ecr-registry \
  --docker-server=038686090046.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$TOKEN \
  -n default

echo "[$(date)] ECR credential renewal completed successfully"
