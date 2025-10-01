#!/bin/bash
# Script para copiar el kubeconfig al servidor de Octopus Deploy
# El servidor Octopus está en la red privada, usa bastion como proxy

set -e

# Configuración
BASTION_IP="54.198.71.71"
OCTOPUS_PRIVATE_IP="10.20.62.98"
SSH_KEY="$HOME/.ssh/tunefy-dev-key.pem"
KUBECONFIG_FILE="./kubeconfig-dev.yaml"

echo "=================================================="
echo "  Copiando kubeconfig a Octopus Server"
echo "=================================================="
echo "Bastion IP: $BASTION_IP"
echo "Octopus Server IP: $OCTOPUS_PRIVATE_IP"
echo "Kubeconfig: $KUBECONFIG_FILE"
echo ""

# Verificar que el kubeconfig existe
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "❌ Error: Kubeconfig no encontrado en $KUBECONFIG_FILE"
    echo "   Ejecutar primero: ./extract-kubeconfig.sh"
    exit 1
fi

# Verificar que la key existe
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: SSH key no encontrada en $SSH_KEY"
    exit 1
fi

echo "🔑 Verificando permisos..."
chmod 600 "$SSH_KEY"
chmod 600 "$KUBECONFIG_FILE"

echo "📤 Copiando kubeconfig a Octopus Server..."

# Copiar el kubeconfig usando el bastion como proxy
scp -o ProxyCommand="ssh -W %h:%p -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$BASTION_IP" \
    -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    "$KUBECONFIG_FILE" \
    ubuntu@$OCTOPUS_PRIVATE_IP:/tmp/kubeconfig-dev.yaml

echo "✅ Kubeconfig copiado a /tmp/kubeconfig-dev.yaml en Octopus Server"
echo ""

echo "📋 Próximos pasos en el servidor Octopus:"
echo ""
echo "1. Conectarse al servidor Octopus:"
echo "   ssh -J ubuntu@$BASTION_IP -i $SSH_KEY ubuntu@$OCTOPUS_PRIVATE_IP"
echo ""
echo "2. Verificar el kubeconfig:"
echo "   cat /tmp/kubeconfig-dev.yaml"
echo ""
echo "3. En la UI de Octopus Deploy:"
echo "   - Infrastructure → Deployment Targets → Add Deployment Target"
echo "   - Select: Kubernetes Cluster"
echo "   - Name: tunefy-dev-k8s"
echo "   - Authentication: Kubernetes certificate"
echo "   - Kubeconfig: Paste content from /tmp/kubeconfig-dev.yaml"
echo "   - Namespace: tunefy-dev"
echo "   - Roles: tunefy, dev, kubernetes"
echo "   - Environment: Dev"
echo ""

echo "=================================================="
echo "  ✅ Completado"
echo "=================================================="
