# 🚀 Tunefy - Ambiente de Producción

## 📋 Resumen Ejecutivo

Ambiente de producción completo para **Tunefy** en AWS con:
- **Infraestructura como Código:** Terraform
- **Kubernetes:** Self-managed cluster (1 CP + 2 Workers)
- **Instancias:** c7i-flex.large (2 vCPU, 4GB RAM)
- **Base de Datos:** PostgreSQL HA con CloudNativePG
- **CI/CD:** TeamCity + Octopus Deploy
- **Estrategias de Deploy:**
  - Frontend: Continuous Deployment (auto)
  - Backend: Continuous Delivery (aprobación manual)

---

## 📁 Estructura del Proyecto

```
RampUp_1/
├── infra/terraform/
│   ├── network/              # VPC, Subnets, NAT, IGW
│   │   └── terraform-prod.tfvars
│   ├── platform/             # ECR, IAM, S3 backups
│   │   └── terraform-prod.tfvars
│   └── compute-prod/         # K8s Cluster (CP + Workers)
│       ├── terraform.tfvars.example
│       ├── user-data-cp-prod.sh      # Kubernetes CP setup
│       ├── user-data-wk-prod.sh      # Worker auto-join
│       └── k8s_asg.tf
│
├── k8s/prod/
│   ├── storageclass-gp3.yaml         # StorageClass gp3
│   ├── tunefy-db-cluster-prod.yaml   # PostgreSQL HA
│   ├── ecr-token-refresh-cronjob.yaml # ECR auto-refresh
│   ├── prometheus-rules.yaml          # Custom alerts
│   └── alertmanager-config.yaml       # Slack integration
│
├── charts/
│   ├── backend/
│   │   ├── values-prod.yaml
│   │   └── Chart.yaml
│   └── frontend/
│       ├── values-prod.yaml
│       └── Chart.yaml
│
├── COMANDOS-DEPLOYMENT-PROD.md   # 👈 GUÍA PRINCIPAL
├── DEPLOYMENT-GUIDE-PROD.md      # Guía detallada paso a paso
├── PLAN-PRODUCCION-COMPLETO.md   # Plan original completo
└── README-PRODUCCION.md          # Este archivo
```

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                   AWS VPC (10.30.0.0/16) - PROD                 │
│                                                                 │
│  ┌──────────────┐      ┌────────────────────────────────────┐ │
│  │   Bastion    │      │   Kubernetes Cluster               │ │
│  │  t3.micro    │─────▶│                                    │ │
│  └──────────────┘      │  • CP: 1x c7i-flex.large (4GB)    │ │
│                        │  • Workers: 2x c7i-flex.large      │ │
│                        │  • PostgreSQL HA (CloudNativePG)   │ │
│                        │  • Namespace: tunefy-prod          │ │
│                        └────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              CI/CD Pipeline (TeamCity)                    │ │
│  │  ┌─────────────────────────────────────────────────┐    │ │
│  │  │  1. Build & Test                                 │    │ │
│  │  │  2. Push to ECR                                  │    │ │
│  │  │  3. Trigger Octopus Deploy                       │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │            Octopus Deploy (CD Strategies)                 │ │
│  │                                                            │ │
│  │  FRONTEND: Auto deploy (Rolling Update)                  │ │
│  │  BACKEND:  Manual approval (Blue/Green)                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Monitoring (Prometheus + Grafana)                 │ │
│  │  • Alertmanager → Slack                                  │ │
│  │  • Custom alerts para producción                         │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Herramientas necesarias
- Terraform >= 1.0
- AWS CLI configurado
- kubectl
- Helm 3
- Nueva cuenta AWS

# Crear SSH key
aws ec2 create-key-pair \
  --key-name tunefy-prod-key \
  --query 'KeyMaterial' \
  --output text > tunefy-prod-key.pem
