variable "project" {
  type        = string
  default     = "tunefy"
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

variable "retention_days" {
  type        = number
  default     = 30
  description = "Number of days to retain etcd backups"
}

variable "glacier_transition_days" {
  type        = number
  default     = 7
  description = "Days after which to transition backups to Glacier storage"
}
