#!/bin/bash
set -euo pipefail

# ============================================
# Control Plane Bootstrap Script - Production
# ============================================

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "🚀 Starting Control Plane Setup (PROD)"
echo "========================================="

# Variables
CLUSTER_NAME="${cluster_name}"
POD_CIDR="${pod_cidr}"
REGION="${region}"
SSM_PARAM_NAME="/tunefy/prod/k8s/join-command"

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
apt-get install -y apt-transport-https ca-certificates curl software-properties-common awscli

# Install containerd
echo "🐳 Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y containerd.io

# Configure containerd
echo "⚙️  Configuring containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
echo "☸️  Installing Kubernetes components (v1.28)..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.28.* kubeadm=1.28.* kubectl=1.28.*
apt-mark hold kubelet kubeadm kubectl

# Disable swap
echo "💾 Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
echo "🔧 Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl params
echo "🔧 Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Get private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "🌐 Private IP: $PRIVATE_IP"

# Initialize cluster
echo "🎯 Initializing Kubernetes cluster..."
kubeadm init \
  --pod-network-cidr=$POD_CIDR \
  --apiserver-advertise-address=$PRIVATE_IP \
  --control-plane-endpoint=$PRIVATE_IP \
  --upload-certs

# Setup kubectl for ubuntu user
echo "👤 Configuring kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Setup kubectl for root
echo "👤 Configuring kubectl for root user..."
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Install Calico CNI
echo "🕸️  Installing Calico CNI..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for Calico pods to be ready
echo "⏳ Waiting for Calico pods to be ready..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s || true

# Generate join command
echo "🔗 Generating worker join command..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

# Save join command locally
echo "$JOIN_COMMAND" > /home/ubuntu/join-command.sh
chmod +x /home/ubuntu/join-command.sh
chown ubuntu:ubuntu /home/ubuntu/join-command.sh

# Save join command to SSM Parameter Store
echo "☁️  Saving join command to SSM Parameter Store..."
aws ssm put-parameter \
  --name "$SSM_PARAM_NAME" \
  --value "$JOIN_COMMAND" \
  --type "SecureString" \
  --overwrite \
  --region "$REGION" \
  || echo "⚠️  Warning: Failed to save join command to SSM (may not have permissions yet)"

# Install Helm
echo "📦 Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Metrics Server
echo "📊 Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch Metrics Server for private IPs
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]' || true

# Create production namespace
echo "📦 Creating tunefy-prod namespace..."
kubectl create namespace tunefy-prod || true

# Taint removal for single-node development (optional)
# kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "========================================="
echo "✅ Control Plane Setup Complete!"
echo "========================================="
echo ""
echo "📋 Next steps:"
echo "1. Worker nodes will auto-join using SSM Parameter Store"
echo "2. Verify cluster: kubectl get nodes"
echo "3. Manual join command saved at: /home/ubuntu/join-command.sh"
echo ""
echo "🔍 Cluster Info:"
kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info