chmod 400 tunefy-prod-key.pem
```

### 2. Deploy Infrastructure

**👉 Sigue la guía completa:** [`COMANDOS-DEPLOYMENT-PROD.md`](COMANDOS-DEPLOYMENT-PROD.md)

Resumen:
```bash
# 1. Network
cd infra/terraform/network
terraform init
terraform apply

# 2. Platform  
cd ../platform
terraform init
terraform apply

# 3. Compute (Kubernetes)
cd ../compute-prod
terraform init
terraform apply

# Esperar 5-10 minutos para inicialización del cluster
```

### 3. Setup Kubernetes

```bash
# Conectar al cluster
ssh -i tunefy-prod-key.pem ubuntu@<BASTION_IP>
ssh ubuntu@<CP_PRIVATE_IP>

# Verificar
kubectl get nodes

# Instalar componentes (ver COMANDOS-DEPLOYMENT-PROD.md)
# - CloudNativePG
# - PostgreSQL
# - Secrets
# - Monitoring
# - AWS LB Controller
```

---

## 📊 Componentes Principales

### Infrastructure (Terraform)

| Módulo | Descripción | Recursos |
|--------|-------------|----------|
| **network** | VPC + Networking | VPC, 2 AZs, Subnets, NAT, IGW |
| **platform** | Servicios compartidos | ECR, IAM, S3 backups |
| **compute-prod** | Kubernetes Cluster | 1 CP, 2 Workers, Bastion, NLB |

### Kubernetes Components

| Componente | Versión | Propósito |
|------------|---------|-----------|
| **Kubernetes** | 1.28 | Orquestación de contenedores |
| **Calico** | 3.26 | CNI networking |
| **CloudNativePG** | 1.21 | Operador PostgreSQL |
| **PostgreSQL** | 16.1 | Base de datos HA (2 réplicas) |
| **Prometheus Stack** | Latest | Monitoring & Alerting |
| **AWS LB Controller** | Latest | Ingress/ALB management |

### Applications

| App | Estrategia | Replicas | Recursos |
|-----|-----------|----------|----------|
| **Frontend** | Rolling Update (Auto) | 2 | 256Mi/500m CPU |
| **Backend** | Blue/Green (Manual) | 2 | 512Mi/500m CPU |
| **PostgreSQL** | StatefulSet | 2 | 512Mi/500m CPU |

---

## 🔐 Secrets Management

Todos los secrets están en Kubernetes (NO en Git):

```bash
# Base de datos
kubectl get secret tunefy-db-credentials -n tunefy-prod

# Backend (Spotify + DB)
kubectl get secret backend-secrets -n tunefy-prod

# ECR pull
kubectl get secret ecr-creds -n tunefy-prod

# S3 backups
kubectl get secret aws-s3-creds -n tunefy-prod
```

**Auto-refresh:** ECR credentials se renuevan cada 8 horas automáticamente.

---

## 📈 Monitoring & Alerting

### Prometheus + Grafana

```bash
# Acceder a Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# http://localhost:3000
# User: admin
# Pass: TunefyProd2024!
```

### Alertas Configuradas

- **PodCrashLooping**: Pod reiniciando frecuentemente
- **HighMemoryUsage**: Uso de memoria > 90%
- **HighCPUUsage**: Uso de CPU > 80%
- **PostgreSQLDown**: Base de datos caída
- **DeploymentReplicasMismatch**: Réplicas no coinciden
- **NodeNotReady**: Nodo no disponible

Todas las alertas van a **Slack** (#tunefy-prod-alerts)

---

## 🔄 Deployment Process

### Frontend (Continuous Deployment)

1. Developer hace push a `main`
2. TeamCity build automático
3. Push image a ECR
4. Octopus deploy **automático** a prod
5. Rolling Update (zero downtime)

### Backend (Continuous Delivery)

1. Developer hace push a `main`
2. TeamCity build automático
3. Push image a ECR
4. Octopus deploy **espera aprobación manual**
5. Reviewer aprueba en Octopus UI
6. Blue/Green deployment
7. Manual traffic switch después de validación

---

## 📝 Operaciones Comunes

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

### Verificar salud

```bash
kubectl get nodes
kubectl top nodes
kubectl top pods -n tunefy-prod
kubectl get all -n tunefy-prod
```

### Acceso a base de datos

```bash
# Port-forward
kubectl port-forward -n tunefy-prod svc/tunefy-db-rw 5432:5432

