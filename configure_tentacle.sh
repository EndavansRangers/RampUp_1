#!/bin/bash
set -e

echo "=========================================="
echo "Configuring Octopus Tentacle"
echo "=========================================="

OCTOPUS_SERVER_URL="http://10.20.61.147:8080"
TENTACLE_NAME="tunefy-dev-cp"
ENVIRONMENT="${2:-Default}"  # Use second argument or "Default"
ROLE="k8s-deployment"
SPACE="Default"

# You need to provide the API key from Octopus Server
if [ -z "$1" ]; then
    echo "ERROR: API Key required!"
    echo "Usage: $0 <OCTOPUS_API_KEY> [ENVIRONMENT]"
    echo ""
    echo "Environment defaults to 'Default' if not specified"
    echo ""
    echo "Steps to get API Key:"
    echo "1. Access Octopus at http://localhost:8080 (via SSH tunnel)"
    echo "2. Complete initial setup if needed"
    echo "3. Go to Profile -> My API Keys"
    echo "4. Create a new API key"
    echo "5. Run this script with the API key as argument"
    exit 1
fi

API_KEY=$1

echo "Creating Tentacle instance..."
sudo /opt/octopus/tentacle/Tentacle create-instance --instance "Tentacle" --config "/etc/octopus/Tentacle/tentacle-Tentacle.config"

echo "Creating new certificate..."
sudo /opt/octopus/tentacle/Tentacle new-certificate --instance "Tentacle" --if-blank

echo "Configuring communication mode (listening)..."
sudo /opt/octopus/tentacle/Tentacle configure --instance "Tentacle" --reset-trust
sudo /opt/octopus/tentacle/Tentacle configure --instance "Tentacle" --app "/home/Octopus/Applications" --port "10933" --noListen "False"

echo "Trusting Octopus Server..."
sudo /opt/octopus/tentacle/Tentacle configure --instance "Tentacle" --trust "$OCTOPUS_SERVER_URL"

echo "Registering with Octopus Server..."
sudo /opt/octopus/tentacle/Tentacle register-with --instance "Tentacle" \
  --server "$OCTOPUS_SERVER_URL" \
  --name "$TENTACLE_NAME" \
  --comms-style "TentaclePassive" \
  --server-comms-port "10943" \
  --apiKey "$API_KEY" \
  --environment "$ENVIRONMENT" \
  --role "$ROLE" \
  --space "$SPACE"

echo "Installing and starting Tentacle service..."
sudo /opt/octopus/tentacle/Tentacle service --instance "Tentacle" --install --start

echo ""
echo "=========================================="
echo "Tentacle configured successfully!"
echo "=========================================="
echo ""
echo "Tentacle details:"
echo "  Name: $TENTACLE_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Role: $ROLE"
echo "  Port: 10933"
echo "  Server: $OCTOPUS_SERVER_URL"
echo ""
