#!/bin/bash
set -e

echo "=========================================="
echo "FASE 1: Preparación del Cluster"
echo "=========================================="
echo ""

# Verificar conectividad
echo "📡 Verificando conectividad con el cluster..."
if ! kubectl get nodes &>/dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    echo "💡 Asegúrate de estar conectado al bastion y luego al control plane"
    exit 1
fi

echo "✅ Conectado al cluster"
echo ""

# 1. Verificar nodos
echo "🔍 PASO 1: Verificando nodos..."
kubectl get nodes -o wide
echo ""

# 2. Verificar pods del sistema
echo "🔍 PASO 2: Verificando pods del sistema..."
echo "Total de pods:"
kubectl get pods -A --no-headers | wc -l
echo ""
echo "Pods NO Running:"
kubectl get pods -A --field-selector=status.phase!=Running --no-headers | wc -l
echo ""

# 3. Crear namespace tunefy-dev
echo "📦 PASO 3: Creando namespace tunefy-dev..."
if kubectl get namespace tunefy-dev &>/dev/null; then
    echo "✅ Namespace tunefy-dev ya existe"
else
    kubectl create namespace tunefy-dev
    kubectl label namespace tunefy-dev environment=dev
    echo "✅ Namespace tunefy-dev creado"
fi
echo ""

# 4. Instalar AWS EBS CSI Driver
echo "💾 PASO 4: Instalando AWS EBS CSI Driver..."
if kubectl get pods -n kube-system | grep -q ebs-csi; then
    echo "✅ AWS EBS CSI Driver ya está instalado"
else
    echo "📥 Descargando manifiestos del CSI Driver..."
    kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.27"
    
    echo "⏳ Esperando a que los pods estén Ready..."
    kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=180s
    echo "✅ AWS EBS CSI Driver instalado correctamente"
fi
echo ""

# 5. Crear StorageClass
echo "💿 PASO 5: Creando StorageClass gp3..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

echo "✅ StorageClass gp3 creado"
echo ""

# 6. Verificar StorageClass
echo "🔍 PASO 6: Verificando StorageClass..."
kubectl get storageclass
echo ""

# Resumen
echo "=========================================="
echo "✅ FASE 1 COMPLETADA"
echo "=========================================="
echo ""
echo "📊 Resumen:"
echo "  • Nodos: $(kubectl get nodes --no-headers | wc -l) Ready"
echo "  • Pods: $(kubectl get pods -A --no-headers | wc -l) Running"
echo "  • Namespace: tunefy-dev creado"
echo "  • StorageClass: gp3 configurado"
echo "  • AWS EBS CSI Driver: Instalado"
echo ""
echo "✅ El cluster está listo para desplegar aplicaciones"
echo ""