# Conectar
psql -h localhost -U tunefy_user -d tunefy
```

---

## 🆘 Troubleshooting

### Workers no se unen

```bash
# Ver join command en SSM
aws ssm get-parameter \
  --name /tunefy/prod/k8s/join-command \
  --region us-east-1

# Logs de worker
ssh -J ubuntu@<bastion> ubuntu@<worker-ip>
tail -f /var/log/user-data.log
```

### ECR authentication fails

```bash
# Regenerar manualmente
kubectl delete secret ecr-creds -n tunefy-prod
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry ecr-creds \
  --docker-server=<account>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  -n tunefy-prod
```

### Database connection issues

```bash
# Test desde backend pod
kubectl exec -it <backend-pod> -n tunefy-prod -- \
  nc -zv tunefy-db-rw.tunefy-prod.svc.cluster.local 5432
```

---

## 📚 Documentación

| Archivo | Descripción |
|---------|-------------|
| **COMANDOS-DEPLOYMENT-PROD.md** | 👈 **Guía principal con todos los comandos** |
| **DEPLOYMENT-GUIDE-PROD.md** | Guía detallada paso a paso |
| **PLAN-PRODUCCION-COMPLETO.md** | Plan original completo |
| **README-PRODUCCION.md** | Este archivo (resumen ejecutivo) |

---

## 📊 Costos Estimados (AWS)

| Recurso | Cantidad | Costo Mensual |
|---------|----------|---------------|
| c7i-flex.large | 3 (1 CP + 2 Workers) | ~$130 |
| t3.micro (Bastion) | 1 | ~$7.5 |
| NLB | 1 | ~$16 |
| NAT Gateway | 1 | ~$32 |
| EBS gp3 (30GB x3) | 90GB | ~$7 |
| Data transfer | Variable | ~$10-20 |
| **Total estimado** | | **~$200-210/mes** |

*Nota: Precios aproximados, pueden variar según uso y región*

---

## ✅ Checklist de Validación

### Infrastructure
- [ ] VPC creado (10.30.0.0/16)
- [ ] 2 AZs configuradas
- [ ] Bastion accesible
- [ ] 1 CP + 2 Workers (c7i-flex.large)
- [ ] NLB configurado

### Kubernetes
- [ ] Todos los nodos Ready
- [ ] Calico CNI funcionando
- [ ] Namespace tunefy-prod
- [ ] StorageClass gp3

### Database
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster (2 instances)
- [ ] Schema inicializado
- [ ] Backups a S3 configurados

### Monitoring
- [ ] Prometheus Stack
- [ ] Alertmanager → Slack
- [ ] Grafana accesible
- [ ] Alertas personalizadas

### Deployment
- [ ] Frontend deployed
- [ ] Backend deployed
- [ ] Ingress/ALB configurado
- [ ] DNS apuntando

---

## 👥 Contactos

- **Slack Alerts:** `#tunefy-prod-alerts`
- **Slack Critical:** `#tunefy-prod-critical`
- **Grafana:** Port-forward para acceso
- **Octopus UI:** http://<octopus-ip>:8080

---

## 🎉 ¡Ambiente de Producción Listo!

**Siguiente paso:** Seguir [`COMANDOS-DEPLOYMENT-PROD.md`](COMANDOS-DEPLOYMENT-PROD.md) para ejecutar el deployment completo.

---

**Creado:** Octubre 2025  
**Versión:** 1.0  
**Managed by:** Terraform + Kubernetes



