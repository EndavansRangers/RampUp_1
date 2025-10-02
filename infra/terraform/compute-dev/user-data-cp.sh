#!/bin/bash
# User Data script for Kubernetes Control Plane auto-installation
# This runs on first boot when ASG creates a new instance

set -e
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Kubernetes Control Plane Setup"
echo "=========================================="
date

# 1. Disable swap
echo "[1/8] Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2. Load kernel modules
echo "[2/8] Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 3. Configure sysctl
echo "[3/8] Configuring sysctl..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 4. Install containerd
echo "[4/8] Installing containerd..."
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Install Kubernetes components
echo "[5/8] Installing Kubernetes packages..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.29.0-1.1 kubeadm=1.29.0-1.1 kubectl=1.29.0-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# 6. Initialize Kubernetes Control Plane
echo "[6/8] Initializing Kubernetes..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --apiserver-advertise-address=${PRIVATE_IP} \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=1.29.0

# 7. Configure kubectl for ubuntu user
echo "[7/8] Configuring kubectl..."
mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# 8. Install Calico CNI
echo "[8/8] Installing Calico CNI..."
sudo -u ubuntu kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
sudo -u ubuntu kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Save join command for workers
echo "Saving join command..."
kubeadm token create --print-join-command | sudo tee /home/ubuntu/kubeadm-join-command.sh
sudo chmod +x /home/ubuntu/kubeadm-join-command.sh
sudo chown ubuntu:ubuntu /home/ubuntu/kubeadm-join-command.sh

echo "=========================================="
echo "Kubernetes Control Plane Setup Complete!"
echo "=========================================="
date
