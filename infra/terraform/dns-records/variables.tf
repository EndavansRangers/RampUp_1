variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "tunefy"
}

variable "env" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = "Z08442723HGVVHTX7RMST"
}

variable "alb_dns_name" {
  description = "ALB DNS name from Kubernetes Ingress"
  type        = string
  default     = "k8s-tunefyde-tunefyfr-e359f2b74f-2122536134.us-east-1.elb.amazonaws.com"
}

variable "alb_zone_id" {
  description = "ALB Hosted Zone ID (us-east-1)"
  type        = string
  default     = "Z35SXDOTRQ7X7K"  # us-east-1 ALB zone ID
}
