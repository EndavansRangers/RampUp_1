# 🚀 Comandos de Deployment - Tunefy Producción

**Instancias:** c7i-flex.large (2 vCPU, 4GB RAM) - CP y Workers  
**Ejecución:** Manual por consola (paso a paso)

---

## ✅ Pre-requisitos

### 1. Verificar herramientas instaladas

```bash
# Terraform
terraform --version

# AWS CLI
aws --version

# kubectl
kubectl version --client

# Helm
helm version

# jq (para procesar JSON)
sudo apt-get install jq -y  # Linux
# brew install jq  # macOS
```

### 2. Configurar AWS CLI (nueva cuenta)

```bash
aws configure

# Ingresa:
# AWS Access Key ID: [tu-access-key]
# AWS Secret Access Key: [tu-secret-key]
# Default region name: us-east-1
# Default output format: json

# Verificar
aws sts get-caller-identity
```

### 3. Crear SSH Key Pair

```bash
# Crear key pair
aws ec2 create-key-pair \
  --key-name tunefy-prod-key \
  --query 'KeyMaterial' \
  --output text > tunefy-prod-key.pem

# Permisos correctos
chmod 400 tunefy-prod-key.pem

# Verificar
ls -la tunefy-prod-key.pem
```

### 4. Obtener tu IP pública

```bash
curl ifconfig.me

# Anota esta IP: _________________
```

---

## 📡 FASE 1: Network Module (VPC)

### Paso 1: Ir al directorio

```bash
cd infra/terraform/network
pwd  # Verificar que estás en: .../infra/terraform/network
```

### Paso 2: Copiar configuración

```bash
# Copiar el archivo de producción
cp terraform-prod.tfvars terraform.tfvars

# Ver el contenido
cat terraform.tfvars
```

### Paso 3: Inicializar Terraform

```bash
terraform init
```

### Paso 4: Planear

```bash
terraform plan -out=network.tfplan

# Revisar el plan (debe crear VPC, subnets, NAT, IGW, routes)
```

### Paso 5: Aplicar

```bash
terraform apply network.tfplan
```

### Paso 6: Guardar outputs

```bash
# Ver outputs
terraform output

# Guardar en variables (ejecuta uno por uno)
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNET_1=$(terraform output -json public_subnet_ids | jq -r '.[0]')
export PUBLIC_SUBNET_2=$(terraform output -json public_subnet_ids | jq -r '.[1]')
export PRIVATE_SUBNET_1=$(terraform output -json private_subnet_ids | jq -r '.[0]')
export PRIVATE_SUBNET_2=$(terraform output -json private_subnet_ids | jq -r '.[1]')

# Verificar
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"

# IMPORTANTE: Guarda estos valores en un archivo
cat > ~/tunefy-prod-network-outputs.txt <<EOF
VPC_ID=$VPC_ID
PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1
PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2
PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1
PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2
EOF

cat ~/tunefy-prod-network-outputs.txt
```

---

## 🏗️ FASE 2: Platform Module (ECR, IAM, S3)

### Paso 1: Ir al directorio

```bash
cd ../platform
pwd  # Verificar: .../infra/terraform/platform
```

### Paso 2: Copiar configuración

```bash
cp terraform-prod.tfvars terraform.tfvars

# Editar si necesitas cambiar el dominio
nano terraform.tfvars
# Cambia root_domain si tienes uno, o déjalo como está
```

### Paso 3: Inicializar

```bash
terraform init
```

### Paso 4: Planear

```bash
terraform plan -out=platform.tfplan

# Revisar: debe crear ECR repos, IAM roles, S3 bucket
```

### Paso 5: Aplicar

```bash
terraform apply platform.tfplan
```

### Paso 6: Guardar outputs

```bash
# Ver outputs
terraform output

# Guardar
export INSTANCE_PROFILE=$(terraform output -raw nodes_instance_profile_name)
export S3_BACKUP_BUCKET=$(terraform output -raw s3_postgresql_backups_bucket)
export ECR_FRONTEND=$(terraform output -json ecr_repo_urls | jq -r '.["tunefy-frontend"]')
export ECR_BACKEND=$(terraform output -json ecr_repo_urls | jq -r '.["tunefy-backend"]')

# Verificar
echo "Instance Profile: $INSTANCE_PROFILE"
echo "S3 Bucket: $S3_BACKUP_BUCKET"
echo "ECR Frontend: $ECR_FRONTEND"
echo "ECR Backend: $ECR_BACKEND"

# Guardar
cat >> ~/tunefy-prod-network-outputs.txt <<EOF
INSTANCE_PROFILE=$INSTANCE_PROFILE
S3_BACKUP_BUCKET=$S3_BACKUP_BUCKET
ECR_FRONTEND=$ECR_FRONTEND
ECR_BACKEND=$ECR_BACKEND
EOF
```

