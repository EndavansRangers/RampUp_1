#!/bin/bash
# Complete setup script for Control Plane as Octopus Worker
# This script will:
# 1. Install required tools (helm, ensure AWS CLI)
# 2. Install Octopus Tentacle
# 3. Register with Octopus Server

set -euo pipefail

echo "=================================================="
echo "Setting up Control Plane as Octopus Worker"
echo "=================================================="
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo bash setup-cp-worker.sh"
    exit 1
fi

OCTOPUS_SERVER_URL="http://10.20.62.98:8080"
OCTOPUS_API_KEY="API-ZTJRLULIZSONJP94ZEGLSVUK4ZDKO4O"
TENTACLE_ENV="Dev"
TENTACLE_ROLE="k8s-deployer"
TENTACLE_NAME="cp1-tentacle"

# ============================================
# Step 1: Install Helm if not present
# ============================================
echo "Step 1: Checking Helm installation..."
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://get.helm.sh/helm-v3.13.1-linux-amd64.tar.gz | tar xz
    mv linux-amd64/helm /usr/local/bin/helm
    rm -rf linux-amd64
    chmod +x /usr/local/bin/helm
    echo "✓ Helm installed successfully"
else
    echo "✓ Helm already installed: $(helm version --short 2>/dev/null || helm version)"
fi
echo ""

# ============================================
# Step 2: Verify kubectl
# ============================================
echo "Step 2: Verifying kubectl..."
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
else
    echo "ERROR: kubectl not found"
    exit 1
fi
echo ""

# ============================================
# Step 3: Verify AWS CLI
# ============================================
echo "Step 3: Verifying AWS CLI..."
if command -v aws &> /dev/null; then
    echo "✓ AWS CLI found: $(aws --version)"
else
    echo "WARNING: AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    echo "✓ AWS CLI installed"
fi
echo ""

# ============================================
# Step 4: Test Kubernetes access
# ============================================
echo "Step 4: Testing Kubernetes access..."
if kubectl get nodes &> /dev/null; then
    echo "✓ Kubernetes cluster accessible"
    kubectl get nodes
else
    echo "ERROR: Cannot access Kubernetes cluster"
    exit 1
fi
echo ""

# ============================================
# Step 5: Verify IAM Role for ECR
# ============================================
echo "Step 5: Verifying IAM credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✓ IAM Role available:"
    aws sts get-caller-identity
else
    echo "WARNING: No IAM credentials found (may need instance profile)"
fi
echo ""

# ============================================
# Step 6: Download Octopus Tentacle
# ============================================
echo "Step 6: Installing Octopus Tentacle..."
cd /tmp

if [ ! -f tentacle-linux_x64.tar.gz ]; then
    echo "Downloading Tentacle..."
    wget -q https://octopus.com/downloads/latest/Linux_x64TarGz/OctopusTentacle -O tentacle-linux_x64.tar.gz
fi

echo "Extracting Tentacle..."
mkdir -p /opt/octopus/tentacle
tar xzf tentacle-linux_x64.tar.gz -C /opt/octopus/tentacle

echo "✓ Tentacle extracted to /opt/octopus/tentacle"
echo ""

# ============================================
# Step 7: Configure Tentacle
# ============================================
echo "Step 7: Configuring Tentacle..."

# Create instance
/opt/octopus/tentacle/tentacle/Tentacle create-instance \
  --instance "$TENTACLE_NAME" \
  --config "/etc/octopus/$TENTACLE_NAME/tentacle.config"

# Generate certificate
/opt/octopus/tentacle/tentacle/Tentacle new-certificate \
  --instance "$TENTACLE_NAME" \
  --if-blank

# Reset trust
/opt/octopus/tentacle/tentacle/Tentacle configure \
  --instance "$TENTACLE_NAME" \
  --reset-trust

# Configure application directory and polling mode
/opt/octopus/tentacle/tentacle/Tentacle configure \
  --instance "$TENTACLE_NAME" \
  --app "/home/Octopus/Applications" \
  --port 10933 \
  --noListen "True"

echo "✓ Tentacle configured"
echo ""

# ============================================
# Step 8: Register with Octopus Server
# ============================================
echo "Step 8: Registering with Octopus Server..."

/opt/octopus/tentacle/tentacle/Tentacle register-with \
  --instance "$TENTACLE_NAME" \
  --server "$OCTOPUS_SERVER_URL" \
  --name "$TENTACLE_NAME" \
  --apiKey "$OCTOPUS_API_KEY" \
  --environment "$TENTACLE_ENV" \
  --role "$TENTACLE_ROLE" \
  --comms-style "TentacleActive" \
  --server-comms-port "10943"

echo "✓ Tentacle registered with Octopus"
echo ""

# ============================================
# Step 9: Install and start service
# ============================================
echo "Step 9: Starting Tentacle service..."

/opt/octopus/tentacle/tentacle/Tentacle service \
  --instance "$TENTACLE_NAME" \
  --install \
  --start

echo "✓ Tentacle service started"
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
echo "  Role: $TENTACLE_ROLE"
echo "  Environment: $TENTACLE_ENV"
echo "  Communication: Polling (TentacleActive)"
echo ""
echo "Tools Available:"
echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
echo "  - helm: $(helm version --short 2>/dev/null || helm version)"
echo "  - aws: $(aws --version)"
echo ""
echo "Next Steps:"
echo "  1. Verify in Octopus UI: Infrastructure > Deployment Targets"
echo "  2. Check that target shows as 'Healthy'"
echo "  3. Update deployment process to use role: $TENTACLE_ROLE"
echo ""
