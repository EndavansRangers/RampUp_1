# 🚀 Plan Completo para Ambiente de Producción - Tunefy

**Fecha:** 9 de octubre de 2025  
**Objetivo:** Crear ambiente de producción completo con estrategias de deployment diferenciadas para frontend y backend

---

## 📋 Requisitos de Negocio

✅ **Infraestructura:** Terraform (no Ansible) para aprovisionamiento  
✅ **Frontend:** Continuous Deployment (auto a Prod)  
✅ **Backend:** Continuous Delivery (requiere aprobación manual para Prod)  
✅ **Secrets:** Activos y seguros (sin dejar secretos en Git)  
✅ **Base de Datos:** CloudNativePG (operador + clúster Postgres HA)  
✅ **Alertas:** Alertmanager → Slack  
✅ **Instancias:** c7i-flex.large con 30 GB gp3 (CP y Workers)

---

## 🏗️ Arquitectura de Producción

```
┌─────────────────────────────────────────────────────────────────┐
│                   AWS VPC (10.20.0.0/16) - PROD                 │
│                                                                 │
│  ┌──────────────┐      ┌────────────────────────────────────┐ │
│  │   Bastion    │      │   Kubernetes Cluster (PROD)        │ │
│  │  (Public)    │─────▶│                                    │ │
│  └──────────────┘      │  • CP: 1x c7i-flex.large (30GB)   │ │
│                        │  • Workers: 2x c7i-flex.large      │ │
│                        │  • PostgreSQL HA (CloudNativePG)   │ │
│                        │  • Namespace: tunefy-prod          │ │
│                        └────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              CI/CD Pipeline (TeamCity)                    │ │
│  │  ┌─────────────────────────────────────────────────┐    │ │
│  │  │  1. Build & Test (ambos ambientes)              │    │ │
│  │  │  2. Push to ECR                                  │    │ │
│  │  │  3. Trigger Octopus Deploy                       │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │            Octopus Deploy (CD Strategies)                 │ │
│  │                                                            │ │
│  │  FRONTEND (Continuous Deployment):                        │ │
│  │  ├─ Dev: Auto deploy on commit                           │ │
│  │  └─ Prod: Auto deploy (Rolling Update)                   │ │
│  │                                                            │ │
│  │  BACKEND (Continuous Delivery):                           │ │
│  │  ├─ Dev: Auto deploy on commit                           │ │
│  │  └─ Prod: Manual approval required (Blue/Green)          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Monitoring & Alerting (Prometheus Stack)          │ │
│  │  • Alertmanager → Slack (prod alerts)                    │ │
│  │  • Grafana dashboards                                     │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 FASE 1: Preparar Terraform para Producción

### Paso 1.1: Actualizar `compute-prod/k8s_asg.tf`

**Cambios requeridos:**

1. **Control Plane:** c7i-flex.large con 30 GB gp3
2. **Workers:** c7i-flex.large con 30 GB gp3
3. **User data:** Script Terraform para k8s setup (sin Ansible)

**Archivo:** `infra/terraform/compute-prod/k8s_asg.tf`

```terraform
# Launch Template CP
resource "aws_launch_template" "cp" {
  name_prefix   = "${local.name}-cp-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "c7i-flex.large"  # 2 vCPU, 4GB RAM
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30  # 30 GB gp3
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.cp.id]

  user_data = base64encode(templatefile("${path.module}/user-data-cp-prod.sh", {
    cluster_name = var.cluster_name
    pod_cidr     = "192.168.0.0/16"
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { 
      Name = "${local.name}-cp"
      Role = "control-plane"
    })
  }
}

# ASG CP (1 node para prod)
resource "aws_autoscaling_group" "cp" {
  name                      = "${local.name}-cp-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.cp.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${local.name}-cp"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "prod"
    propagate_at_launch = true
  }
}

# Launch Template Worker
resource "aws_launch_template" "wk" {
  name_prefix   = "${local.name}-wk-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "c7i-flex.large"  # 2 vCPU, 4GB RAM
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30  # 30 GB gp3
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.wk.id]

  user_data = base64encode(templatefile("${path.module}/user-data-wk-prod.sh", {
    cluster_name = var.cluster_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { 
      Name = "${local.name}-wk"
      Role = "worker"
    })
  }
}

