#!/bin/bash
# Script para configurar IAM roles manualmente (requiere permisos de IAM)
# Ejecutar con usuario/rol que tenga permisos: iam:CreateRole, iam:AttachRolePolicy, etc.

set -e

echo "=========================================="
echo "📋 IAM Setup para Tunefy Dev"
echo "=========================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# 1. Crear IAM Role para K8s nodes
echo "[1/5] Creando IAM Role: tunefy-dev-nodes..."
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name tunefy-dev-nodes \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --tags Key=owner,Value=david.cifuentes Key=project,Value=tunefy-david.cifuentes Key=env,Value=dev \
  || echo "⚠️  Role already exists, continuing..."

# 2. Attach managed policies
echo "[2/5] Attaching managed policies..."
aws iam attach-role-policy \
  --role-name tunefy-dev-nodes \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore || true

aws iam attach-role-policy \
  --role-name tunefy-dev-nodes \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true

# 3. Create custom policy for SSM Parameter Store
echo "[3/5] Creating custom SSM policy..."
cat > /tmp/ssm-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ],
    "Resource": "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/tunefy/dev/k8s/*"
  }]
}
EOF

aws iam create-policy \
  --policy-name tunefy-dev-ssm-join-command \
  --policy-document file:///tmp/ssm-policy.json \
  --tags Key=owner,Value=david.cifuentes Key=project,Value=tunefy-david.cifuentes Key=env,Value=dev \
  || echo "⚠️  Policy already exists, continuing..."

aws iam attach-role-policy \
  --role-name tunefy-dev-nodes \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/tunefy-dev-ssm-join-command || true

# 4. Create instance profile
echo "[4/5] Creating instance profile..."
aws iam create-instance-profile \
  --instance-profile-name tunefy-dev-nodes \
  || echo "⚠️  Instance profile already exists, continuing..."

# 5. Add role to instance profile
echo "[5/5] Adding role to instance profile..."
aws iam add-role-to-instance-profile \
  --instance-profile-name tunefy-dev-nodes \
  --role-name tunefy-dev-nodes \
  || echo "⚠️  Role already attached, continuing..."

echo ""
echo "=========================================="
echo "✅ IAM Setup completado!"
echo "=========================================="
echo ""
echo "Recursos creados:"
echo "  - IAM Role: tunefy-dev-nodes"
echo "  - Instance Profile: tunefy-dev-nodes"
echo "  - Políticas adjuntas:"
echo "    • AmazonSSMManagedInstanceCore"
echo "    • AmazonEC2ContainerRegistryReadOnly"
echo "    • tunefy-dev-ssm-join-command (custom)"
echo ""
