#!/bin/bash
set -euo pipefail

# ============================================
# Setup Kubernetes Production Environment
# Run this script from the Control Plane
# ============================================

echo "========================================"
echo "Tunefy Production K8s Setup"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check we're on control plane
if ! kubectl version --short &> /dev/null; then
    echo "kubectl not configured. Run this from Control Plane."
    exit 1
fi

echo -e "${GREEN}kubectl configured${NC}"
echo ""

# Wait for all nodes
echo "Waiting for all nodes to be Ready..."
kubectl wait --for=condition=ready nodes --all --timeout=600s
echo -e "${GREEN}All nodes Ready${NC}"
echo ""

kubectl get nodes
echo ""

# PHASE 1: CloudNativePG
echo "========================================"
echo "PHASE 1: Installing CloudNativePG"
echo "========================================"

kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml

echo "Waiting for CloudNativePG operator..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cloudnative-pg \
  -n cnpg-system \
  --timeout=300s

echo -e "${GREEN}CloudNativePG operator ready${NC}"
echo ""

# PHASE 2: StorageClass
echo "========================================"
echo "PHASE 2: Creating StorageClass"
echo "========================================"

kubectl apply -f k8s/prod/storageclass-gp3.yaml
echo -e "${GREEN}StorageClass gp3 created${NC}"
kubectl get storageclass
echo ""

# PHASE 3: Database Secrets
echo "========================================"
echo "PHASE 3: Creating Database Secrets"
echo "========================================"

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

kubectl create secret generic tunefy-db-credentials \
  --from-literal=username=tunefy_user \
  --from-literal=password="$DB_PASSWORD" \
  --namespace=tunefy-prod \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}Database credentials created${NC}"
echo -e "${YELLOW}Save this password: $DB_PASSWORD${NC}"
echo "$DB_PASSWORD" > ~/tunefy-db-password.txt
chmod 600 ~/tunefy-db-password.txt
echo "Saved to: ~/tunefy-db-password.txt"
echo ""

# S3 credentials for backups
echo "Creating S3 credentials for backups..."
echo -e "${YELLOW}Using instance IAM role for S3 access${NC}"
echo -e "${YELLOW}If you need dedicated credentials, create them manually${NC}"

# Get AWS region from metadata
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region || echo "us-east-1")

kubectl create secret generic aws-s3-creds \
  --from-literal=ACCESS_KEY_ID="" \
  --from-literal=ACCESS_SECRET_KEY="" \
  --from-literal=AWS_REGION="$AWS_REGION" \
  --namespace=tunefy-prod \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}S3 credentials placeholder created${NC}"
echo ""

# PHASE 4: PostgreSQL Cluster
echo "========================================"
echo "PHASE 4: Deploying PostgreSQL Cluster"
echo "========================================"

kubectl apply -f k8s/prod/tunefy-db-cluster-prod.yaml

echo "Waiting for PostgreSQL cluster (this may take 2-3 minutes)..."
sleep 30  # Initial wait

kubectl wait --for=condition=ready cluster/tunefy-db \
  -n tunefy-prod \
  --timeout=300s || true

echo ""
kubectl get pods -n tunefy-prod -l cnpg.io/cluster=tunefy-db
echo ""
echo -e "${GREEN}PostgreSQL cluster deployed${NC}"
echo ""

# PHASE 5: Backend Secrets
echo "========================================"
echo "PHASE 5: Creating Backend Secrets"
echo "========================================"

echo -e "${YELLOW}Enter Spotify API credentials:${NC}"
read -p "Spotify Client ID: " SPOTIFY_CLIENT_ID
read -sp "Spotify Client Secret: " SPOTIFY_CLIENT_SECRET
echo ""
read -p "Spotify Redirect URI [https://tunefy-prod.yourdomain.com/callback]: " SPOTIFY_REDIRECT_URI
SPOTIFY_REDIRECT_URI=${SPOTIFY_REDIRECT_URI:-https://tunefy-prod.yourdomain.com/callback}

SESSION_SECRET=$(openssl rand -base64 32)

kubectl create secret generic backend-secrets \
  --from-literal=SPOTIFY_CLIENT_ID="$SPOTIFY_CLIENT_ID" \
  --from-literal=SPOTIFY_CLIENT_SECRET="$SPOTIFY_CLIENT_SECRET" \
  --from-literal=SPOTIFY_REDIRECT_URI="$SPOTIFY_REDIRECT_URI" \
  --from-literal=SESSION_SECRET="$SESSION_SECRET" \
  --from-literal=PGHOST='tunefy-db-rw.tunefy-prod.svc.cluster.local' \
  --from-literal=PGPORT='5432' \
  --from-literal=PGDATABASE='tunefy' \
  --from-literal=PGUSER='tunefy_user' \
  --from-literal=PGPASSWORD="$DB_PASSWORD" \
  --namespace=tunefy-prod \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}Backend secrets created${NC}"
echo ""

# PHASE 6: ECR Credentials
echo "========================================"
echo "PHASE 6: Creating ECR Credentials"
echo "========================================"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TOKEN=$(aws ecr get-login-password --region $AWS_REGION)

kubectl create secret docker-registry ecr-creds \
  --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --namespace=tunefy-prod \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}ECR credentials created${NC}"
echo ""

# PHASE 7: ECR Token Auto-Refresh
echo "========================================"
echo "PHASE 7: Setting up ECR Token Refresh"
echo "========================================"

kubectl apply -f k8s/prod/ecr-token-refresh-cronjob.yaml
echo -e "${GREEN}ECR auto-refresh CronJob deployed${NC}"
kubectl get cronjob -n tunefy-prod
echo ""

# PHASE 8: AWS Load Balancer Controller
echo "========================================"
echo "PHASE 8: Installing AWS LB Controller"
echo "========================================"

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "Waiting for cert-manager..."
sleep 20
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

echo -e "${GREEN}cert-manager ready${NC}"
echo ""

# Install AWS LB Controller
echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=tunefy-prod-vpc" --query 'Vpcs[0].VpcId' --output text)

helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tunefy-prod \
  --set serviceAccount.create=false \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

echo -e "${GREEN}AWS Load Balancer Controller installed${NC}"
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""

# PHASE 9: Monitoring
echo "========================================"
echo "PHASE 9: Installing Monitoring Stack"
echo "========================================"

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set alertmanager.enabled=true \
  --set grafana.adminPassword='TunefyProd2024!'

echo "Waiting for Prometheus stack..."
sleep 30
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=grafana \
  -n monitoring \
  --timeout=300s || true

echo -e "${GREEN}Monitoring stack installed${NC}"
echo ""

# Apply custom alerts
kubectl apply -f k8s/prod/prometheus-rules.yaml
echo -e "${GREEN}Custom alerts configured${NC}"
echo ""

# PHASE 10: Database Schema
echo "========================================"
echo "PHASE 10: Initializing Database Schema"
echo "========================================"

echo "Waiting for database pod to be ready..."
kubectl wait --for=condition=ready pod/tunefy-db-1 \
  -n tunefy-prod \
  --timeout=300s

echo "Copying schema to database pod..."
kubectl cp backend/database_setup.sql \
  tunefy-prod/tunefy-db-1:/tmp/schema.sql

echo "Executing schema..."
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -f /tmp/schema.sql

echo -e "${GREEN}Database schema initialized${NC}"
echo ""