# ASG Worker (2 nodes para prod)
resource "aws_autoscaling_group" "wk" {
  name                      = "${local.name}-wk-asg"
  max_size                  = 2
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.wk.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${local.name}-wk"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "prod"
    propagate_at_launch = true
  }
}
```

---

### Paso 1.2: Crear User Data Scripts para Kubernetes

**Archivo:** `infra/terraform/compute-prod/user-data-cp-prod.sh`

```bash
#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Control Plane Setup for Production ==="

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Install containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.28.* kubeadm=1.28.* kubectl=1.28.*
apt-mark hold kubelet kubeadm kubectl

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Initialize cluster
PRIVATE_IP=$(hostname -I | awk '{print $1}')
kubeadm init \
  --pod-network-cidr=${pod_cidr} \
  --apiserver-advertise-address=$PRIVATE_IP \
  --control-plane-endpoint=$PRIVATE_IP \
  --upload-certs

# Setup kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Setup kubectl for root
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Install Calico CNI
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Save join command
kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
chmod +x /home/ubuntu/join-command.sh

echo "=== Control Plane Setup Complete ==="
```

**Archivo:** `infra/terraform/compute-prod/user-data-wk-prod.sh`

```bash
#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Worker Setup for Production ==="

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Install containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.28.* kubeadm=1.28.* kubectl=1.28.*
apt-mark hold kubelet kubeadm kubectl

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "=== Worker node ready for manual join ==="
echo "Run the join command from Control Plane: /home/ubuntu/join-command.sh"
```

---

### Paso 1.3: Actualizar variables de Terraform

**Archivo:** `infra/terraform/compute-prod/terraform.tfvars`

```hcl
project     = "tunefy"
region      = "us-east-1"
env         = "prod"
cluster_name = "tunefy-prod"

# Instance types - c7i-flex.large (2 vCPU, 4GB RAM)
cp_instance_type      = "c7i-flex.large"
wk_instance_type      = "c7i-flex.large"
bastion_instance_type = "t3.micro"

# Network (from network module outputs)
vpc_id             = "vpc-xxxxx"  # Output from network module
public_subnet_ids  = ["subnet-xxx", "subnet-yyy"]
private_subnet_ids = ["subnet-aaa", "subnet-bbb"]

# SSH
key_name         = "tunefy-prod-key"
allowed_ssh_cidr = "YOUR_IP/32"  # Your public IP

# IAM (from platform module)
nodes_instance_profile_name = "tunefy-prod-k8s-nodes"

tags = {
  ManagedBy = "Terraform"
  Purpose   = "Production K8s Cluster"
}
```

---

### Paso 1.4: Aplicar Terraform

```bash
cd infra/terraform/compute-prod

# 1. Initialize
terraform init

# 2. Plan
terraform plan -out=prod.tfplan

# 3. Apply
terraform apply prod.tfplan

# 4. Get outputs
terraform output
```

**Outputs esperados:**
- `bastion_public_ip`: IP pública del bastion
- `cp_private_ips`: IPs privadas de control planes
- `nlb_dns_name`: DNS del NLB para acceso al API server

---

## 📝 FASE 2: Configurar Kubernetes Manualmente

### Paso 2.1: Conectar al Bastion y luego al Control Plane

```bash
# Conectar a bastion
ssh -i tunefy-prod-key.pem ubuntu@<BASTION_PUBLIC_IP>

# Desde bastion, conectar a CP
ssh ubuntu@<CP_PRIVATE_IP>

# Verificar que el cluster esté up
kubectl get nodes
```

### Paso 2.2: Unir Workers al Cluster

```bash
# En cada worker node:
sudo /home/ubuntu/join-command.sh

# Verificar desde CP:
kubectl get nodes
# Deberías ver: 1 CP + 2 Workers (Ready)
```

---

## 📝 FASE 3: Instalar CloudNativePG y PostgreSQL

### Paso 3.1: Instalar CloudNativePG Operator

**Desde el Control Plane:**

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml

# Verificar instalación
kubectl get pods -n cnpg-system
```

