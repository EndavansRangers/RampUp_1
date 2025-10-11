locals {
  name = "${var.project}-${var.env}"

  # create subnets:  /16 -> /20 publivs and /20 privates 
  # first block  /20s -> publics, second block -> privates
  public_subnets  = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i + length(var.azs))]

  common_tags = merge({
    Project = var.project
    Env     = var.env
  }, var.tags)
}
