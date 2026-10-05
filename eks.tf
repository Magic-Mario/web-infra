# Dos entornos de ejecución independientes: backend y frontend.
# Un módulo reutilizable invocado una vez por servicio (FR-004).
module "eks" {
  for_each = local.services
  source   = "./modules/eks-cluster"

  cluster_name       = each.key
  kubernetes_version = var.cluster_version
  cluster_role_arn   = aws_iam_role.cluster[each.key].arn
  node_role_arn      = aws_iam_role.node[each.key].arn
  subnet_ids         = [aws_subnet.private[each.key].id]
  security_group_ids = [aws_security_group.service[each.key].id]
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  create_addons      = var.create_addons

  tags = merge(local.common_tags, { Name = each.key })
}
