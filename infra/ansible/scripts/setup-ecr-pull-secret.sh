#!/bin/bash
# Script para crear/actualizar el secret de ECR en el namespace tunefy-dev
# Paso 1 del CI/CD Setup

set -e

# Variables
NS="tunefy-dev"
REGION="us-east-1"
ACCOUNT_ID=$(/usr/local/bin/aws sts get-caller-identity --query Account --output text)
REG="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "======================================"
echo "Configurando ECR Pull Secret"
echo "======================================"
echo "Account ID: ${ACCOUNT_ID}"
echo "ECR Registry: ${REG}"
echo "Namespace: ${NS}"
echo ""

# Crear namespace si no existe
echo "1. Verificando namespace ${NS}..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

# Eliminar secret anterior si existe
echo "2. Eliminando secret anterior (si existe)..."
kubectl delete secret ecr-creds -n $NS --ignore-not-found

# Obtener password de ECR
echo "3. Obteniendo token de autenticación de ECR..."
ECR_PASSWORD=$(/usr/local/bin/aws ecr get-login-password --region $REGION)

# Crear nuevo secret
echo "4. Creando nuevo secret ecr-creds..."
kubectl create secret docker-registry ecr-creds \
  --docker-server="$REG" \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  -n $NS

# Verificar
echo ""
echo "✅ Secret creado exitosamente!"
echo ""
echo "Verificando..."
kubectl get secret ecr-creds -n $NS

echo ""
echo "======================================"
echo "Configuración completada"
echo "======================================"
echo ""
echo "Para usar este secret en tus deployments, agrega:"
echo "  imagePullSecrets:"
echo "    - name: ecr-creds"
echo ""
