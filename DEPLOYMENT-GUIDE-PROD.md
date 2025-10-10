# 🚀 Deployment Guide - Tunefy Production

**Fecha:** Octubre 2025  
**Ambiente:** Producción (Nueva cuenta AWS - Free Tier optimizado)  
**Cluster:** 1 Control Plane + 2 Workers (t3.small + t3.micro)

---

## 📋 Prerequisites

### 1. AWS Account Setup
- [ ] Nueva cuenta AWS creada
- [ ] AWS CLI instalado y configurado
- [ ] Credenciales AWS configuradas: `aws configure`
- [ ] Free Tier activo

### 2. Local Tools
```bash
# Terraform
terraform --version  # Requiere >= 1.0

# kubectl
kubectl version --client

# Helm
helm version

# AWS CLI
aws --version
```

### 3. SSH Key Pair
```bash
# Crear key pair en AWS (nueva cuenta)
aws ec2 create-key-pair \
  --key-name tunefy-prod-key \
  --query 'KeyMaterial' \
  --output text > tunefy-prod-key.pem

chmod 400 tunefy-prod-key.pem
```

### 4. Get Your Public IP
```bash
curl ifconfig.me
# Anota esta IP para SSH access
```

---

## 🏗️ FASE 1: Deploy Infrastructure with Terraform

### Step 1: Network Module (VPC + Subnets)

```bash
cd infra/terraform/network

# Copy and configure
cp terraform-prod.tfvars terraform.tfvars

# Review and edit if needed
nano terraform.tfvars

# Initialize
terraform init

# Plan
terraform plan -out=network.tfplan

# Apply
terraform apply network.tfplan

# Get outputs (save these!)
terraform output
```

**Expected outputs:**
- `vpc_id`: vpc-xxxxx
- `public_subnet_ids`: [subnet-xxx, subnet-yyy]
- `private_subnet_ids`: [subnet-aaa, subnet-bbb]

### Step 2: Platform Module (ECR, IAM, S3)

```bash
cd ../platform

# Copy and configure
cp terraform-prod.tfvars terraform.tfvars

# Edit domain if needed
nano terraform.tfvars

# Initialize
terraform init

# Plan
terraform plan -out=platform.tfplan

# Apply
terraform apply platform.tfplan

# Get outputs (save these!)
terraform output
```

**Expected outputs:**
- `ecr_repo_urls`: ECR repository URLs
- `nodes_instance_profile_name`: tunefy-prod-nodes
- `s3_postgresql_backups_bucket`: tunefy-prod-postgresql-backups

### Step 3: Compute Module (K8s Cluster)

```bash
cd ../compute-prod

# Copy and configure
cp terraform.tfvars.example terraform.tfvars

# IMPORTANT: Edit with outputs from previous steps
nano terraform.tfvars
```

**terraform.tfvars configuration:**
```hcl
project = "tunefy"
region  = "us-east-1"
env     = "prod"

# From network module output
vpc_id = "vpc-xxxxx"  # REPLACE
public_subnet_ids = [
  "subnet-xxxxxxxxx",  # REPLACE
  "subnet-yyyyyyyyy"   # REPLACE
]
private_subnet_ids = [
  "subnet-aaaaaaaaa",  # REPLACE
  "subnet-bbbbbbbbb"   # REPLACE
]

# From platform module output
nodes_instance_profile_name = "tunefy-prod-nodes"  # Usually matches

# SSH config
key_name = "tunefy-prod-key"
allowed_ssh_cidr = "YOUR.IP.HERE/32"  # REPLACE with your IP

# K8s config
cluster_name = "tunefy-prod"
cp_instance_type = "t3.small"
wk_instance_type = "t3.micro"
bastion_instance_type = "t3.micro"

tags = {
  Owner       = "DevOps"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```

```bash
# Initialize
terraform init

# Plan (review carefully!)
terraform plan -out=compute.tfplan

# Apply (this will take ~10 minutes)
terraform apply compute.tfplan

# Get outputs
terraform output
```

**Expected outputs:**
- `bastion_public_ip`: X.X.X.X
- `cp_private_ips`: [10.30.x.x]
- `nlb_dns_name`: tunefy-prod-nlb-xxxxx.elb.us-east-1.amazonaws.com