---

## ☸️ FASE 3: Compute Module (Kubernetes Cluster)

### Paso 1: Ir al directorio

```bash
cd ../compute-prod
pwd  # Verificar: .../infra/terraform/compute-prod
```

### Paso 2: Crear terraform.tfvars

```bash
# Cargar las variables guardadas
source ~/tunefy-prod-network-outputs.txt

# Obtener tu IP actual
MY_IP=$(curl -s ifconfig.me)

# Crear terraform.tfvars con los valores correctos
cat > terraform.tfvars <<EOF
project = "tunefy"
region  = "us-east-1"
env     = "prod"

# VPC y Subnets (desde network module)
vpc_id = "$VPC_ID"

public_subnet_ids = [
  "$PUBLIC_SUBNET_1",
  "$PUBLIC_SUBNET_2"
]

private_subnet_ids = [
  "$PRIVATE_SUBNET_1",
  "$PRIVATE_SUBNET_2"
]

# IAM (desde platform module)
nodes_instance_profile_name = "$INSTANCE_PROFILE"

# SSH
key_name = "tunefy-prod-key"
allowed_ssh_cidr = "$MY_IP/32"

# Kubernetes
cluster_name = "tunefy-prod"

# Instance Types - c7i-flex.large (2 vCPU, 4GB RAM)
cp_instance_type      = "c7i-flex.large"
wk_instance_type      = "c7i-flex.large"
bastion_instance_type = "t3.micro"

tags = {
  Owner       = "DevOps"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Project     = "Tunefy"
}
EOF

# Verificar el contenido
cat terraform.tfvars
```

### Paso 3: Inicializar

```bash
terraform init
```

### Paso 4: Planear (REVISA CUIDADOSAMENTE)

```bash
terraform plan -out=compute.tfplan

# IMPORTANTE: Verifica que muestre:
# - 1 Control Plane c7i-flex.large
# - 2 Workers c7i-flex.large
# - 1 Bastion t3.micro
# - NLB
# - Security Groups
```

### Paso 5: Aplicar (tomará ~10 minutos)

```bash
terraform apply compute.tfplan

# Espera a que termine...
```

### Paso 6: Guardar outputs

```bash
# Ver outputs
terraform output

# Guardar
export BASTION_IP=$(terraform output -raw bastion_public_ip)
export CP_PRIVATE_IP=$(terraform output -json cp_private_ips | jq -r '.[0]')
export NLB_DNS=$(terraform output -raw nlb_dns_name)

# Verificar
echo "Bastion IP: $BASTION_IP"
echo "Control Plane IP: $CP_PRIVATE_IP"
echo "NLB DNS: $NLB_DNS"

# Guardar
cat >> ~/tunefy-prod-network-outputs.txt <<EOF
BASTION_IP=$BASTION_IP
CP_PRIVATE_IP=$CP_PRIVATE_IP
NLB_DNS=$NLB_DNS
EOF

cat ~/tunefy-prod-network-outputs.txt
```

---

## ⏳ ESPERA: Cluster Initialization (5-10 minutos)

```bash
# El cluster de Kubernetes se está inicializando automáticamente
# Los user-data scripts están:
# 1. Instalando Kubernetes
# 2. Inicializando el Control Plane
# 3. Uniendo los Workers automáticamente

echo "Esperando 8 minutos para que el cluster se inicialice..."
sleep 480  # 8 minutos

# O simplemente espera y toma un café ☕
```

---

## 🔍 VERIFICACIÓN: Conectar al Cluster

### Paso 1: SSH al Bastion

```bash
# Cargar variables si es una nueva sesión
source ~/tunefy-prod-network-outputs.txt

# Conectar al bastion
ssh -i tunefy-prod-key.pem ubuntu@$BASTION_IP
```

### Paso 2: Desde Bastion, conectar al Control Plane

