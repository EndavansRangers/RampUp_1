locals {
  name       = "${var.project}-${var.env}"
  common_tags = merge({
    Project = var.project
    Env     = var.env
  }, var.tags)
}