### Paso 3.2: Crear Namespace de Producción

```bash
kubectl create namespace tunefy-prod
```

### Paso 3.3: Crear Secret para PostgreSQL

```bash
kubectl create secret generic tunefy-db-credentials \
  --from-literal=username=tunefy_user \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=tunefy-prod
```

### Paso 3.4: Crear StorageClass gp3

**Archivo:** `k8s/storageclass-gp3-prod.yaml`

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

```bash
kubectl apply -f k8s/storageclass-gp3-prod.yaml
```

### Paso 3.5: Desplegar PostgreSQL Cluster

**Archivo:** `charts/tunefy-db-cluster-prod.yaml`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: tunefy-db
  namespace: tunefy-prod
spec:
  instances: 2  # HA para prod
  imageName: ghcr.io/cloudnative-pg/postgresql:16.1
  
  storage:
    storageClass: gp3
    size: 10Gi
  
  bootstrap:
    initdb:
      database: tunefy
      owner: tunefy_user
      secret:
        name: tunefy-db-credentials
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  monitoring:
    enablePodMonitor: true
  
  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"
      work_mem: "4MB"
      maintenance_work_mem: "64MB"
      effective_cache_size: "512MB"
    pg_hba:
      - host all all all scram-sha-256
  
  primaryUpdateStrategy: unsupervised
  
  backup:
    barmanObjectStore:
      destinationPath: s3://tunefy-prod-backups/postgresql
      s3Credentials:
        accessKeyId:
          name: aws-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: aws-creds
          key: ACCESS_SECRET_KEY
    retentionPolicy: "30d"
```

```bash
kubectl apply -f charts/tunefy-db-cluster-prod.yaml

# Esperar a que esté ready
kubectl wait --for=condition=ready pod/tunefy-db-1 -n tunefy-prod --timeout=300s
```

---

## 📝 FASE 4: Configurar Secrets en Kubernetes

### Paso 4.1: Crear Secret para Backend (Spotify API + DB)

```bash
kubectl create secret generic backend-secrets \
  --from-literal=SPOTIFY_CLIENT_ID='your-client-id' \
  --from-literal=SPOTIFY_CLIENT_SECRET='your-client-secret' \
  --from-literal=SPOTIFY_REDIRECT_URI='https://tunefy-prod.yourdomain.com/callback' \
  --from-literal=SESSION_SECRET=$(openssl rand -base64 32) \
  --from-literal=PGHOST='tunefy-db-rw.tunefy-prod.svc.cluster.local' \
  --from-literal=PGPORT='5432' \
  --from-literal=PGDATABASE='tunefy' \
  --from-literal=PGUSER='tunefy_user' \
  --from-literal=PGPASSWORD='<password-from-db-secret>' \
  --namespace=tunefy-prod
```

### Paso 4.2: Crear Secret para ECR Pull

```bash
# En el CP (tiene IAM role con acceso a ECR)
ACCOUNT_ID="365074502389"
REGION="us-east-1"
TOKEN=$(aws ecr get-login-password --region $REGION)

kubectl create secret docker-registry ecr-creds \
  --docker-server=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --namespace=tunefy-prod
```

---

## 📝 FASE 5: Configurar Octopus Deploy para Producción

### Paso 5.1: Crear Environment "Production" en Octopus

1. En Octopus UI: `Infrastructure → Environments → Add Environment`
2. Nombre: `Production`
3. Descripción: `Tunefy Production Environment`

### Paso 5.2: Registrar Deployment Target para Prod

Desde el CP de producción:

```bash
# Crear ServiceAccount para Octopus
kubectl create serviceaccount octopus-deploy -n tunefy-prod

# Crear ClusterRoleBinding
kubectl create clusterrolebinding octopus-deploy-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=tunefy-prod:octopus-deploy

# Obtener token
kubectl create token octopus-deploy -n tunefy-prod --duration=8760h > octopus-token.txt
```

En Octopus UI:
1. `Infrastructure → Deployment Targets → Add Deployment Target`
2. Tipo: `Kubernetes Cluster`
3. Nombre: `tunefy-prod-cluster`
4. URL: `https://<NLB_DNS>:6443`
5. Token: (pegar contenido de octopus-token.txt)
6. Environment: `Production`
7. Roles: `k8s-deployer`

