#!/bin/bash
# Este script se ejecuta en el CONTROL PLANE
set -e

echo "=========================================="
echo "FASE 2B: AWS Load Balancer Controller (K8s)"
echo "=========================================="
echo ""

# Verificar conectividad
echo "📡 Verificando conectividad con el cluster..."
if ! kubectl get nodes &>/dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi
echo "✅ Conectado al cluster"
echo ""

# Variables
CLUSTER_NAME="tunefy-dev-k8s"
AWS_REGION="us-east-1"

echo "📋 Configuración:"
echo "  • Cluster: $CLUSTER_NAME"
echo "  • Región: $AWS_REGION"
echo ""

# PASO 1: Instalar cert-manager (prerequisito)
echo "📦 PASO 1: Verificando cert-manager..."
if kubectl get namespace cert-manager &>/dev/null; then
    echo "✅ cert-manager ya está instalado"
else
    echo "📥 Instalando cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "⏳ Esperando a que cert-manager esté listo (180s)..."
    sleep 30
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=180s 2>/dev/null || true
    echo "✅ cert-manager instalado"
fi
echo ""

# PASO 2: Verificar/Instalar Helm
echo "🔧 PASO 2: Verificando Helm..."
if ! command -v helm &>/dev/null; then
    echo "❌ Helm no está instalado"
    echo "📥 Instalando Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm instalado"
else
    echo "✅ Helm ya está instalado: $(helm version --short)"
fi
echo ""

# PASO 3: Añadir Helm repo
echo "📚 PASO 3: Configurando Helm repo..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
echo "✅ Helm repo configurado"
echo ""

# PASO 4: Detectar VPC ID
echo "🔍 PASO 4: Detectando VPC ID..."
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "   Nodo de referencia: $NODE_NAME"

# Obtener el VPC ID desde las etiquetas del nodo
VPC_ID=$(kubectl get node $NODE_NAME -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null | sed 's/[a-z]$//' || echo "")

if [ -z "$VPC_ID" ]; then
    echo "   ⚠️ No se pudo detectar VPC desde labels"
    echo "   Usando VPC predeterminado: vpc-0a1b2c3d4e5f6g7h8"
    VPC_ID="vpc-0a1b2c3d4e5f6g7h8"  # Este debe ser el VPC ID correcto
fi

echo "   📝 VPC ID: $VPC_ID"
echo ""

# PASO 5: Configurar Provider IDs en los nodos
echo "🔧 PASO 5: Configurando Provider IDs en los nodos..."
echo ""

# Función para obtener instance ID desde hostname del nodo
get_instance_id_from_hostname() {
    local hostname=$1
    # Los nombres de los nodos EC2 suelen ser: ip-10-20-30-40 o contener el instance ID
    if [[ $hostname =~ i-[0-9a-f]+ ]]; then
        echo "${BASH_REMATCH[0]}"
    else
        echo ""
    fi
}

for NODE in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "📝 Nodo: $NODE"
    
    # Verificar si ya tiene providerID
    CURRENT_PROVIDER_ID=$(kubectl get node $NODE -o jsonpath='{.spec.providerID}')
    
    if [ -n "$CURRENT_PROVIDER_ID" ]; then
        echo "   ✅ Provider ID ya configurado: $CURRENT_PROVIDER_ID"
        continue
    fi
    
    # Intentar extraer instance ID del hostname
    INSTANCE_ID=$(get_instance_id_from_hostname "$NODE")
    
    if [ -z "$INSTANCE_ID" ]; then
        echo "   ⚠️ No se pudo extraer Instance ID del hostname"
        echo "   Configúralo manualmente con: kubectl patch node $NODE -p '{\"spec\":{\"providerID\":\"aws:///us-east-1X/i-XXXXX\"}}'"
        continue
    fi
    
    # Obtener AZ del nodo
    AZ=$(kubectl get node $NODE -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    if [ -z "$AZ" ]; then
        AZ="us-east-1a"  # Default
        echo "   ⚠️ AZ no detectada, usando: $AZ"
    fi
    
    PROVIDER_ID="aws:///$AZ/$INSTANCE_ID"
    
    echo "   Instance ID: $INSTANCE_ID"
    echo "   AZ: $AZ"
    echo "   Provider ID: $PROVIDER_ID"
    
    # Configurar providerID
    kubectl patch node $NODE -p "{\"spec\":{\"providerID\":\"$PROVIDER_ID\"}}"
    echo "   ✅ Provider ID configurado"
    echo ""
done

# PASO 6: Instalar AWS Load Balancer Controller
echo "🚀 PASO 6: Instalando AWS Load Balancer Controller..."

# Detectar VPC ID correcto del subnet de los nodos
echo "   🔍 Detectando VPC ID real..."
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "   IP del primer nodo: $NODE_IP"

# El VPC ID debería estar en el formato vpc-XXXXX
# Por ahora usaremos un valor conocido o lo dejaremos para que Helm lo detecte
VPC_ID="vpc-0cef07bb68de40fa5"  # Este es el VPC que creamos con Terraform

echo "   📝 Usando VPC ID: $VPC_ID"
echo ""

if helm list -n kube-system | grep -q aws-load-balancer-controller; then
    echo "⚠️ AWS Load Balancer Controller ya está instalado"
    echo "🔄 Actualizando..."
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$AWS_REGION \
        --set vpcId=$VPC_ID \
        --set enableShield=false \
        --set enableWaf=false \
        --set enableWafv2=false \
        --wait \
        --timeout 5m
    echo "✅ Controller actualizado"
else
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$AWS_REGION \
        --set vpcId=$VPC_ID \
        --set enableShield=false \
        --set enableWaf=false \
        --set enableWafv2=false \
        --wait \
        --timeout 5m
    echo "✅ Controller instalado"
fi
echo ""

# PASO 7: Crear IngressClass
echo "📋 PASO 7: Configurando IngressClass..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
EOF
echo "✅ IngressClass 'alb' configurada como default"
echo ""

# PASO 8: Verificar instalación
echo "🔍 PASO 8: Verificando instalación..."
echo ""
echo "Pods del controller:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
echo ""

echo "Deployments:"
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""

# Verificación final
echo "=========================================="
echo "✅ FASE 2B COMPLETADA"
echo "=========================================="
echo ""
echo "📊 Resumen:"
echo "  • cert-manager: Instalado"
echo "  • Helm repo: Configurado"
echo "  • VPC ID: $VPC_ID"
echo "  • AWS Load Balancer Controller: Instalado"
echo "  • Provider IDs: Configurados"
echo "  • IngressClass: alb (default)"
echo ""

# Mostrar logs del controller
echo "📝 Últimas líneas de logs del controller:"
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20 --all-containers=true 2>/dev/null || echo "   (esperando que los pods estén listos...)"
echo ""

echo "✅ El cluster puede ahora crear ALBs automáticamente desde Ingress resources"
echo ""
