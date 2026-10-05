output "cluster_name" {
  description = "Nombre del clúster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN del clúster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint del API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Versión de Kubernetes"
  value       = aws_eks_cluster.this.version
}

output "node_group_name" {
  description = "Nombre del node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_group_status" {
  description = "Estado del node group"
  value       = aws_eks_node_group.this.status
}
