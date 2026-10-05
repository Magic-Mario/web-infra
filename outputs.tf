output "vpc_id" {
  description = "ID de la VPC compartida"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "ID de la subred privada dedicada de cada servicio"
  value       = { for name, s in aws_subnet.private : name => s.id }
}

output "public_subnet_ids" {
  description = "ID de las subredes públicas (ALB + NAT)"
  value       = { for name, s in aws_subnet.public : name => s.id }
}

output "firewall_subnet_ids" {
  description = "ID de las subredes del endpoint de Network Firewall"
  value       = { for name, s in aws_subnet.firewall : name => s.id }
}

output "nat_gateway_ids" {
  description = "ID del NAT Gateway de cada AZ"
  value       = { for name, n in aws_nat_gateway.main : name => n.id }
}

output "security_group_ids" {
  description = "Security group de cada servicio"
  value       = { for name, sg in aws_security_group.service : name => sg.id }
}

output "alb_dns_name" {
  description = "DNS público del Application Load Balancer (único borde)"
  value       = aws_lb.edge.dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.edge.arn
}

output "edge_certificate_arn" {
  description = "ARN del certificado ACM del listener HTTPS"
  value       = aws_acm_certificate.edge.arn
}

output "network_firewall_arn" {
  description = "ARN de AWS Network Firewall que inspecciona el egreso"
  value       = aws_networkfirewall_firewall.this.arn
}

output "waf_web_acl_arn" {
  description = "ARN de la Web ACL de AWS WAF asociada al ALB"
  value       = aws_wafv2_web_acl.edge.arn
}

output "waf_web_acl_name" {
  description = "Nombre de la Web ACL de AWS WAF"
  value       = aws_wafv2_web_acl.edge.name
}

output "waf_log_group_name" {
  description = "Log group de CloudWatch con los logs de AWS WAF"
  value       = aws_cloudwatch_log_group.waf.name
}

output "cluster_names" {
  description = "Nombre de cada clúster por servicio"
  value       = { for name, m in module.eks : name => m.cluster_name }
}

output "cluster_endpoints" {
  description = "Endpoint del API server de cada clúster"
  value       = { for name, m in module.eks : name => m.cluster_endpoint }
}

output "cluster_versions" {
  description = "Versión de Kubernetes de cada clúster"
  value       = { for name, m in module.eks : name => m.cluster_version }
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR por servicio"
  value       = { for name, r in aws_ecr_repository.app : name => r.repository_url }
}
