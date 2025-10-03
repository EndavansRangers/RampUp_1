#!/bin/bash
set -e

echo "Installing Helm in TeamCity agent..."

# Install Helm inside the TeamCity agent container
sudo docker exec teamcity-agent-1 bash -c "
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
"

echo "Verifying Helm installation..."
sudo docker exec teamcity-agent-1 helm version

echo ""
echo "Helm installed successfully in TeamCity agent!"
