# Módulo reutilizable: un clúster EKS con su node group y addon.
# Se invoca una vez por entorno de ejecución (backend y frontend).

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = var.tags
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = [var.node_instance_type]
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_desired_size
    max_size     = var.node_desired_size
  }

  tags = var.tags
}

# Addons EKS. Floci no implementa CreateAddon (404 UnknownOperationException),
# así que por defecto `create_addons = var.create_addons` es false. El recurso
# queda declarado para cuando se apunte a AWS real.
resource "aws_eks_addon" "this" {
  count = var.create_addons ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = var.tags
}