### Paso 5.3: Crear Variables para Producción

En Octopus: `Variables → Add Variable`

| Variable | Value | Scope | Notes |
|----------|-------|-------|-------|
| `Kubernetes.Token` | `<token>` | Production | Token del SA |
| `ECR.AccountId` | `365074502389` | Production | Account ID |
| `ECR.Region` | `us-east-1` | Production | ECR region |
| `Backend.Replicas` | `2` | Production | 2 réplicas HA |
| `Frontend.Replicas` | `2` | Production | 2 réplicas HA |
| `Namespace` | `tunefy-prod` | Production | K8s namespace |

---

## 📝 FASE 6: Actualizar Deployment Process en Octopus

### Paso 6.1: Agregar Aprobación Manual para Backend en Prod

**Archivo:** `.octopus/deployment_process.ocl`

Agregar step de aprobación antes del deploy de backend:

```hcl
step "approve-backend-prod" {
    name = "Manual Approval for Backend Production"
    properties = {
        Octopus.Action.Manual.BlockConcurrentDeployments = "True"
        Octopus.Action.Manual.Instructions = "Review backend changes before deploying to production"
    }

    action {
        action_type = "Octopus.Manual"
        environments = ["production"]
        is_required = true
        notes = "Require manual approval before deploying backend to production"
        properties = {
            Octopus.Action.Manual.ResponsibleTeamIds = "teams-everyone"
        }
    }
}

step "deploy-backend" {
    name = "Deploy Backend"
    start_trigger = "StartAfterPrevious"
    
    # ... existing backend deploy logic ...
    
    action {
        action_type = "Octopus.Script"
        environments = ["dev", "production"]  # Add production
        # ... rest of action ...
    }
}
```

### Paso 6.2: Actualizar Deploy Scripts para Prod

**Backend Deploy Script** (Blue/Green para prod):

```bash
#!/bin/bash
set -euo pipefail

NAMESPACE="#{Namespace}"
IMAGE_TAG="#{Octopus.Release.Number}"
ENVIRONMENT="#{Octopus.Environment.Name}"

if [ "$ENVIRONMENT" == "Production" ]; then
  echo "=== Deploying Backend to PRODUCTION (Blue/Green) ==="
  
  # Blue/Green: Deploy new version alongside current
  helm upgrade --install tunefy-backend-green charts/backend \
    -f charts/backend/values-prod.yaml \
    --set image.tag=$IMAGE_TAG \
    --set nameOverride=tunefy-backend-green \
    --namespace=$NAMESPACE \
    --timeout=5m \
    --wait
  
  echo "Green deployment ready. Verify before switching traffic."
  echo "Run: kubectl get pods -n $NAMESPACE -l app=tunefy-backend-green"
  
else
  echo "=== Deploying Backend to DEV ==="
  
  helm upgrade --install tunefy-backend charts/backend \
    -f charts/backend/values-dev.yaml \
    --set image.tag=$IMAGE_TAG \
    --namespace=$NAMESPACE \
    --timeout=3m \
    --wait
fi
```

**Frontend Deploy Script** (Rolling Update para prod):

```bash
#!/bin/bash
set -euo pipefail

NAMESPACE="#{Namespace}"
IMAGE_TAG="#{Octopus.Release.Number}"
ENVIRONMENT="#{Octopus.Environment.Name}"

if [ "$ENVIRONMENT" == "Production" ]; then
  echo "=== Deploying Frontend to PRODUCTION (Rolling Update) ==="
  
  helm upgrade --install tunefy-frontend charts/frontend \
    -f charts/frontend/values-prod.yaml \
    --set image.tag=$IMAGE_TAG \
    --namespace=$NAMESPACE \
    --timeout=5m \
    --wait
  
else
  echo "=== Deploying Frontend to DEV ==="
  
  helm upgrade --install tunefy-frontend charts/frontend \
    -f charts/frontend/values-dev.yaml \
    --set image.tag=$IMAGE_TAG \
    --namespace=$NAMESPACE \
    --timeout=3m \
    --wait
fi
```

