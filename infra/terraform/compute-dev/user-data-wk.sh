#!/bin/bash
# User Data script for Kubernetes Worker Node with AUTO-JOIN via SSM Parameter Store
# This runs on first boot when ASG creates a new instance

set -euo pipefail
    
# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1
    
echo "=========================================="
echo "🚀 Starting Kubernetes Worker Bootstrap"
echo "=========================================="
    
# Set hostname using IMDSv2 (Instance Metadata Service v2)
echo "Getting instance ID from IMDSv2..."
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

hostnamectl set-hostname tunefy-dev-wk-$INSTANCE_ID
    
# Update /etc/hosts
echo "127.0.0.1 tunefy-dev-wk-$INSTANCE_ID" >> /etc/hosts

# 1. Disable swap
echo "[1/8] Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2. Load kernel modules
echo "[2/8] Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# 3. Configure sysctl
echo "[3/8] Configuring sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# 4. Install containerd
echo "[4/8] Installing containerd..."
apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# 5. Install Kubernetes components
echo "[5/8] Installing Kubernetes packages..."
apt-get install -y apt-transport-https ca-certificates curl gpg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.30.0-1.1 kubeadm=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubeadm kubectl

# 6. Install AWS CLI if not present
if ! command -v aws &> /dev/null; then
  echo "[6/8] Installing AWS CLI..."
  apt-get update
  apt-get install -y awscli
fi
    
# 7. Wait for SSM parameter to be available (in case cluster is still bootstrapping)
echo "[7/8] Waiting for join command in SSM Parameter Store..."
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
  if aws ssm get-parameter \
    --name "/tunefy/dev/k8s/join-command" \
    --region us-east-1 \
    --query "Parameter.Value" \
    --output text &> /dev/null; then
    echo "✅ Join command found!"
    break
  fi
      
  RETRIES=$((RETRIES+1))
  echo "⏳ Retry $RETRIES/$MAX_RETRIES..."
  sleep 10
done
    
if [ $RETRIES -eq $MAX_RETRIES ]; then
  echo "❌ ERROR: Join command not found in SSM after $MAX_RETRIES retries"
  echo "⚠️  This instance will NOT join the cluster automatically"
  exit 1
fi
    
# 8. Retrieve join command and execute
echo "[8/8] Joining Kubernetes cluster..."
JOIN_CMD=$(aws ssm get-parameter \
  --name "/tunefy/dev/k8s/join-command" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region us-east-1)
    
if [ -z "$JOIN_CMD" ]; then
  echo "❌ ERROR: Join command is empty"
  exit 1
fi
    
echo "🔗 Joining cluster..."
eval "$JOIN_CMD"
    
# Verify kubelet is running
echo "🔍 Verifying kubelet status..."
sleep 5
if systemctl is-active --quiet kubelet; then
  echo "✅ Kubelet is running!"
  systemctl status kubelet --no-pager
else
  echo "⚠️  WARNING: Kubelet is not running"
  systemctl status kubelet --no-pager
  exit 1
fi
    
echo "=========================================="
echo "✅ Worker node joined successfully!"
echo "=========================================="
