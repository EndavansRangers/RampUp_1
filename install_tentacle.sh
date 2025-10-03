#!/bin/bash
set -e

echo "=========================================="
echo "Installing Octopus Tentacle on Control Plane"
echo "=========================================="

# Install Tentacle
echo "Adding Octopus repository..."
sudo apt update
sudo apt install --no-install-recommends gnupg curl ca-certificates apt-transport-https -y

curl -sSfL https://apt.octopus.com/public.key | sudo gpg --dearmor -o /usr/share/keyrings/octopus.gpg
sudo sh -c "echo deb [signed-by=/usr/share/keyrings/octopus.gpg] https://apt.octopus.com/ stable main > /etc/apt/sources.list.d/octopus.com.list"

echo "Installing Octopus Tentacle..."
sudo apt update
sudo apt install tentacle -y

echo "Tentacle version:"
/opt/octopus/tentacle/Tentacle version

echo ""
echo "=========================================="
echo "Tentacle installed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Configure Tentacle with the following command:"
echo "   sudo /opt/octopus/tentacle/Tentacle create-instance --instance \"Tentacle\" --config \"/etc/octopus/Tentacle/tentacle-Tentacle.config\""
echo "2. Register Tentacle with Octopus Server at http://10.20.61.147:8080"
echo ""