---

## ☸️ FASE 2: Verify Kubernetes Cluster

### Step 1: Connect to Bastion

```bash
ssh -i tunefy-prod-key.pem ubuntu@<BASTION_PUBLIC_IP>
```

### Step 2: From Bastion, connect to Control Plane

```bash
# Get CP private IP from Terraform output
ssh ubuntu@<CP_PRIVATE_IP>
```

### Step 3: Verify Cluster

```bash
# Check nodes (should see 1 CP + 2 Workers after ~5 minutes)
kubectl get nodes

# Expected output:
# NAME                  STATUS   ROLES           AGE   VERSION
# tunefy-prod-cp-xxx    Ready    control-plane   5m    v1.28.x
# tunefy-prod-wk-xxx    Ready    <none>          3m    v1.28.x
# tunefy-prod-wk-yyy    Ready    <none>          3m    v1.28.x

# Check pods
kubectl get pods -A

# Check namespace
kubectl get ns tunefy-prod
```

### Step 4: Copy kubeconfig to Local

```bash
# From Control Plane, display kubeconfig
cat ~/.kube/config

# From your local machine:
mkdir -p ~/.kube
scp -i tunefy-prod-key.pem \
  -o ProxyJump=ubuntu@<BASTION_IP> \
  ubuntu@<CP_PRIVATE_IP>:~/.kube/config \
  ~/.kube/config-tunefy-prod

# Set context
export KUBECONFIG=~/.kube/config-tunefy-prod

# Update server URL to use NLB
kubectl config set-cluster kubernetes \
  --server=https://<NLB_DNS_NAME>:6443
  
# Test
kubectl get nodes
```

---

## 🗄️ FASE 3: Install CloudNativePG and PostgreSQL

### Step 1: Install CloudNativePG Operator

```bash
# From Control Plane or local (with kubeconfig)
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml

# Verify
kubectl get pods -n cnpg-system

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cloudnative-pg \
  -n cnpg-system \
  --timeout=300s
```

### Step 2: Create StorageClass

```bash
kubectl apply -f k8s/prod/storageclass-gp3.yaml

# Verify
kubectl get storageclass
```

### Step 3: Create Database Credentials Secret

```bash
# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

kubectl create secret generic tunefy-db-credentials \
  --from-literal=username=tunefy_user \
  --from-literal=password="$DB_PASSWORD" \
  --namespace=tunefy-prod

# Save password securely!
echo "DB Password: $DB_PASSWORD" >> ~/tunefy-prod-secrets.txt
chmod 600 ~/tunefy-prod-secrets.txt
```

### Step 4: Create S3 Credentials for Backups

```bash
# Create IAM user for backups (alternative: use instance role)
# If using instance role, you can skip this and remove s3Credentials from cluster manifest

# If creating dedicated user:
# 1. Create IAM user in AWS Console: tunefy-prod-db-backup
# 2. Attach policy to access S3 bucket
# 3. Create access key

kubectl create secret generic aws-s3-creds \
  --from-literal=ACCESS_KEY_ID='your-access-key' \
  --from-literal=ACCESS_SECRET_KEY='your-secret-key' \
  --from-literal=AWS_REGION='us-east-1' \
  --namespace=tunefy-prod
```

### Step 5: Deploy PostgreSQL Cluster

```bash
kubectl apply -f k8s/prod/tunefy-db-cluster-prod.yaml

# Monitor deployment
kubectl get cluster -n tunefy-prod -w

# Wait for ready (takes ~2-3 minutes)
kubectl wait --for=condition=ready cluster/tunefy-db \
  -n tunefy-prod \
  --timeout=300s

# Verify pods
kubectl get pods -n tunefy-prod -l cnpg.io/cluster=tunefy-db
```

### Step 6: Initialize Database Schema

```bash
# Copy schema to pod
kubectl cp backend/database_setup.sql \
  tunefy-prod/tunefy-db-1:/tmp/schema.sql

# Execute schema
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -f /tmp/schema.sql

# Verify tables
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -c '\dt'
```

---

## 🔐 FASE 4: Configure Secrets

### Step 1: Backend Secrets (Spotify API + DB)

