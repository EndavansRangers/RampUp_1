#!/bin/bash
set -e

echo "Fixing containerd configuration..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl status containerd | head -3

echo "Resetting kubeadm..."
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd

echo "Initializing Kubernetes cluster..."
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=1.29.0 \
  --apiserver-advertise-address=10.20.87.103

echo "Setting up kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "Installing Calico CNI..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

echo "Generating join command for workers..."
kubeadm token create --print-join-command | sudo tee /home/ubuntu/kubeadm-join-command.sh
sudo chmod +x /home/ubuntu/kubeadm-join-command.sh

echo "Done! Cluster initialized successfully."
