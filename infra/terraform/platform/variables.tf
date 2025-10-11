variable "project" { type = string }
variable "env"     { type = string }  # "dev" | "prod"
variable "region"  { type = string }

variable "repos" {
  description = "Repos ECR base"
  type        = list(string)
  default     = ["tunefy-frontend", "tunefy-backend"]
}

variable "root_domain" {
  description = "public domain root"
  type        = string
}

variable "create_zone" {
  description = "If true, creates a hosted public zone; if false, use a created one"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