```bash
# Ya estás en el bastion
# Conectar al CP (usa la IP privada)
ssh ubuntu@<CP_PRIVATE_IP>

# Ejemplo:
# ssh ubuntu@10.30.1.10
```

### Paso 3: Verificar el cluster

```bash
# Ya estás en el Control Plane
# Verificar nodos
kubectl get nodes

# Deberías ver:
# NAME                  STATUS   ROLES           AGE   VERSION
# tunefy-prod-cp-xxx    Ready    control-plane   5m    v1.28.x
# tunefy-prod-wk-xxx    Ready    <none>          3m    v1.28.x
# tunefy-prod-wk-yyy    Ready    <none>          3m    v1.28.x

# Verificar pods del sistema
kubectl get pods -A

# Verificar namespace
kubectl get ns tunefy-prod
```

### Paso 4: Copiar kubeconfig a tu máquina local

```bash
# Desde tu máquina LOCAL (nueva terminal):
source ~/tunefy-prod-network-outputs.txt

# Copiar kubeconfig
scp -i tunefy-prod-key.pem \
  -o ProxyJump=ubuntu@$BASTION_IP \
  ubuntu@$CP_PRIVATE_IP:~/.kube/config \
  ~/.kube/config-tunefy-prod

# Configurar kubectl local
export KUBECONFIG=~/.kube/config-tunefy-prod

# Actualizar server URL al NLB
kubectl config set-cluster kubernetes --server=https://$NLB_DNS:6443

# Verificar desde local
kubectl get nodes
```

---

## 🗄️ FASE 4: CloudNativePG y PostgreSQL

### Paso 1: Instalar CloudNativePG Operator

```bash
# Desde tu máquina local (con KUBECONFIG configurado)
# O desde el Control Plane

kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml

# Verificar instalación
kubectl get pods -n cnpg-system

# Esperar a que esté ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cloudnative-pg \
  -n cnpg-system \
  --timeout=300s
```

### Paso 2: Crear StorageClass

```bash
kubectl apply -f k8s/prod/storageclass-gp3.yaml

# Verificar
kubectl get storageclass
```

### Paso 3: Crear secret de credenciales DB

```bash
# Generar password seguro
DB_PASSWORD=$(openssl rand -base64 32)

# Crear secret
kubectl create secret generic tunefy-db-credentials \
  --from-literal=username=tunefy_user \
  --from-literal=password="$DB_PASSWORD" \
  --namespace=tunefy-prod

# IMPORTANTE: Guardar el password
echo "DB_PASSWORD=$DB_PASSWORD" >> ~/tunefy-prod-secrets.txt
chmod 600 ~/tunefy-prod-secrets.txt

echo "Password guardado en: ~/tunefy-prod-secrets.txt"
cat ~/tunefy-prod-secrets.txt
```

### Paso 4: Crear secret para S3 backups

```bash
# Obteniendo región
AWS_REGION="us-east-1"

# Usando IAM role de la instancia (recomendado)
kubectl create secret generic aws-s3-creds \
  --from-literal=ACCESS_KEY_ID="" \
  --from-literal=ACCESS_SECRET_KEY="" \
  --from-literal=AWS_REGION="$AWS_REGION" \
  --namespace=tunefy-prod

# Nota: Deja ACCESS_KEY_ID y SECRET vacíos para usar instance IAM role
```

### Paso 5: Desplegar PostgreSQL Cluster

```bash
kubectl apply -f k8s/prod/tunefy-db-cluster-prod.yaml

# Monitorear deployment
kubectl get cluster -n tunefy-prod -w

# En otra terminal, ver los pods
kubectl get pods -n tunefy-prod -l cnpg.io/cluster=tunefy-db -w

# Esperar a que esté ready (2-3 minutos)
kubectl wait --for=condition=ready cluster/tunefy-db \
  -n tunefy-prod \
  --timeout=300s
```

### Paso 6: Inicializar schema de base de datos

```bash
# Copiar schema al pod
kubectl cp backend/database_setup.sql \
  tunefy-prod/tunefy-db-1:/tmp/schema.sql

# Ejecutar schema
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -f /tmp/schema.sql

# Verificar tablas
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -c '\dt'
```

---

## 🔐 FASE 5: Secrets de Aplicación

### Paso 1: Crear backend secrets

