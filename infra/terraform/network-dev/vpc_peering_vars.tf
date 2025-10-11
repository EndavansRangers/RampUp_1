# ============================================
# VPC Peering Variables for Dev Account
# ============================================

variable "dev_vpc_id" {
  type        = string
  description = "Dev VPC ID"
  default     = "vpc-0ac1ff8ba92cbf0f4"  # Dev VPC ID
}

variable "prod_vpc_id" {
  type        = string
  description = "Prod VPC ID (from Prod account)"
  default     = "vpc-0976ad85d907cbb75"  # Prod VPC ID
}

variable "prod_vpc_cidr" {
  type        = string
  description = "Prod VPC CIDR block"
  default     = "10.30.0.0/16"
}

variable "prod_account_id" {
  type        = string
  description = "Prod AWS Account ID"
  default     = "038686090046"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "configure_octopus_sg" {
  type        = bool
  description = "Whether to automatically configure Octopus security group"
  default     = true
}

variable "octopus_security_group_id" {
  type        = string
  description = "Octopus Security Group ID (if configure_octopus_sg is false, configure manually)"
  default     = ""
}
