#!/bin/bash
set -e

echo "=========================================="
echo "Fixing Tentacle Registration"
echo "=========================================="

API_KEY="$1"
OCTOPUS_SERVER_URL="http://10.20.61.147:8080"
TENTACLE_NAME="tunefy-dev-cp"
ENVIRONMENT="dev"
ROLE="k8s-deployment"
SPACE="Default"
# Use the actual private IP of the Control Plane
TENTACLE_PUBLIC_URL="http://10.20.87.103:10933"

if [ -z "$API_KEY" ]; then
    echo "ERROR: API Key required!"
    echo "Usage: $0 <OCTOPUS_API_KEY>"
    exit 1
fi

echo "Deregistering old machine from Octopus..."
# First, we need to find and remove the old registration via API
# This is easier to do from Octopus UI, but we'll try to re-register

echo "Re-registering Tentacle with explicit public hostname..."
sudo /opt/octopus/tentacle/Tentacle register-with --instance "Tentacle" \
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

echo "Restarting Tentacle service..."
sudo systemctl restart Tentacle

echo ""
echo "=========================================="
echo "Tentacle re-registered!"
echo "=========================================="
echo ""
echo "Please go to Octopus UI:"
echo "1. Infrastructure → Deployment Targets"
echo "2. Find and DELETE the old 'tunefy-dev-cp' entry with hostname"
echo "3. Verify the new entry shows: http://10.20.87.103:10933"
echo "4. Run Health Check"
echo ""