```bash
# Cargar DB password
source ~/tunefy-prod-secrets.txt

# Ingresar credenciales de Spotify
read -p "Spotify Client ID: " SPOTIFY_CLIENT_ID
read -sp "Spotify Client Secret: " SPOTIFY_CLIENT_SECRET
echo ""
read -p "Spotify Redirect URI [https://tunefy-prod.yourdomain.com/callback]: " SPOTIFY_REDIRECT_URI
SPOTIFY_REDIRECT_URI=${SPOTIFY_REDIRECT_URI:-https://tunefy-prod.yourdomain.com/callback}

# Generar session secret
SESSION_SECRET=$(openssl rand -base64 32)

# Crear secret
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
  --namespace=tunefy-prod

# Verificar
kubectl get secret backend-secrets -n tunefy-prod
```

### Paso 2: Crear ECR pull secret

```bash
# Obtener account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

# Obtener token ECR
TOKEN=$(aws ecr get-login-password --region $AWS_REGION)

# Crear secret
kubectl create secret docker-registry ecr-creds \
  --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --namespace=tunefy-prod

# Verificar
kubectl get secret ecr-creds -n tunefy-prod
```

### Paso 3: Desplegar ECR token auto-refresh

```bash
kubectl apply -f k8s/prod/ecr-token-refresh-cronjob.yaml

# Verificar CronJob
kubectl get cronjob -n tunefy-prod

# Test manual (opcional)
kubectl create job --from=cronjob/ecr-token-refresh test-refresh -n tunefy-prod
kubectl logs job/test-refresh -n tunefy-prod
```

---

## 🌐 FASE 6: AWS Load Balancer Controller

### Paso 1: Instalar cert-manager

```bash
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Esperar
sleep 20

# Verificar
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s
```

### Paso 2: Instalar AWS LB Controller

```bash
# Agregar repo Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Cargar VPC_ID
source ~/tunefy-prod-network-outputs.txt

# Instalar
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tunefy-prod \
  --set serviceAccount.create=false \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID

# Verificar
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 📊 FASE 7: Monitoring Stack

### Paso 1: Instalar Prometheus Stack

```bash
# Agregar repo
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set alertmanager.enabled=true \
  --set grafana.adminPassword='TunefyProd2024!'

# Esperar
sleep 30

# Verificar
kubectl get pods -n monitoring -w
```

### Paso 2: Aplicar alertas personalizadas

```bash
kubectl apply -f k8s/prod/prometheus-rules.yaml

# Verificar
kubectl get prometheusrule -n monitoring
```

### Paso 3: Configurar Alertmanager (Slack)

```bash
# Si tienes webhook de Slack
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

kubectl create secret generic alertmanager-slack \
  --from-literal=webhook-url="$SLACK_WEBHOOK" \
  --namespace=monitoring

# Aplicar configuración
kubectl apply -f k8s/prod/alertmanager-config.yaml
```

### Paso 4: Acceder a Grafana

```bash
# Port-forward
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80

# Abrir: http://localhost:3000
# User: admin
# Password: TunefyProd2024!
```

---

## 🎉 Resumen de Comandos Completados

```bash
# Ver todos los recursos
kubectl get all -n tunefy-prod
kubectl get all -n monitoring

# Ver secrets
kubectl get secrets -n tunefy-prod

# Ver nodos
kubectl get nodes -o wide

# Ver cluster info
kubectl cluster-info
```

---

## 📋 Siguiente Paso: Octopus Deploy

Ver sección **FASE 7** del archivo `DEPLOYMENT-GUIDE-PROD.md` para:
1. Crear environment "Production" en Octopus
2. Registrar deployment target
3. Configurar variables
4. Primer deployment

---

## 🆘 Troubleshooting

### Workers no se unen al cluster

```bash
# Verificar SSM parameter
aws ssm get-parameter \
  --name /tunefy/prod/k8s/join-command \
  --region us-east-1 \
  --with-decryption

# Ver logs de worker
ssh -J ubuntu@$BASTION_IP ubuntu@<WORKER_PRIVATE_IP>
tail -f /var/log/user-data.log
```

### ECR pull fails

```bash
# Regenerar token
kubectl delete secret ecr-creds -n tunefy-prod
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry ecr-creds \
  --docker-server=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --namespace=tunefy-prod
```

---

**¡Todo listo para deployar aplicaciones!** 🚀



