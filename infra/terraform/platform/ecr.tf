resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repos)

  name                 = "${each.value}-${var.env}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "AES256" }

  tags = merge(local.common_tags, { Name = "${local.name}-${each.value}" })
}

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each  = aws_ecr_repository.repos
  repository = each.value.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 30 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 30
      }
      action = { type = "expire" }
    }]
  })
}