```bash
# Get DB password
DB_PASSWORD=$(kubectl get secret tunefy-db-credentials \
  -n tunefy-prod \
  -o jsonpath='{.data.password}' | base64 -d)

# Create backend secrets
kubectl create secret generic backend-secrets \
  --from-literal=SPOTIFY_CLIENT_ID='your-spotify-client-id' \
  --from-literal=SPOTIFY_CLIENT_SECRET='your-spotify-client-secret' \
  --from-literal=SPOTIFY_REDIRECT_URI='https://tunefy-prod.yourdomain.com/callback' \
  --from-literal=SESSION_SECRET=$(openssl rand -base64 32) \
  --from-literal=PGHOST='tunefy-db-rw.tunefy-prod.svc.cluster.local' \
  --from-literal=PGPORT='5432' \
  --from-literal=PGDATABASE='tunefy' \
  --from-literal=PGUSER='tunefy_user' \
  --from-literal=PGPASSWORD="$DB_PASSWORD" \
  --namespace=tunefy-prod
```

### Step 2: ECR Pull Secret

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

# Get ECR token
TOKEN=$(aws ecr get-login-password --region $AWS_REGION)

# Create secret
kubectl create secret docker-registry ecr-creds \
  --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --namespace=tunefy-prod
```

### Step 3: Deploy ECR Token Auto-Refresh

```bash
kubectl apply -f k8s/prod/ecr-token-refresh-cronjob.yaml

# Verify CronJob
kubectl get cronjob -n tunefy-prod

# Test manually
kubectl create job --from=cronjob/ecr-token-refresh \
  test-refresh -n tunefy-prod
```

---

## 🌐 FASE 5: Install AWS Load Balancer Controller

### Step 1: Install cert-manager (prerequisite)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s
```

### Step 2: Install AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tunefy-prod \
  --set serviceAccount.create=false \
  --set region=us-east-1 \
  --set vpcId=<VPC_ID>  # From Terraform output

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

## 📊 FASE 6: Install Monitoring Stack

### Step 1: Install Prometheus Stack

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set alertmanager.enabled=true \
  --set grafana.adminPassword='admin123!'  # CHANGE THIS

# Wait for pods
kubectl get pods -n monitoring -w
```

### Step 2: Configure Alertmanager for Slack

```bash
# Create Slack webhook secret
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

kubectl create secret generic alertmanager-slack \
  --from-literal=webhook-url="$SLACK_WEBHOOK" \
  --namespace=monitoring

# Apply alertmanager config
kubectl apply -f k8s/prod/alertmanager-config.yaml

# Apply custom alerts
kubectl apply -f k8s/prod/prometheus-rules.yaml
```

### Step 3: Access Grafana

```bash
# Port-forward
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80

# Open: http://localhost:3000
# User: admin
# Password: admin123! (or what you set)
```

---

## 🐙 FASE 7: Configure Octopus Deploy

### Step 1: Create Environment in Octopus

1. Go to Octopus UI: `Infrastructure → Environments`
2. Click `Add Environment`
3. Name: `Production`
4. Save

### Step 2: Create ServiceAccount for Octopus

```bash
kubectl create serviceaccount octopus-deploy -n tunefy-prod

# Create ClusterRole with specific permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: octopus-deployer
  namespace: tunefy-prod
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
EOF

# Bind role
kubectl create rolebinding octopus-deployer \
  --role=octopus-deployer \
  --serviceaccount=tunefy-prod:octopus-deploy \
  -n tunefy-prod

# Create token (valid for 1 year)
kubectl create token octopus-deploy \
  -n tunefy-prod \
  --duration=8760h > octopus-token.txt

cat octopus-token.txt
```

### Step 3: Register Deployment Target in Octopus

1. Go to: `Infrastructure → Deployment Targets → Add Deployment Target`
2. Type: `Kubernetes Cluster`
3. Name: `tunefy-prod-cluster`
4. URL: `https://<NLB_DNS_NAME>:6443`
5. Token: paste from `octopus-token.txt`
6. Namespace: `tunefy-prod`
7. Environment: `Production`
8. Roles: `k8s-deployer`
9. Save

### Step 4: Configure Variables in Octopus

Go to: `Projects → Tunefy → Variables`

