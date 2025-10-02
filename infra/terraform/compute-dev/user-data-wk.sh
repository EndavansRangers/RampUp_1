#!/bin/bash
# User Data script for Kubernetes Worker Node auto-installation
# This runs on first boot when ASG creates a new instance

set -e
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Kubernetes Worker Node Setup"
echo "=========================================="
date

# 1. Disable swap
echo "[1/7] Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2. Load kernel modules
echo "[2/7] Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 3. Configure sysctl
echo "[3/7] Configuring sysctl..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 4. Install containerd
echo "[4/7] Installing containerd..."
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Install Kubernetes components
echo "[5/7] Installing Kubernetes packages..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.29.0-1.1 kubeadm=1.29.0-1.1 kubectl=1.29.0-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# 6. Wait for Control Plane and join cluster
echo "[6/7] Waiting for Control Plane to be ready..."
# This part will need manual intervention or a discovery mechanism
# For now, worker will be ready but not joined - needs to be done via Ansible
# Alternative: Use AWS SSM Parameter Store to share join command

echo "[7/7] Worker node prepared. Join command needed from Control Plane."
echo "Run: ssh cp1 'cat /home/ubuntu/kubeadm-join-command.sh' | sudo bash"

echo "=========================================="
echo "Kubernetes Worker Node Setup Complete!"
echo "=========================================="
date
