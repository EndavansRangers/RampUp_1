#!/bin/bash
# Script para extraer kubeconfig del control plane para Octopus Deploy
# Usa el bastion como proxy jump para acceder al control plane privado

set -e

# Configuración
BASTION_IP="54.198.71.71"
CP_PRIVATE_IP="10.20.90.15"
SSH_KEY="$HOME/.ssh/tunefy-dev-key.pem"
OUTPUT_FILE="./kubeconfig-dev.yaml"

echo "=================================================="
echo "  Extrayendo kubeconfig del Control Plane"
echo "=================================================="
echo "Bastion IP: $BASTION_IP"
echo "Control Plane IP: $CP_PRIVATE_IP"
echo "Output: $OUTPUT_FILE"
echo ""

# Verificar que la key existe
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: SSH key no encontrada en $SSH_KEY"
    exit 1
fi

echo "🔑 Verificando permisos de la SSH key..."
chmod 600 "$SSH_KEY"

echo "📥 Descargando kubeconfig desde control plane..."

# Nota: Se asume que admin.conf ya fue copiado a /tmp/admin.conf con permisos 0644
# usando: ansible cp1 -m copy -a 'src=/etc/kubernetes/admin.conf dest=/tmp/admin.conf remote_src=yes mode=0644' -b

# Extraer el kubeconfig usando el bastion como proxy
scp -o ProxyCommand="ssh -W %h:%p -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$BASTION_IP" \
    -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    ubuntu@$CP_PRIVATE_IP:/tmp/admin.conf "$OUTPUT_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "❌ Error: No se pudo descargar el kubeconfig"
    exit 1
fi

echo "✅ Kubeconfig descargado"
echo ""

# Modificar el kubeconfig para usar la IP pública (si se accede desde fuera de la VPC)
# O mantener la IP privada si Octopus está dentro de la VPC

echo "📝 Verificando contenido del kubeconfig..."
echo ""
echo "Server actual en kubeconfig:"
grep "server:" "$OUTPUT_FILE"
echo ""

# Backup del original
cp "$OUTPUT_FILE" "${OUTPUT_FILE}.backup"

# Información sobre modificación del server
echo "⚠️  IMPORTANTE: Configuración del server endpoint"
echo ""
echo "El kubeconfig descargado apunta a: https://10.20.90.15:6443"
echo ""
echo "Opciones:"
echo "1. Si Octopus está DENTRO de la VPC (instancia oc1): NO modificar"
echo "2. Si Octopus está FUERA de la VPC: Necesitas exponer el API server"
echo ""
echo "Para este setup, Octopus (oc1: 10.20.62.98) está DENTRO de la VPC"
echo "Por lo tanto, el kubeconfig NO necesita modificación ✅"
echo ""

# Verificar permisos
chmod 600 "$OUTPUT_FILE"

echo "📋 Información del kubeconfig:"
echo "   Cluster: $(grep 'name:' "$OUTPUT_FILE" | head -1 | awk '{print $2}')"
echo "   User: $(grep 'user:' "$OUTPUT_FILE" | tail -1 | awk '{print $2}')"
echo "   Context: $(grep 'name:' "$OUTPUT_FILE" | tail -1 | awk '{print $2}')"
echo ""

echo "📁 Archivos generados:"
echo "   - $OUTPUT_FILE (kubeconfig para Octopus)"
echo "   - ${OUTPUT_FILE}.backup (backup original)"
echo ""

echo "🎯 Próximos pasos:"
echo "1. Copiar el kubeconfig al servidor Octopus (oc1: 10.20.62.98)"
echo "2. En Octopus, configurar Kubernetes Target:"
echo "   - Authentication: Kubernetes certificate"
echo "   - Kubeconfig: Contenido de $OUTPUT_FILE"
echo "   - Namespace: tunefy-dev"
echo ""

echo "=================================================="
echo "  ✅ Kubeconfig listo"
echo "=================================================="
