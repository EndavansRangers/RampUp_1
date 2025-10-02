# Monitoring Stack - Tunefy Dev Environment

Este módulo despliega un stack completo de observabilidad usando **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager).

## 📦 Componentes

- **Prometheus**: Recolección y almacenamiento de métricas
- **Grafana**: Visualización de métricas y dashboards
- **Alertmanager**: Gestión y enrutamiento de alertas
- **kube-state-metrics**: Métricas del estado del cluster
- **node-exporter**: Métricas de los nodos
- **ServiceMonitors**: Configuración para scrapear servicios de Tunefy

## 🚀 Deployment

### Opción 1: Deployment manual

Desde el nodo control plane (cp1):

```bash
# Ejecutar script de deployment
bash charts/monitoring/deploy-monitoring.sh
```

### Opción 2: Via Octopus Deploy

El step "Deploy Monitoring Stack" está integrado en el pipeline de Octopus (Step 9).

- **Ejecuta automáticamente** en cada deployment si está habilitado
- **Puede deshabilitarse** configurando `is_required = false`

## 📊 Acceso a los componentes

### Grafana (UI externa via ALB)

```bash
# Obtener URL del ALB
kubectl get ingress -n monitoring

# Credenciales por defecto
Usuario: admin
Password: admin
```

Abrir la URL del ALB en el navegador.

### Prometheus (puerto forwarding)

```bash
kubectl -n monitoring port-forward svc/mon-kube-prometheus-stack-prometheus 9090:9090
```

Abrir: http://localhost:9090

**Endpoints útiles:**
- Status → Targets: Ver todos los servicios scrapeados
- Status → Rules: Ver reglas de alertas configuradas
- Graph: Ejecutar queries PromQL

### Alertmanager (puerto forwarding)

```bash
kubectl -n monitoring port-forward svc/mon-kube-prometheus-stack-alertmanager 9093:9093
```

Abrir: http://localhost:9093

Ver alertas activas (firing) y silenciadas.

## 📈 Dashboards disponibles

Grafana viene con dashboards precargados:

1. **Kubernetes / Compute Resources / Cluster** - Vista general del cluster
2. **Kubernetes / Compute Resources / Namespace (Pods)** - Métricas por namespace
3. **Kubernetes / Compute Resources / Pod** - Métricas detalladas por pod
4. **Node Exporter / Nodes** - Métricas de hardware de nodos

Navega en Grafana: `Dashboards → Browse → Kubernetes`

## 🚨 Alertas configuradas

### Alertas de Tunefy (custom)

| Alerta | Condición | Severidad |
|--------|-----------|-----------|
| TunefyBackendDown | Backend no responde por 2min | Critical |
| TunefyFrontendDown | Frontend no responde por 2min | Critical |
| PostgreSQLDown | DB no responde por 2min | Critical |
| HighPodRestarts | Pods reiniciando frecuentemente | Warning |
| HighMemoryUsage | Memoria > 85% por 5min | Warning |
| HighCPUUsage | CPU > 80% por 5min | Warning |

### Alertas del sistema (built-in)

El stack incluye ~50 reglas adicionales para:
- Nodos down
- API server issues
- etcd problems
- Persistent volume issues
- Etc.

## 🔧 Configuración

### Archivos principales

```
charts/monitoring/
├── values-dev.yaml          # Configuración Helm
├── servicemonitors.yaml     # ServiceMonitors para Tunefy
└── README.md               # Este archivo

charts/
└── deploy-monitoring.sh     # Script de deployment
```

### Modificar retention de Prometheus

Editar `values-dev.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 2d  # Cambiar a 7d, 30d, etc.
```

Re-aplicar:

```bash
helm upgrade mon prometheus-community/kube-prometheus-stack \
  -n monitoring -f charts/monitoring/values-dev.yaml
```

### Agregar receptores de alertas (Slack/Email)

Editar `values-dev.yaml`, sección `alertmanager.config`:

