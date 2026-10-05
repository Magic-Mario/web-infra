variable "region" {
  description = "Región usada por todos los recursos (valor por defecto de Floci)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto; prefijo de nombres de recursos"
  type        = string
  default     = "cloud-project"
}

variable "cluster_version" {
  description = "Versión de Kubernetes para los clústeres EKS"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC compartida"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr debe ser un CIDR IPv4 válido."
  }
}

variable "public_subnets" {
  description = <<-EOT
    Subredes públicas (2 AZs). Albergan el ALB internet-facing y los NAT
    Gateways. No corren cargas de la aplicación.
  EOT

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  default = {
    a = {
      cidr_block        = "10.0.0.0/24"
      availability_zone = "us-east-1a"
    }
    b = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "firewall_subnets" {
  description = <<-EOT
    Subredes dedicadas al endpoint de AWS Network Firewall (una por AZ). La
    inspección de egreso vive aquí, separada de las subredes de aplicación.
  EOT

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  default = {
    a = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1a"
    }
    b = {
      cidr_block        = "10.0.3.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "private_subnets" {
  description = <<-EOT
    Subredes privadas, una por servicio (backend / frontend). Sin acceso directo
    a Internet: su egreso pasa por Network Firewall y sale por el NAT Gateway.
  EOT

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  default = {
    backend = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
    }
    frontend = {
      cidr_block        = "10.0.11.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "certificate_domain" {
  description = "Dominio del certificado ACM que usa el listener HTTPS del ALB"
  type        = string
  default     = "finance.local"
}

variable "waf_enforcement" {
  description = <<-EOT
    Postura de la Web ACL del ALB: "count" registra las coincidencias sin
    bloquear (rollout seguro recomendado, para revisar logs antes de aplicar) o
    "block" aplica las reglas. El default es "count" según la guía de AWS WAF.
  EOT
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.waf_enforcement)
    error_message = "waf_enforcement debe ser 'count' o 'block'."
  }
}

variable "waf_rate_limit" {
  description = "Límite de peticiones por IP en una ventana de 300 s (mínimo 10)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 10
    error_message = "waf_rate_limit debe ser >= 10 (mínimo de AWS WAF)."
  }
}

variable "node_instance_type" {
  description = "Tipo de instancia de los nodos (Floci usa un nodo k3s por clúster)"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Número de nodos deseados por clúster"
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
