#!/bin/bash
# Este script se ejecuta en el BASTION (tiene AWS CLI)
set -e

echo "=========================================="
echo "FASE 2A: Configuración IAM (desde Bastion)"
echo "=========================================="
echo ""

AWS_REGION="us-east-1"

# PASO 1: Descargar IAM Policy
echo "📥 PASO 1: Descargando IAM Policy para ALB Controller..."
curl -o /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
echo "✅ Policy descargada"
echo ""

# PASO 2: Crear IAM Policy en AWS
echo "🔐 PASO 2: Creando IAM Policy en AWS..."
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text --region $AWS_REGION 2>/dev/null || echo "")

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
        echo "⚠️ Error al crear policy: $POLICY_ARN"
        echo "   Intentando obtener policy existente..."
        POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text --region $AWS_REGION 2>/dev/null || echo "")
        if [ -n "$POLICY_ARN" ]; then
            echo "✅ Policy encontrada: $POLICY_ARN"
        else
            echo "❌ No se pudo obtener la policy"
            exit 1
        fi
    fi
else
    echo "✅ Policy ya existe: $POLICY_ARN"
fi
echo ""

# PASO 3: Attachar policy al role de los nodos
echo "🔗 PASO 3: Attachando policy al IAM role de los nodos..."
ROLE_NAME="tunefy-dev-k8s-nodes"

if aws iam get-role --role-name $ROLE_NAME --region $AWS_REGION &>/dev/null; then
    # Verificar si ya está attached
    if aws iam list-attached-role-policies --role-name $ROLE_NAME --region $AWS_REGION --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text | grep -q "$POLICY_ARN"; then
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
    echo "   Listando roles disponibles:"
    aws iam list-roles --query 'Roles[?contains(RoleName, `tunefy`) || contains(RoleName, `k8s`)].RoleName' --output table --region $AWS_REGION
    exit 1
fi
echo ""

echo "=========================================="
echo "✅ FASE 2A COMPLETADA"
echo "=========================================="
echo ""
echo "📊 Resumen:"
echo "  • Policy ARN: $POLICY_ARN"
echo "  • Role: $ROLE_NAME"
echo ""
echo "➡️ Continúa con fase2-k8s-setup.sh en el control plane"
