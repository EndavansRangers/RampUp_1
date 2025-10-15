#!/bin/bash
set -euo pipefail

# ============================================
# Worker Node Bootstrap Script - Production
# ============================================

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Starting Worker Node Setup (PROD)"
echo "========================================="

# Variables
CLUSTER_NAME="${cluster_name}"
REGION="${region}"
SSM_PARAM_NAME="/tunefy/prod/k8s/join-command"

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y apt-transport-https ca-certificates curl software-properties-common awscli

# Install containerd
echo "Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y containerd.io

# Configure containerd
echo "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
echo "Installing Kubernetes components (v1.28)..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.28.* kubeadm=1.28.* kubectl=1.28.*
apt-mark hold kubelet kubeadm kubectl

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl params
echo "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Set hostname
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname $CLUSTER_NAME-wk-$INSTANCE_ID
echo "Hostname set to: $CLUSTER_NAME-wk-$INSTANCE_ID"

# Wait for SSM parameter to be available
echo "Waiting for join command in SSM Parameter Store..."
RETRIES=0
MAX_RETRIES=60  # 10 minutes (60 * 10 seconds)

while [ $RETRIES -lt $MAX_RETRIES ]; do
  if aws ssm get-parameter \
    --name "$SSM_PARAM_NAME" \
    --region "$REGION" \
    --query "Parameter.Value" \
    --output text &> /dev/null; then
    echo "Join command found!"
    break
  fi
  
  RETRIES=$((RETRIES+1))
  echo "Retry $RETRIES/$MAX_RETRIES..."
  sleep 10
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
  echo "ERROR: Join command not found in SSM after $MAX_RETRIES retries"
  echo "This worker will NOT join the cluster automatically"
  echo "You can manually join later with: sudo /root/join-command.sh"
  exit 1
fi

# Retrieve join command
echo "Retrieving join command from SSM..."
JOIN_CMD=$(aws ssm get-parameter \
  --name "$SSM_PARAM_NAME" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$REGION")

if [ -z "$JOIN_CMD" ]; then
  echo "ERROR: Join command is empty"
  exit 1
fi

# Save join command for manual retry if needed
echo "$JOIN_CMD" > /root/join-command.sh
chmod +x /root/join-command.sh

# Join the cluster
echo "Joining Kubernetes cluster..."
echo "Command: $JOIN_CMD"
eval "$JOIN_CMD"

# Verify kubelet is running
echo "Verifying kubelet status..."
sleep 5

if systemctl is-active --quiet kubelet; then
  echo "Kubelet is running!"
  systemctl status kubelet --no-pager
else
  echo "WARNING: Kubelet is not running"
  echo "Kubelet status:"
  systemctl status kubelet --no-pager
  echo ""
  echo "Kubelet logs:"
  journalctl -u kubelet -n 50 --no-pager
  exit 1
fi

echo "========================================="
echo "Worker Node Setup Complete!"
echo "========================================="
echo ""
echo "This worker has joined: $CLUSTER_NAME"
echo "Verify from control plane: kubectl get nodes"



