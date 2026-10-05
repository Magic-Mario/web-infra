variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes"
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN del rol IAM del plano de control"
  type        = string
}

variable "node_role_arn" {
  description = "ARN del rol IAM de los nodos"
  type        = string
}

variable "subnet_ids" {
  description = "Subredes donde se despliega el clúster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups adicionales del clúster"
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "Tipo de instancia de los nodos"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Número de nodos deseados"
  type        = number
  default     = 1
}

variable "create_addons" {
  description = <<-EOT
    Crear addons EKS. Floci no implementa CreateAddon (devuelve
    UnknownOperationException / 404), por eso el default es false. El recurso
    queda declarado en el módulo para cuando se apunte a AWS real.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