---

## 📝 FASE 7: Configurar Alerting (Prometheus + Alertmanager → Slack)

### Paso 7.1: Instalar Prometheus Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set alertmanager.enabled=true
```

### Paso 7.2: Configurar Alertmanager para Slack

**Crear Secret con Slack Webhook:**

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

kubectl create secret generic alertmanager-slack \
  --from-literal=webhook-url=$SLACK_WEBHOOK_URL \
  --namespace=monitoring
```

**Archivo:** `k8s/alertmanager-config-prod.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'SLACK_WEBHOOK_URL_FROM_SECRET'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack-prod'
      routes:
        - match:
            severity: critical
          receiver: 'slack-prod'
          continue: true
    
    receivers:
      - name: 'slack-prod'
        slack_configs:
          - channel: '#tunefy-prod-alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: >-
              {{ range .Alerts }}
                *Alert:* {{ .Annotations.summary }}
                *Description:* {{ .Annotations.description }}
                *Severity:* {{ .Labels.severity }}
              {{ end }}
            send_resolved: true
```

```bash
kubectl apply -f k8s/alertmanager-config-prod.yaml
```

### Paso 7.3: Crear Alertas Personalizadas

**Archivo:** `k8s/alerts-prod.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tunefy-prod-alerts
  namespace: monitoring
spec:
  groups:
    - name: tunefy-prod
      interval: 30s
      rules:
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total{namespace="tunefy-prod"}[5m]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod is crash looping in production"
            description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
        
        - alert: HighMemoryUsage
          expr: container_memory_usage_bytes{namespace="tunefy-prod"} / container_spec_memory_limit_bytes > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage detected"
            description: "Container {{ $labels.container }} in pod {{ $labels.pod }} is using > 90% memory"
        
        - alert: PostgreSQLDown
          expr: pg_up{namespace="tunefy-prod"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "PostgreSQL is down"
            description: "PostgreSQL cluster in tunefy-prod is not responding"
        
        - alert: DeploymentReplicasMismatch
          expr: kube_deployment_spec_replicas{namespace="tunefy-prod"} != kube_deployment_status_replicas_available{namespace="tunefy-prod"}
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Deployment replicas mismatch"
            description: "Deployment {{ $labels.deployment }} has {{ $value }} replicas available, expected {{ $labels.spec_replicas }}"
```

```bash
kubectl apply -f k8s/alerts-prod.yaml
```

---

## 📝 FASE 8: Inicializar Base de Datos

### Paso 8.1: Ejecutar Schema SQL

```bash
# Desde CP, copiar schema al pod de PostgreSQL
kubectl cp backend/database_setup.sql tunefy-prod/tunefy-db-1:/tmp/

# Ejecutar schema
kubectl exec -it tunefy-db-1 -n tunefy-prod -- \
  psql -U tunefy_user -d tunefy -f /tmp/database_setup.sql
```

---

## 📝 FASE 9: Primer Deploy a Producción

### Paso 9.1: Trigger Pipeline desde TeamCity

1. Commit código a `main` branch
2. TeamCity ejecuta build
3. Push images a ECR
4. Trigger Octopus deployment

### Paso 9.2: Deploy Frontend (Auto)

Frontend se desplegará automáticamente a producción (Continuous Deployment).

```bash
# Monitorear desde CP:
kubectl get pods -n tunefy-prod -l app=tunefy-frontend -w
```

### Paso 9.3: Deploy Backend (Manual Approval)

1. En Octopus UI, ir a Tasks
2. Ver deployment esperando aprobación
3. Revisar cambios
4. Aprobar deployment
5. Backend se despliega con estrategia Blue/Green

```bash
# Monitorear desde CP:
kubectl get pods -n tunefy-prod -l app=tunefy-backend -w
```

### Paso 9.4: Verificar Deployment

```bash
# Verificar todos los pods
kubectl get pods -n tunefy-prod

# Verificar servicios
kubectl get svc -n tunefy-prod

# Verificar ingress/ALB
kubectl get ingress -n tunefy-prod

# Test de conectividad
curl https://tunefy-prod.yourdomain.com/health
```

