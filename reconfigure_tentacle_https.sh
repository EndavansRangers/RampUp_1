#!/bin/bash
set -e

echo "=========================================="
echo "Reconfiguring Tentacle for HTTPS"
echo "=========================================="

API_KEY="$1"
OCTOPUS_SERVER_URL="http://10.20.61.147:8080"
TENTACLE_NAME="tunefy-dev-cp"
ENVIRONMENT="dev"
ROLE="k8s-deployment"
SPACE="Default"

if [ -z "$API_KEY" ]; then
    echo "ERROR: API Key required!"
    echo "Usage: $0 <OCTOPUS_API_KEY>"
    exit 1
fi

echo "Stopping Tentacle service..."
sudo systemctl stop Tentacle || true

echo "Removing old instance..."
sudo /opt/octopus/tentacle/Tentacle delete-instance --instance="Tentacle" || true

echo "Creating new Tentacle instance..."
sudo /opt/octopus/tentacle/Tentacle create-instance \
  --instance "Tentacle" \
  --config "/etc/octopus/Tentacle/tentacle-Tentacle.config"

echo "Generating new certificate..."
sudo /opt/octopus/tentacle/Tentacle new-certificate \
  --instance "Tentacle" \
  --if-blank

echo "Configuring Tentacle for HTTPS listening mode..."
sudo /opt/octopus/tentacle/Tentacle configure \
  --instance "Tentacle" \
  --reset-trust

sudo /opt/octopus/tentacle/Tentacle configure \
  --instance "Tentacle" \
  --app "/home/Octopus/Applications" \
  --port "10933" \
  --noListen "False"

echo "Trusting Octopus Server..."
sudo /opt/octopus/tentacle/Tentacle configure \
  --instance "Tentacle" \
  --trust "$OCTOPUS_SERVER_URL"

echo "Registering with Octopus Server using IP address..."
sudo /opt/octopus/tentacle/Tentacle register-with \
  --instance "Tentacle" \
  --server "$OCTOPUS_SERVER_URL" \
  --name "$TENTACLE_NAME" \
  --publicHostName "10.20.87.103" \
  --comms-style "TentaclePassive" \
  --server-comms-port "10943" \
  --apiKey "$API_KEY" \
  --environment "$ENVIRONMENT" \
  --role "$ROLE" \
  --space "$SPACE" \
  --force

echo "Installing and starting Tentacle service..."
sudo /opt/octopus/tentacle/Tentacle service \
  --instance "Tentacle" \
  --install \
  --start

sleep 3

echo ""
echo "=========================================="
echo "Tentacle reconfigured!"
echo "=========================================="
echo ""
echo "Tentacle is now listening on: https://10.20.87.103:10933"
echo ""
sudo systemctl status Tentacle --no-pager -l
echo ""
