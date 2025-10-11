#!/bin/bash
set -e

echo "=========================================="
echo "FASE 2: AWS Load Balancer Controller"
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
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=tunefy-dev-vpc" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION 2>/dev/null || echo "")

echo "📋 Configuración:"
echo "  • Cluster: $CLUSTER_NAME"
echo "  • Región: $AWS_REGION"
echo "  • VPC ID: ${VPC_ID:-'(detectando...)'}"
echo ""

# PASO 1: Descargar IAM Policy
echo "📥 PASO 1: Descargando IAM Policy para ALB Controller..."
curl -o /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
echo "✅ Policy descargada"
echo ""

# PASO 2: Crear IAM Policy en AWS
echo "🔐 PASO 2: Creando IAM Policy en AWS..."
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text --region $AWS_REGION 2>/dev/null)

if [ -z "$POLICY_ARN" ]; then
    echo "📝 Creando nueva policy..."
    POLICY_ARN=$(aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file:///tmp/iam-policy.json \
        --region $AWS_REGION \
        --query 'Policy.Arn' \
        --output text 2>&1)
    
    if [[ $POLICY_ARN == arn:aws:iam::* ]]; then
        echo "✅ Policy creada: $POLICY_ARN"
    else
        echo "⚠️ No se pudo crear policy (puede que ya exista o no tengas permisos)"
        echo "   Continuando con la policy existente..."
        POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text --region $AWS_REGION 2>/dev/null)
    fi
else
    echo "✅ Policy ya existe: $POLICY_ARN"
fi
echo ""

# PASO 3: Attachar policy al role de los nodos
echo "🔗 PASO 3: Attachando policy al IAM role de los nodos..."
ROLE_NAME="tunefy-dev-k8s-nodes"

if aws iam get-role --role-name $ROLE_NAME &>/dev/null; then
    # Verificar si ya está attached
    if aws iam list-attached-role-policies --role-name $ROLE_NAME --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text | grep -q "$POLICY_ARN"; then
        echo "✅ Policy ya está attachada al role"
    else
        aws iam attach-role-policy \
            --role-name $ROLE_NAME \
            --policy-arn $POLICY_ARN \
            --region $AWS_REGION
        echo "✅ Policy attachada al role: $ROLE_NAME"
    fi
else
    echo "❌ Role $ROLE_NAME no encontrado"
    echo "⚠️ El ALB Controller puede tener problemas de permisos"
    echo "   Continúa con la instalación, pero revisa los logs si falla"
fi
echo ""

# PASO 4: Instalar cert-manager (prerequisito)
echo "📦 PASO 4: Verificando cert-manager..."
if kubectl get namespace cert-manager &>/dev/null; then
    echo "✅ cert-manager ya está instalado"
else
    echo "📥 Instalando cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "⏳ Esperando a que cert-manager esté listo..."
    kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=180s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=180s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=180s 2>/dev/null || true
    echo "✅ cert-manager instalado"
fi
echo ""

# PASO 5: Añadir Helm repo
echo "📚 PASO 5: Configurando Helm repo..."
if ! command -v helm &>/dev/null; then
    echo "❌ Helm no está instalado"
    echo "📥 Instalando Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
echo "✅ Helm repo configurado"
echo ""

# PASO 6: Detectar VPC ID si no se pudo antes
if [ -z "$VPC_ID" ]; then
    echo "🔍 Detectando VPC ID desde los nodos..."
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    VPC_ID=$(aws ec2 describe-instances \
        --filters "Name=private-ip-address,Values=$NODE_IP" \
        --query 'Reservations[0].Instances[0].VpcId' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "")
    
    if [ -n "$VPC_ID" ]; then
        echo "✅ VPC ID detectado: $VPC_ID"
    else
        echo "❌ No se pudo detectar VPC ID"
        echo "   Especifica manualmente con: --set vpcId=vpc-xxxxx"
        exit 1
    fi
fi
echo ""

# PASO 7: Instalar AWS Load Balancer Controller
echo "🚀 PASO 7: Instalando AWS Load Balancer Controller..."
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

# PASO 8: Verificar instalación
echo "🔍 PASO 8: Verificando instalación..."
echo ""
echo "Pods del controller:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
echo ""

# PASO 9: Configurar Provider IDs en los nodos
echo "🔧 PASO 9: Configurando Provider IDs en los nodos..."
echo ""

# Obtener información de cada nodo
for NODE in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "📝 Nodo: $NODE"
    
    # Verificar si ya tiene providerID
    CURRENT_PROVIDER_ID=$(kubectl get node $NODE -o jsonpath='{.spec.providerID}')
    
    if [ -n "$CURRENT_PROVIDER_ID" ]; then
        echo "   ✅ Provider ID ya configurado: $CURRENT_PROVIDER_ID"
        continue
    fi
    
    # Obtener IP del nodo
    NODE_IP=$(kubectl get node $NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    
    # Obtener instance ID y AZ desde AWS
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --filters "Name=private-ip-address,Values=$NODE_IP" \
        --query 'Reservations[0].Instances[0].[InstanceId,Placement.AvailabilityZone]' \
        --output text \
        --region $AWS_REGION 2>/dev/null)
    
    if [ -z "$INSTANCE_INFO" ]; then
        echo "   ⚠️ No se pudo obtener información de la instancia"
        continue
    fi
    
    INSTANCE_ID=$(echo $INSTANCE_INFO | awk '{print $1}')
    AZ=$(echo $INSTANCE_INFO | awk '{print $2}')
    PROVIDER_ID="aws:///$AZ/$INSTANCE_ID"
    
    echo "   Instance ID: $INSTANCE_ID"
    echo "   AZ: $AZ"
    echo "   Provider ID: $PROVIDER_ID"
    
    # Configurar providerID
    kubectl patch node $NODE -p "{\"spec\":{\"providerID\":\"$PROVIDER_ID\"}}"
    echo "   ✅ Provider ID configurado"
    echo ""
done

# PASO 10: Crear IngressClass
echo "📋 PASO 10: Configurando IngressClass..."
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

# Verificación final
echo "=========================================="
echo "✅ FASE 2 COMPLETADA"
echo "=========================================="
echo ""
echo "📊 Resumen:"
echo "  • IAM Policy: Creada/Attachada"
echo "  • cert-manager: Instalado"
echo "  • Helm repo: Configurado"
echo "  • VPC ID: $VPC_ID"
echo "  • AWS Load Balancer Controller: Instalado"
echo "  • Provider IDs: Configurados en todos los nodos"
echo "  • IngressClass: alb (default)"
echo ""

# Mostrar logs del controller
echo "📝 Últimas líneas de logs del controller:"
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=10 --all-containers=true 2>/dev/null || echo "   (logs no disponibles aún, espera 1-2 minutos)"
echo ""

echo "✅ El cluster puede ahora crear ALBs automáticamente desde Ingress resources"
echo ""