| Variable | Value | Scope |
|----------|-------|-------|
| `Kubernetes.Namespace` | `tunefy-prod` | Production |
| `ECR.AccountId` | `<your-account-id>` | Production |
| `ECR.Region` | `us-east-1` | Production |
| `Backend.Replicas` | `2` | Production |
| `Frontend.Replicas` | `2` | Production |
| `DB.Host` | `tunefy-db-rw.tunefy-prod.svc.cluster.local` | Production |

---

## 🚀 FASE 8: First Deployment

### Step 1: Build and Push Images (TeamCity)

Trigger TeamCity build from main branch.

### Step 2: Deploy Frontend (Auto)

Frontend will auto-deploy to production (Continuous Deployment).

Monitor in Octopus UI: `Projects → Tunefy → Deployments`

```bash
# Verify from cluster
kubectl get pods -n tunefy-prod -l app=tunefy-frontend
kubectl get svc -n tunefy-prod -l app=tunefy-frontend
```

### Step 3: Deploy Backend (Manual Approval)

1. Go to Octopus: `Tasks`
2. Find backend deployment (waiting for approval)
3. Review changes
4. Click `Approve`
5. Backend deploys with Blue/Green strategy

```bash
# Monitor
kubectl get pods -n tunefy-prod -l app=tunefy-backend -w
```

### Step 4: Create Ingress

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tunefy-prod
  namespace: tunefy-prod
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  rules:
    - host: tunefy-prod.yourdomain.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: tunefy-backend
                port:
                  number: 3000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tunefy-frontend
                port:
                  number: 80
EOF

# Get ALB DNS
kubectl get ingress -n tunefy-prod
```

### Step 5: Configure DNS

Point your domain to the ALB:
```
tunefy-prod.yourdomain.com → CNAME → k8s-tunefyprod-xxx.elb.us-east-1.amazonaws.com
```

---

## ✅ Verification Checklist

### Infrastructure
- [ ] VPC created with 2 AZs
- [ ] 1 NAT Gateway deployed
- [ ] Bastion accessible via SSH
- [ ] 1 CP + 2 Workers running
- [ ] NLB configured for API server

### Kubernetes
- [ ] All nodes Ready
- [ ] Calico CNI working
- [ ] Namespace `tunefy-prod` exists
- [ ] StorageClass gp3 configured

### Database
- [ ] CloudNativePG operator installed
- [ ] PostgreSQL cluster with 2 instances
- [ ] Schema initialized
- [ ] Backups configured to S3

### Secrets
- [ ] `tunefy-db-credentials` created
- [ ] `backend-secrets` created
- [ ] `ecr-creds` created and auto-refreshing
- [ ] No secrets in Git

### Monitoring
- [ ] Prometheus Stack installed
- [ ] Alertmanager configured
- [ ] Slack integration working
- [ ] Custom alerts created
- [ ] Grafana accessible

### Deployment
- [ ] Frontend deployed and healthy
- [ ] Backend deployed and healthy
- [ ] Ingress/ALB configured
- [ ] DNS pointing to production
- [ ] Application accessible

---

## 🔧 Troubleshooting

### Workers not joining cluster

```bash
# Check SSM parameter exists
aws ssm get-parameter \
  --name /tunefy/prod/k8s/join-command \
  --region us-east-1

# Check worker logs
ssh -J ubuntu@<BASTION_IP> ubuntu@<WORKER_IP>
tail -f /var/log/user-data.log

# Manual join
sudo /root/join-command.sh
```

### ECR authentication fails

```bash
# Manually refresh
kubectl delete secret ecr-creds -n tunefy-prod
kubectl create secret docker-registry ecr-creds \
  --docker-server=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=tunefy-prod
```

### Database connection issues

```bash
# Test from backend pod
kubectl exec -it <backend-pod> -n tunefy-prod -- \
  nc -zv tunefy-db-rw.tunefy-prod.svc.cluster.local 5432
```

---

## 📞 Support

- **Slack Alerts:** `#tunefy-prod-alerts`
- **Grafana:** Port-forward to access
- **Logs:** `kubectl logs -f deployment/<name> -n tunefy-prod`

---

**🎉 ¡Ambiente de Producción Completo!**