```yaml
alertmanager:
  config:
    global:
      resolve_timeout: 5m
      slack_api_url: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
    route:
      receiver: "slack"
      group_by: ["alertname","namespace"]
    receivers:
      - name: "slack"
        slack_configs:
          - channel: "#alerts"
            send_resolved: true
```

Re-aplicar el Helm chart.

### Agregar ServiceMonitors para nuevos servicios

Editar `servicemonitors.yaml` y agregar:

```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mi-servicio
  namespace: tunefy-dev
  labels:
    release: mon
spec:
  selector:
    matchLabels:
      app: mi-servicio
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

Aplicar:

```bash
kubectl apply -f charts/monitoring/servicemonitors.yaml
```

## 🔍 Troubleshooting

### Targets no aparecen en Prometheus

1. Verificar ServiceMonitor:
```bash
kubectl get servicemonitors -n tunefy-dev
kubectl describe servicemonitor tunefy-backend -n tunefy-dev
```

2. Verificar labels del Service:
```bash
kubectl get svc -n tunefy-dev --show-labels
```

3. Verificar logs de Prometheus:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### Grafana no carga dashboards

1. Verificar datasource:
```bash
kubectl exec -n monitoring -it deployment/mon-grafana -- \
  curl http://localhost:3000/api/datasources
```

2. Reiniciar pod de Grafana:
```bash
kubectl rollout restart deployment/mon-grafana -n monitoring
```

### Alertas no se disparan

1. Verificar reglas cargadas en Prometheus:
   - UI → Status → Rules
   - Buscar `tunefy-alerts`

2. Verificar expresiones PromQL:
```bash
# Port-forward Prometheus
kubectl -n monitoring port-forward svc/mon-kube-prometheus-stack-prometheus 9090:9090

# Ejecutar query manualmente en http://localhost:9090
```

## 📝 Recursos

### Recursos configurados (dev)

| Componente | CPU Request | Memory Request | Memory Limit |
|------------|-------------|----------------|--------------|
| Prometheus | 100m | 256Mi | 512Mi |
| Grafana | 50m | 128Mi | 256Mi |
| Alertmanager | 50m | 128Mi | 256Mi |
| kube-state-metrics | 50m | 64Mi | 128Mi |
| node-exporter | 25m | 64Mi | 128Mi |

**Total aproximado**: ~275m CPU, ~640Mi memoria

Compatible con worker node t3.small (2 vCPU, 2GB RAM).

## 🔐 Seguridad

### Credenciales por defecto

⚠️ **CAMBIAR EN PRODUCCIÓN**

```yaml
grafana:
  adminPassword: "admin"  # INSEGURO - solo para dev
```

Para producción, usar Secrets de Kubernetes:

```yaml
grafana:
  admin:
    existingSecret: grafana-admin-secret
    userKey: admin-user
    passwordKey: admin-password
```

### API Keys

Google API key embebida en el código es solo para desarrollo.

## 📚 Links útiles

- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

## ✅ Verificación de deployment

Checklist:

- [ ] Namespace `monitoring` creado
- [ ] Pods en estado Running:
  ```bash
  kubectl get pods -n monitoring
  ```
- [ ] Grafana accesible via ALB
- [ ] Prometheus muestra targets (Status → Targets)
- [ ] Dashboards de Kubernetes visibles en Grafana
- [ ] ServiceMonitors aplicados en `tunefy-dev`
- [ ] Alertas cargadas en Prometheus (Status → Rules)

## 🔄 Mantenimiento

### Actualizar el stack

```bash
helm repo update
helm upgrade mon prometheus-community/kube-prometheus-stack \
  -n monitoring -f charts/monitoring/values-dev.yaml
```

### Desinstalar completamente

```bash
helm uninstall mon -n monitoring
kubectl delete namespace monitoring
kubectl delete servicemonitors -n tunefy-dev --all
```

### Backup de dashboards de Grafana

Los dashboards se pueden exportar como JSON desde la UI de Grafana:

1. Dashboard → Settings → JSON Model
2. Copiar y guardar en `charts/monitoring/dashboards/`
3. Commitear a Git

Para restaurar, importar desde Grafana UI o configurar en `values-dev.yaml`.
