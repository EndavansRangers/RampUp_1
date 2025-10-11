#!/bin/bash
# Octopus Tentacle Installation Script for Production
# This script installs Octopus Tentacle in Polling mode to connect to Octopus in Dev account

set -e

# Variables from Terraform
PROJECT="${project}"
ENV="${env}"
REGION="${region}"
K8S_API_SERVER="${k8s_api_server}"
OCTOPUS_SERVER_URL="${octopus_server_url}"
OCTOPUS_API_KEY="${octopus_api_key}"
OCTOPUS_SPACE="${octopus_space}"
OCTOPUS_ENVIRONMENT="${octopus_environment}"
OCTOPUS_ROLES="${octopus_roles}"

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Octopus Tentacle Production Setup ==="
echo "Project: $PROJECT | Environment: $ENV | Region: $REGION"
echo "Kubernetes API: $K8S_API_SERVER"
echo "Octopus Server: $OCTOPUS_SERVER_URL"

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    ca-certificates \
    gnupg \
    apt-transport-https

# Install AWS CLI v2
echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Helm
echo "=== Installing Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Docker (for running deployment tasks if needed)
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install Octopus Tentacle
echo "=== Installing Octopus Tentacle ==="
wget https://apt.octopus.com/public.key -O - | apt-key add -
echo "deb https://apt.octopus.com/ stable main" | tee /etc/apt/sources.list.d/octopus.list
apt-get update
apt-get install -y tentacle

# Configure Tentacle
echo "=== Configuring Octopus Tentacle ==="

TENTACLE_HOME="/home/Octopus"
TENTACLE_APP="/home/Octopus/Applications"
INSTANCE_NAME="Tentacle"

mkdir -p $TENTACLE_HOME
mkdir -p $TENTACLE_APP

# Create new instance
/opt/octopus/tentacle/Tentacle create-instance \
    --instance "$INSTANCE_NAME" \
    --config "/etc/octopus/$INSTANCE_NAME/tentacle.config"

# Configure Tentacle
/opt/octopus/tentacle/Tentacle new-certificate \
    --instance "$INSTANCE_NAME" \
    --if-blank

/opt/octopus/tentacle/Tentacle configure \
    --instance "$INSTANCE_NAME" \
    --home "$TENTACLE_HOME" \
    --app "$TENTACLE_APP" \
    --port "10933" \
    --noListen "True"  # Polling mode - Tentacle connects to server

# Register with Octopus Server
echo "=== Registering Tentacle with Octopus Server ==="

MACHINE_NAME="tunefy-prod-worker-$(ec2-metadata --instance-id | cut -d ' ' -f 2)"

/opt/octopus/tentacle/Tentacle register-worker \
    --instance "$INSTANCE_NAME" \
    --server "$OCTOPUS_SERVER_URL" \
    --apiKey "$OCTOPUS_API_KEY" \
    --space "$OCTOPUS_SPACE" \
    --workerpool "Default Worker Pool" \
    --name "$MACHINE_NAME" \
    --comms-style "TentacleActive" \
    --server-comms-port "10943" \
    --policy "Default Machine Policy"

# Start service
/opt/octopus/tentacle/Tentacle service \
    --instance "$INSTANCE_NAME" \
    --install \
    --start

echo "=== Tentacle registered and started ==="

# Configure kubectl for Kubernetes cluster
echo "=== Setting up Kubernetes access ==="
mkdir -p /home/ubuntu/.kube

# Create script to get kubeconfig from control plane
cat > /home/ubuntu/setup-kubeconfig.sh <<'KUBESCRIPT'
#!/bin/bash
# This script should be run to setup kubectl access
# It requires SSH access to the control plane

set -e

BASTION_IP="54.91.57.185"
CONTROL_PLANE_IP="10.30.62.6"

echo "=== Getting kubeconfig from control plane ==="

# Get kubeconfig via SSH
ssh -o StrictHostKeyChecking=no -J ubuntu@$BASTION_IP ubuntu@$CONTROL_PLANE_IP 'cat ~/.kube/config' > /tmp/kubeconfig-temp

