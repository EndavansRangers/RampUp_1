#!/bin/bash
# User Data for TeamCity CI Server
# This script prepares the instance for Ansible configuration

set -e

# Variables from Terraform
PROJECT="${project}"
ENV="${env}"
REGION="${region}"

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=================================================="
echo "TeamCity CI Server - User Data Script"
echo "=================================================="
echo "Project: $PROJECT"
echo "Environment: $ENV"
echo "Region: $REGION"
echo "Timestamp: $(date)"
echo "=================================================="

# Update system
echo "[1/6] Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools
echo "[2/6] Installing basic tools..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    python3 \
    python3-pip \
    awscli

# Configure hostname
echo "[3/6] Configuring hostname..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
HOSTNAME="${project}-${env}-teamcity"
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

# Store instance info in SSM
echo "[4/6] Storing instance info in SSM Parameter Store..."
PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
aws ssm put-parameter \
    --name "/${project}/${env}/teamcity/instance-id" \
    --value "$INSTANCE_ID" \
    --type "String" \
    --overwrite \
    --region "${region}" || true

aws ssm put-parameter \
    --name "/${project}/${env}/teamcity/private-ip" \
    --value "$PRIVATE_IP" \
    --type "String" \
    --overwrite \
    --region "$REGION" || true

# Prepare for Ansible
echo "[5/6] Preparing for Ansible configuration..."
# Create marker file to indicate user-data completed
touch /var/lib/cloud/instance/user-data-finished

# Wait for Ansible to configure the rest
echo "[6/6] Basic setup completed. Waiting for Ansible configuration..."
echo "TeamCity will be configured by Ansible playbook"
echo "Access will be available at: http://$PRIVATE_IP:8111"
echo ""
echo "=================================================="
echo "User Data Script Completed Successfully"
echo "Timestamp: $(date)"
echo "=================================================="

# Signal completion
aws ssm put-parameter \
    --name "/${project}/${env}/teamcity/user-data-status" \
    --value "completed" \
    --type "String" \
    --overwrite \
    --region "${region}" || true
