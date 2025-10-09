#!/bin/bash
set -e

echo "=== Installing Octopus Tentacle on Control Plane ==="

# Download and install Tentacle
echo "1. Downloading Tentacle..."
wget -q https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -O /tmp/tentacle.tar.gz

echo "2. Extracting Tentacle..."
sudo mkdir -p /opt/octopus
sudo tar xzf /tmp/tentacle.tar.gz -C /opt/octopus
sudo chmod +x /opt/octopus/tentacle/Tentacle

echo "3. Creating Tentacle instance..."
sudo /opt/octopus/tentacle/Tentacle create-instance --instance tentacle-cp1 --config /etc/octopus/tentacle-cp1.config

echo "4. Generating certificate..."
sudo /opt/octopus/tentacle/Tentacle new-certificate --instance tentacle-cp1 --if-blank

echo "5. Configuring Tentacle (Polling mode)..."
sudo /opt/octopus/tentacle/Tentacle configure \
  --instance tentacle-cp1 \
  --home /var/opt/octopus \
  --app /home/Octopus/Applications \
  --port 10933 \
  --noListen True

echo "6. Registering with Octopus Server..."
sudo /opt/octopus/tentacle/Tentacle register-with \
  --instance tentacle-cp1 \
  --server "http://10.20.63.199:8080" \
  --apiKey "API-PK3XVCQYIGGE3HEPUPVNIGQNIBZRJ" \
  --space "Default" \
  --name "cp1-tentacle" \
  --environment "dev" \
  --role "k8s-deployer" \
  --comms-style "TentacleActive" \
  --server-comms-port 10943 \
  --force

echo "7. Installing and starting service..."
sudo /opt/octopus/tentacle/Tentacle service --instance tentacle-cp1 --install --start

echo "8. Verifying status..."
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance tentacle-cp1

echo ""
echo "✅ Tentacle installation complete!"
echo "   Name: cp1-tentacle"
echo "   Environment: dev"
echo "   Role: k8s-deployer"
echo "   Mode: Polling (TentacleActive)"


