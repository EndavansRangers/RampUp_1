#!/bin/bash
# Script to install Octopus Tentacle on Control Plane node
# This allows Octopus to execute deployment commands directly on CP where kubectl is already installed

set -euo pipefail

OCTOPUS_SERVER_URL="http://10.20.62.98:8080"
OCTOPUS_API_KEY="API-ZTJRLULIZSONJP94ZEGLSVUK4ZDKO4O"
TENTACLE_ENV="Dev"
TENTACLE_ROLE="k8s-deployer"
TENTACLE_NAME="cp-tentacle"

echo "=== Installing Octopus Tentacle on Control Plane ==="
echo ""

# Download and install Tentacle
echo "Downloading Tentacle..."
wget -q https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -O tentacle-linux_x64.tar.gz

echo "Extracting Tentacle..."
mkdir -p /opt/octopus/tentacle
tar xzf tentacle-linux_x64.tar.gz -C /opt/octopus/tentacle
rm tentacle-linux_x64.tar.gz

# Create tentacle instance
echo "Creating Tentacle instance..."
sudo /opt/octopus/tentacle/tentacle/Tentacle create-instance \
  --instance "$TENTACLE_NAME" \
  --config "/etc/octopus/$TENTACLE_NAME/tentacle.config"

# Configure tentacle
echo "Configuring Tentacle..."
sudo /opt/octopus/tentacle/tentacle/Tentacle new-certificate \
  --instance "$TENTACLE_NAME" \
  --if-blank

sudo /opt/octopus/tentacle/tentacle/Tentacle configure \
  --instance "$TENTACLE_NAME" \
  --reset-trust

sudo /opt/octopus/tentacle/tentacle/Tentacle configure \
  --instance "$TENTACLE_NAME" \
  --app "/home/Octopus/Applications" \
  --port 10933 \
  --noListen "True"

sudo /opt/octopus/tentacle/tentacle/Tentacle register-with \
  --instance "$TENTACLE_NAME" \
  --server "$OCTOPUS_SERVER_URL" \
  --name "$TENTACLE_NAME" \
  --apiKey "$OCTOPUS_API_KEY" \
  --environment "$TENTACLE_ENV" \
  --role "$TENTACLE_ROLE" \
  --comms-style "TentacleActive" \
  --server-comms-port "10943"

# Start service
echo "Starting Tentacle service..."
sudo /opt/octopus/tentacle/tentacle/Tentacle service \
  --instance "$TENTACLE_NAME" \
  --install \
  --start

echo ""
echo "=== Tentacle installed successfully ==="
echo "Instance: $TENTACLE_NAME"
echo "Role: $TENTACLE_ROLE"
echo "Environment: $TENTACLE_ENV"
echo ""
echo "Verify in Octopus UI: Infrastructure > Deployment Targets"