# Update server URL to use NLB
sed "s|https://.*:6443|${k8s_api_server}|g" /tmp/kubeconfig-temp > /home/ubuntu/.kube/config

chmod 600 /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "=== Kubeconfig configured ==="
echo "Testing connection..."
kubectl get nodes

echo "✅ Kubernetes access configured successfully!"
KUBESCRIPT

chmod +x /home/ubuntu/setup-kubeconfig.sh

# Note: kubeconfig setup requires SSH key, will be done manually or via Secrets Manager
echo "⚠️  Run /home/ubuntu/setup-kubeconfig.sh to configure kubectl access"

# Create deployment helper scripts
mkdir -p /home/ubuntu/octopus-scripts

cat > /home/ubuntu/octopus-scripts/deploy-app.sh <<'DEPLOYSCRIPT'
#!/bin/bash
# Generic deployment script for Octopus

set -e

APP_NAME=$1
VERSION=$2
NAMESPACE=$${3:-tunefy-app}

if [ -z "$APP_NAME" ] || [ -z "$VERSION" ]; then
    echo "Usage: $0 <app-name> <version> [namespace]"
    exit 1
fi

ECR_REPO="038686090046.dkr.ecr.us-east-1.amazonaws.com"
IMAGE="$ECR_REPO/tunefy-$APP_NAME-prod:$VERSION"

echo "=== Deploying $APP_NAME version $VERSION ==="
echo "Image: $IMAGE"
echo "Namespace: $NAMESPACE"

# Update deployment
kubectl set image deployment/tunefy-$APP_NAME \
    $APP_NAME=$IMAGE \
    -n $NAMESPACE

# Wait for rollout
kubectl rollout status deployment/tunefy-$APP_NAME -n $NAMESPACE --timeout=5m

echo "✅ Deployment complete!"
DEPLOYSCRIPT

cat > /home/ubuntu/octopus-scripts/rollback-app.sh <<'ROLLBACKSCRIPT'
#!/bin/bash
# Rollback script for Octopus

set -e

APP_NAME=$1
NAMESPACE=$${2:-tunefy-app}

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name> [namespace]"
    exit 1
fi

echo "=== Rolling back $APP_NAME ==="

kubectl rollout undo deployment/tunefy-$APP_NAME -n $NAMESPACE

kubectl rollout status deployment/tunefy-$APP_NAME -n $NAMESPACE --timeout=5m

echo "✅ Rollback complete!"
ROLLBACKSCRIPT

chmod +x /home/ubuntu/octopus-scripts/*.sh
chown -R ubuntu:ubuntu /home/ubuntu/octopus-scripts

# Setup ECR authentication helper
cat > /home/ubuntu/ecr-login.sh <<'ECRSCRIPT'
#!/bin/bash
AWS_ACCOUNT_ID="038686090046"
AWS_REGION="us-east-1"

aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "✅ ECR login successful"
ECRSCRIPT

chmod +x /home/ubuntu/ecr-login.sh

# Setup cron for ECR login (every 6 hours)
echo "0 */6 * * * /home/ubuntu/ecr-login.sh >> /var/log/ecr-login.log 2>&1" | crontab -u ubuntu -

echo "=== Octopus Tentacle installation complete! ==="
echo ""
echo "Tentacle Name: $MACHINE_NAME"
echo "Octopus Server: $OCTOPUS_SERVER_URL"
echo "Environment: $OCTOPUS_ENVIRONMENT"
echo "Roles: $OCTOPUS_ROLES"
echo ""
echo "Next steps:"
echo "1. Setup kubectl: /home/ubuntu/setup-kubeconfig.sh"
echo "2. Verify in Octopus UI that worker is registered"
echo "3. Create deployment projects in Octopus"
echo ""
echo "Deployment scripts: /home/ubuntu/octopus-scripts/"
echo ""
echo "=== Setup Complete ==="
