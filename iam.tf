# Roles de mínimo privilegio (constitution, principio V).
# Un rol de clúster y uno de nodo por entorno de ejecución.

resource "aws_iam_role" "cluster" {
  for_each = local.services

  name = "${local.name_prefix}-${each.key}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}-cluster-role" })
}

resource "aws_iam_role_policy" "cluster" {
  for_each = local.services

  name = "${local.name_prefix}-${each.key}-cluster-policy"
  role = aws_iam_role.cluster[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "node" {
  for_each = local.services

  name = "${local.name_prefix}-${each.key}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}-node-role" })
}

resource "aws_iam_role_policy" "node" {
  for_each = local.services

  name = "${local.name_prefix}-${each.key}-node-policy"
  role = aws_iam_role.node[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces", "eks:DescribeCluster"]
        Resource = "*"
      },
    ]
  })
}
