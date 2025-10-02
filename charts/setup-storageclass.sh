#!/bin/bash
set -euo pipefail

echo "=== Setting up AWS EBS CSI Driver StorageClass ==="

# Check if gp2 storageclass exists
if kubectl get storageclass gp2 &>/dev/null; then
    echo "StorageClass gp2 already exists"
else
    echo "Creating gp2 StorageClass..."
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
fi

echo "✓ StorageClass configured"
kubectl get storageclass
