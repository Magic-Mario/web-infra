# Repositorios ECR propios de cada servicio: ninguno comparte almacenamiento.
# IMMUTABLE (FR-019): un tag publicado no se sobrescribe; el rollback es
# re-aplicar el tag anterior. `latest` flotante prohibido en prod.
resource "aws_ecr_repository" "app" {
  for_each = local.services

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  tags = merge(local.common_tags, { Name = each.key })
}
