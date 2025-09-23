variable "project" { type = string }
variable "env" { type = string } # "dev" | "prod"
variable "region" { type = string }

variable "azs" {
  description = "AZs to use"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "nat_per_az" {
  description = "true = NAT for each AZ (HA), false = only one NAT"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
