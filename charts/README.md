# Tunefy Helm Charts

Helm charts para despliegue de aplicación Tunefy en Kubernetes.

## 📦 Charts Disponibles

### 1. Frontend Chart (Rolling Update)
**Ubicación**: `charts/frontend/`

Estrategia de deployment: **Rolling Update**
- Actualización gradual sin downtime
- MaxSurge: 1, MaxUnavailable: 0

**Archivos clave**:
- `Chart.yaml` - Metadata del chart
- `values-dev.yaml` - Configuración para ambiente Dev
- `templates/deployment.yaml` - Deployment con rolling update
- `templates/service.yaml` - NodePort service
- `templates/ingress.yaml` - ALB Ingress configuration

### 2. Backend Chart (Blue/Green)
**Ubicación**: `charts/backend/`

Estrategia de deployment: **Blue/Green**
- Dos deployments simultáneos: `backend-blue` y `backend-green`
- Service estable apunta al color "live"
- Zero-downtime deployments

**Archivos clave**:
- `Chart.yaml` - Metadata del chart
- `values-dev.yaml` - Configuración para ambiente Dev
- `templates/deployment.yaml` - Crea ambos deployments (blue y green)
- `templates/service.yaml` - Service con selector `colorLive`
- `templates/ingress.yaml` - ALB Ingress configuration

---

## 🚀 Uso

### Frontend (Rolling Update)

#### Instalación inicial:
```bash
helm install tunefy-frontend ./charts/frontend \
  --namespace tunefy-dev \
  --values ./charts/frontend/values-dev.yaml
```

#### Upgrade (con nueva versión):
```bash
helm upgrade tunefy-frontend ./charts/frontend \
  --namespace tunefy-dev \
  --values ./charts/frontend/values-dev.yaml \
  --set image.tag=1.2.3
```

### Backend (Blue/Green)

#### Instalación inicial:
```bash
helm install tunefy-backend ./charts/backend \
  --namespace tunefy-dev \
  --values ./charts/backend/values-dev.yaml
```

#### Deploy nueva versión (Blue/Green switch):

**Paso 1**: Deploy a color inactivo (ej: green)
```bash
helm upgrade tunefy-backend ./charts/backend \
  --namespace tunefy-dev \
  --values ./charts/backend/values-dev.yaml \
  --set image.tag=1.2.3 \
  --set color=green
```

**Paso 2**: Smoke test en `backend-green`
```bash
# Test directo al pod green
kubectl port-forward -n tunefy-dev deployment/tunefy-backend-green 3001:3001
curl http://localhost:3001/health
```

**Paso 3**: Switch del service al nuevo color
```bash
helm upgrade tunefy-backend ./charts/backend \
  --namespace tunefy-dev \
  --values ./charts/backend/values-dev.yaml \
  --set image.tag=1.2.3 \
  --set color=green \
  --set service.selector.colorLive=green
```

**Paso 4**: Rollback si es necesario
```bash
# Volver a blue
helm upgrade tunefy-backend ./charts/backend \
  --namespace tunefy-dev \
  --values ./charts/backend/values-dev.yaml \
  --set service.selector.colorLive=blue
```

---

## 🎯 Integración con Octopus Deploy

### Variables de Octopus

**Frontend**:
```
Image.Tag = #{Octopus.Release.Number}
```

**Backend**:
```
Image.Tag = #{Octopus.Release.Number}
Color = #{BackendColor}  # blue o green
ColorLive = #{ColorLive}  # blue o green
```

### Process Steps en Octopus

#### Frontend Deployment:
```yaml
- Step: Deploy Frontend
  Action: Helm Upgrade
  Chart: ./charts/frontend
  Values: ./charts/frontend/values-dev.yaml
  Set Values:
    - image.tag=#{Octopus.Release.Number}
```

#### Backend Blue/Green Deployment:

