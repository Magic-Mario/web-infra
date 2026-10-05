# Repositorios ECR propios de cada servicio: ninguno comparte almacenamiento.
resource "aws_ecr_repository" "app" {
  for_each = local.services

  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = merge(local.common_tags, { Name = each.key })
}
