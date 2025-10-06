variable "project" {
  type        = string
  description = "Project name"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "env" {
  type        = string
  default     = "prod"
  description = "Environment name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for bastion and NLB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for control planes and workers (multi-AZ)"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name for EC2 instances"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR block allowed to SSH to bastion (your IP /32)"
}

variable "cluster_name" {
  type        = string
  default     = "tunefy-prod"
  description = "Kubernetes cluster name"
}

variable "cp_instance_type" {
  type        = string
  default     = "t3.small"
  description = "Control plane instance type (2 vCPU / 2GB RAM - min for etcd HA)"
}

variable "wk_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Worker instance type (1 vCPU / 1GB RAM - Free Tier eligible)"
}

variable "bastion_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Bastion instance type (Free Tier eligible)"
}

variable "nodes_instance_profile_name" {
  type        = string
  description = "IAM instance profile name for K8s nodes (from platform module)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags for resources"
}