```yaml
- Step 1: Deploy to Inactive Color
  Action: Helm Upgrade
  Chart: ./charts/backend
  Values: ./charts/backend/values-dev.yaml
  Set Values:
    - image.tag=#{Octopus.Release.Number}
    - color=#{BackendColor}
  
- Step 2: Smoke Test
  Action: Run Script
  Script: |
    # Test nuevo deployment
    kubectl wait --for=condition=ready pod \
      -l app=tunefy-backend,color=#{BackendColor} \
      -n tunefy-dev --timeout=300s
    
    # Health check
    POD=$(kubectl get pod -n tunefy-dev -l app=tunefy-backend,color=#{BackendColor} -o name | head -1)
    kubectl exec -n tunefy-dev $POD -- curl -f http://localhost:3001/health
  
- Step 3: Switch Traffic
  Action: Helm Upgrade
  Chart: ./charts/backend
  Values: ./charts/backend/values-dev.yaml
  Set Values:
    - image.tag=#{Octopus.Release.Number}
    - color=#{BackendColor}
    - service.selector.colorLive=#{BackendColor}
  
- Step 4: Cleanup Old Color (opcional)
  Action: Manual Intervention or Automated
  Notes: El deployment del color anterior sigue corriendo para rollback rápido
```

---

## 📋 Values por Ambiente

### values-dev.yaml
✅ Ya creado para ambos charts con:
- ECR registry del ambiente Dev
- imagePullSecrets configurado
- Ingress con ALB annotations
- Health checks configurados
- Resource limits apropiados

### values-qa.yaml (futuro)
Crea archivo similar cambiando:
- ECR repository: `tunefy-frontend-qa`, `tunefy-backend-qa`
- Hosts: `app.qa.tunefy.local`, `api.qa.tunefy.local`
- Namespace: `tunefy-qa`

### values-prod.yaml (futuro)
Crea archivo similar cambiando:
- ECR repository: `tunefy-frontend-prod`, `tunefy-backend-prod`
- Hosts: `app.tunefy.com`, `api.tunefy.com`
- Namespace: `tunefy-prod`
- ReplicaCount: 3+ (alta disponibilidad)
- Resources: Límites más altos

---

## 🔍 Verificación

### Frontend:
```bash
# Verificar deployment
kubectl get deployment tunefy-frontend -n tunefy-dev

# Verificar pods
kubectl get pods -n tunefy-dev -l app=tunefy-frontend

# Verificar service
kubectl get svc tunefy-frontend -n tunefy-dev

# Verificar ingress y ALB
kubectl get ingress tunefy-frontend -n tunefy-dev
```

### Backend:
```bash
# Verificar ambos deployments
kubectl get deployment -n tunefy-dev -l app=tunefy-backend

# Verificar pods por color
kubectl get pods -n tunefy-dev -l app=tunefy-backend,color=blue
kubectl get pods -n tunefy-dev -l app=tunefy-backend,color=green

# Verificar cuál está live
kubectl get pods -n tunefy-dev -l app=tunefy-backend,colorLive=true

# Verificar service selector
kubectl get svc backend -n tunefy-dev -o yaml | grep -A3 selector

# Verificar ingress
kubectl get ingress tunefy-backend -n tunefy-dev
```

---

## 🔧 Troubleshooting

### Problema: Pods no inician (ImagePullBackOff)
**Solución**:
```bash
# Verificar secret de ECR
kubectl get secret ecr-creds -n tunefy-dev

# Si no existe o expiró, regenerar
/tmp/setup-ecr-pull-secret.sh
```

### Problema: Backend service no encuentra pods
**Solución**:
```bash
# Verificar labels del service
kubectl get svc backend -n tunefy-dev -o yaml | grep -A5 selector

# Verificar labels de los pods
kubectl get pods -n tunefy-dev -l app=tunefy-backend --show-labels

# Deben coincidir: colorLive debe estar en pods y service selector
```

### Problema: ALB no se crea
**Solución**:
```bash
# Verificar logs del AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar events del ingress
kubectl describe ingress <nombre> -n tunefy-dev
```

---

## 📊 Estructura de Archivos

```
charts/
├── frontend/
│   ├── Chart.yaml
│   ├── values-dev.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml    # Rolling update strategy
│       ├── service.yaml        # NodePort para ALB
│       └── ingress.yaml        # ALB configuration
│
└── backend/
    ├── Chart.yaml
    ├── values-dev.yaml
    └── templates/
        ├── _helpers.tpl
        ├── deployment.yaml    # Crea blue Y green deployments
        ├── service.yaml        # Selector con colorLive
        └── ingress.yaml        # ALB configuration
```

---

**Última actualización**: 30 de Septiembre de 2025  
**Ambiente**: Dev  
**Kubernetes Version**: 1.30  
**Helm Version**: 3.19.0