---

## 📋 Checklist de Validación

### ✅ Infraestructura
- [ ] Cluster de K8s levantado (1 CP + 2 Workers, c7i-flex.large, 30GB)
- [ ] Bastion accesible por SSH
- [ ] NLB configurado para acceso al API server
- [ ] Security groups correctamente configurados

### ✅ Kubernetes
- [ ] Todos los nodos en estado Ready
- [ ] CNI (Calico) funcionando
- [ ] Namespace `tunefy-prod` creado
- [ ] StorageClass gp3 configurado

### ✅ Base de Datos
- [ ] CloudNativePG operator instalado
- [ ] PostgreSQL cluster con 2 instancias (HA)
- [ ] Schema inicializado
- [ ] Backups configurados a S3

### ✅ Secrets
- [ ] `tunefy-db-credentials` creado
- [ ] `backend-secrets` creado (Spotify + DB)
- [ ] `ecr-creds` creado
- [ ] Ningún secret en Git

### ✅ Octopus Deploy
- [ ] Environment "Production" creado
- [ ] Target `tunefy-prod-cluster` registrado
- [ ] Variables de producción configuradas
- [ ] Aprobación manual para backend configurada
- [ ] Auto-deploy para frontend configurado

### ✅ Monitoring & Alerting
- [ ] Prometheus Stack instalado
- [ ] Alertmanager configurado
- [ ] Integración con Slack funcionando
- [ ] Alertas personalizadas creadas
- [ ] Grafana accesible

### ✅ Deployment
- [ ] Frontend desplegado y funcionando
- [ ] Backend desplegado y funcionando
- [ ] Pods healthy (readiness/liveness passing)
- [ ] Ingress/ALB configurado
- [ ] DNS apuntando a producción
- [ ] SSL/TLS funcionando

---

## 🔐 Consideraciones de Seguridad

1. **Secrets Management:**
   - Todos los secrets en Kubernetes (no en Git)
   - Rotar passwords periódicamente
   - Usar AWS Secrets Manager para secrets críticos

2. **Network Policies:**
   - Implementar network policies para aislar namespaces
   - Restringir acceso a PostgreSQL solo desde backend

3. **RBAC:**
   - ServiceAccounts con permisos mínimos
   - No usar cluster-admin en producción (refinarlo)

4. **Backups:**
   - PostgreSQL backups automáticos cada 24h
   - Retention de 30 días
   - Test de restore mensualmente

---

## 📊 Estrategias de Deployment

### Frontend (Continuous Deployment)
- **Estrategia:** Rolling Update
- **Razón:** Cambios visuales, bajo riesgo
- **Aprobación:** Automática
- **Rollback:** Automático si health checks fallan

### Backend (Continuous Delivery)
- **Estrategia:** Blue/Green
- **Razón:** Cambios en lógica de negocio, API, DB
- **Aprobación:** Manual requerida
- **Rollback:** Manual, switch traffic de Green a Blue

---

## 🚀 Comandos Rápidos de Operación

### Escalar aplicaciones
```bash
kubectl scale deployment tunefy-frontend --replicas=3 -n tunefy-prod
kubectl scale deployment tunefy-backend --replicas=3 -n tunefy-prod
```

### Ver logs
```bash
kubectl logs -f deployment/tunefy-frontend -n tunefy-prod
kubectl logs -f deployment/tunefy-backend -n tunefy-prod
```

### Rollback
```bash
helm rollback tunefy-frontend -n tunefy-prod
helm rollback tunefy-backend -n tunefy-prod
```

### Verificar salud del cluster
```bash
kubectl get nodes
kubectl top nodes
kubectl top pods -n tunefy-prod
```

---

## 📞 Contactos y Recursos

- **Alertas Slack:** `#tunefy-prod-alerts`
- **Grafana:** `https://grafana.tunefy-prod.yourdomain.com`
- **Octopus UI:** `http://<octopus-ip>:8080`
- **Documentación:** Este archivo

---

**🎉 Con este plan, tendrás un ambiente de producción robusto, seguro y con las estrategias de deployment diferenciadas según los requisitos de negocio.**
