#!/bin/bash
# Simplified Tentacle setup using Listening mode (Octopus connects to Tentacle)
# This avoids Security Group issues with polling mode

set -euo pipefail

echo "=================================================="
echo "Setting up Control Plane as Octopus Worker"
echo "(Listening Mode)"
echo "=================================================="
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo bash setup-cp-worker-listening.sh"
    exit 1
fi

OCTOPUS_SERVER_URL="http://10.20.62.98:8080"
OCTOPUS_API_KEY="API-ZTJRLULIZSONJP94ZEGLSVUK4ZDKO4O"
OCTOPUS_THUMBPRINT="YOUR_OCTOPUS_THUMBPRINT"  # Will be obtained from Octopus
TENTACLE_ENV="Dev"
TENTACLE_ROLE="k8s-deployer"
TENTACLE_NAME="cp1-tentacle"
TENTACLE_PORT="10933"

# ============================================
# Step 1: Install required tools
# ============================================
echo "Step 1: Installing required tools..."

# Helm
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://get.helm.sh/helm-v3.13.1-linux-amd64.tar.gz | tar xz
    mv linux-amd64/helm /usr/local/bin/helm
    rm -rf linux-amd64
    chmod +x /usr/local/bin/helm
fi

# AWS CLI (if needed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

echo "✓ Tools installed"
echo ""

# ============================================
# Step 2: Verify environment
# ============================================
echo "Step 2: Verifying environment..."
echo "  kubectl: $(kubectl version --client | head -1)"
echo "  helm: $(helm version --short 2>/dev/null || helm version)"
echo "  aws: $(aws --version)"
echo "  k8s cluster: $(kubectl get nodes --no-headers | wc -l) nodes"
echo ""

# ============================================
# Step 3: Get Octopus Server Thumbprint
# ============================================
echo "Step 3: Getting Octopus Server thumbprint..."
OCTOPUS_THUMBPRINT=$(echo | openssl s_client -connect 10.20.62.98:10943 2>/dev/null | openssl x509 -noout -fingerprint -sha1 2>/dev/null | cut -d'=' -f2 || echo "")

if [ -z "$OCTOPUS_THUMBPRINT" ]; then
    echo "WARNING: Could not get thumbprint automatically"
    echo "Manual steps required:"
    echo "  1. In Octopus UI, go to: Configuration > Thumbprint"
    echo "  2. Copy the thumbprint"
    echo "  3. Update this script with the thumbprint"
    echo ""
    read -p "Enter Octopus thumbprint (or press Enter to try without): " MANUAL_THUMBPRINT
    if [ -n "$MANUAL_THUMBPRINT" ]; then
        OCTOPUS_THUMBPRINT="$MANUAL_THUMBPRINT"
    fi
fi

if [ -n "$OCTOPUS_THUMBPRINT" ]; then
    echo "✓ Octopus thumbprint: $OCTOPUS_THUMBPRINT"
else
    echo "⚠ Proceeding without thumbprint (may need manual configuration)"
fi
echo ""

# ============================================
# Step 4: Download and install Tentacle
# ============================================
echo "Step 4: Installing Octopus Tentacle..."
cd /tmp

if [ ! -d /opt/octopus/tentacle ]; then
    if [ ! -f tentacle-linux_x64.tar.gz ]; then
        echo "Downloading Tentacle..."
        wget -q https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -O tentacle-linux_x64.tar.gz
    fi
    
    echo "Extracting Tentacle..."
    mkdir -p /opt/octopus/tentacle
    tar xzf tentacle-linux_x64.tar.gz -C /opt/octopus/tentacle
    echo "✓ Tentacle extracted"
else
    echo "✓ Tentacle already installed"
fi
echo ""

# ============================================
# Step 5: Configure Tentacle (Listening Mode)
# ============================================
echo "Step 5: Configuring Tentacle in Listening mode..."

# Remove old instance if exists
/opt/octopus/tentacle/tentacle/Tentacle delete-instance --instance "$TENTACLE_NAME" || true

# Create new instance
/opt/octopus/tentacle/tentacle/Tentacle create-instance \
  --instance "$TENTACLE_NAME" \
  --config "/etc/octopus/$TENTACLE_NAME/tentacle.config"

# Generate certificate
/opt/octopus/tentacle/tentacle/Tentacle new-certificate \
  --instance "$TENTACLE_NAME" \
  --if-blank

# Configure to LISTEN (not poll)
/opt/octopus/tentacle/tentacle/Tentacle configure \
  --instance "$TENTACLE_NAME" \
  --reset-trust \
  --app "/home/Octopus/Applications" \
  --port "$TENTACLE_PORT" \
  --noListen "False"

# Trust Octopus Server (if we have thumbprint)
if [ -n "$OCTOPUS_THUMBPRINT" ]; then
    /opt/octopus/tentacle/tentacle/Tentacle configure \
      --instance "$TENTACLE_NAME" \
      --trust "$OCTOPUS_THUMBPRINT"
fi

echo "✓ Tentacle configured in Listening mode on port $TENTACLE_PORT"
echo ""

# ============================================
# Step 6: Register with Octopus Server
# ============================================
echo "Step 6: Registering with Octopus Server..."

# Get this machine's private IP
MACHINE_IP=$(hostname -I | awk '{print $1}')

/opt/octopus/tentacle/tentacle/Tentacle register-with \
  --instance "$TENTACLE_NAME" \
  --server "$OCTOPUS_SERVER_URL" \
  --name "$TENTACLE_NAME" \
  --apiKey "$OCTOPUS_API_KEY" \
  --publicHostName "$MACHINE_IP" \
  --environment "$TENTACLE_ENV" \
  --role "$TENTACLE_ROLE" \
  --comms-style "TentaclePassive"

echo "✓ Tentacle registered"
echo ""

# ============================================
# Step 7: Start Tentacle service
# ============================================
echo "Step 7: Starting Tentacle service..."

/opt/octopus/tentacle/tentacle/Tentacle service \
  --instance "$TENTACLE_NAME" \
  --install \
  --start

sleep 2

# Check status
if systemctl is-active --quiet tentacle || pgrep -f "Tentacle.exe" > /dev/null; then
    echo "✓ Tentacle service is running"
else
    echo "⚠ Tentacle service may not be running - check logs"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=================================================="
echo "✓ Setup Complete!"
echo "=================================================="
echo ""
echo "Tentacle Details:"
echo "  Name: $TENTACLE_NAME"
echo "  IP: $MACHINE_IP"
echo "  Port: $TENTACLE_PORT (Listening)"
echo "  Role: $TENTACLE_ROLE"
echo "  Environment: $TENTACLE_ENV"
echo "  Communication: Listening (TentaclePassive)"
echo ""
echo "IMPORTANT: Octopus must be able to reach this machine on port $TENTACLE_PORT"
echo "You may need to add a Security Group rule:"
echo "  Source: CI/CD SG (Octopus)"
echo "  Destination: CP SG"
echo "  Port: $TENTACLE_PORT"
echo ""
echo "Next Steps:"
echo "  1. Add Security Group rule (see above)"
echo "  2. Verify in Octopus UI: Infrastructure > Deployment Targets"
echo "  3. Test connection (should show 'Healthy')"
echo "  4. Update deployment process to use role: $TENTACLE_ROLE"
echo ""
