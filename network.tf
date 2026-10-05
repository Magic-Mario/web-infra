# Red de la plataforma (topología "production-shaped").
#
#   Internet
#     │
#   IGW
#     │
#   Subredes públicas (2 AZs) ── ALB internet-facing + NAT Gateway
#     │                                 │
#   Subredes firewall (2 AZs) ── AWS Network Firewall (inspección)
#     │
#   Subredes privadas (1 por servicio: backend / frontend)
#
# Política:
#   - Ingreso público: SOLO HTTP (80) / HTTPS (443) al ALB. El listener HTTP
#     responde 301 hacia HTTPS (ver alb.tf).
#   - Egreso de las subredes privadas: SOLO HTTPS (443) + DNS, inspeccionado por
#     Network Firewall (firewall.tf) y saliendo por el NAT Gateway.
#   - Las route tables y el IGW no filtran por puerto: el filtrado vive en el
#     ALB, Network Firewall, los security groups y las NACLs.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ---------------------------------------------------------------------------
# Subredes
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "firewall" {
  for_each = var.firewall_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-firewall-${each.key}"
    Tier = "firewall"
  })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-private"
    Tier    = "private"
    Service = each.key
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway y NAT (uno por AZ, para alta disponibilidad)
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_eip" "nat" {
  for_each = var.public_subnets

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each = var.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

# Públicas: salida a Internet por el IGW (para el ALB).
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Firewall: la inspección reenvía el tráfico al NAT de la misma AZ.
resource "aws_route_table" "firewall" {
  for_each = var.firewall_subnets

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-firewall-${each.key}-rt"
  })
}

resource "aws_route" "firewall_default" {
  for_each = var.firewall_subnets

  route_table_id         = aws_route_table.firewall[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "firewall" {
  for_each = aws_subnet.firewall

  subnet_id      = each.value.id
  route_table_id = aws_route_table.firewall[each.key].id
}

# Privadas: todo el egreso pasa por Network Firewall (misma AZ) y de ahí al NAT.
resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-private-rt"
  })
}

resource "aws_route" "private_default" {
  for_each = var.private_subnets

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoint_by_az[each.value.availability_zone]

  # Floci no refleja `VpcEndpointId` en DescribeRouteTables (aunque la ruta se
  # crea), así que Terraform vería drift perpetuo. La ruta real es correcta.
  lifecycle {
    ignore_changes = [vpc_endpoint_id]
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------------------------------------------------------------------
# Security groups (stateful)
# ---------------------------------------------------------------------------

# ALB: único punto de entrada público. Solo HTTP/HTTPS desde Internet.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Ingreso publico solo HTTP/HTTPS; salida hacia los servicios privados"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico (el listener redirige a HTTPS)"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egreso por CIDR (no por SG) para evitar un ciclo con el SG del servicio.
  egress {
    description = "Frontend privado"
    from_port   = local.service_port["frontend"]
    to_port     = local.service_port["frontend"]
    protocol    = "tcp"
    cidr_blocks = [var.private_subnets["frontend"].cidr_block]
  }

  egress {
    description = "Backend privado"
    from_port   = local.service_port["backend"]
    to_port     = local.service_port["backend"]
    protocol    = "tcp"
    cidr_blocks = [var.private_subnets["backend"].cidr_block]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# Servicios (privados): reciben del ALB y egresan solo HTTPS/DNS.
resource "aws_security_group" "service" {
  for_each = local.services

  name        = "${local.name_prefix}-${each.key}-sg"
  description = "Security group del servicio ${each.key} (privado)"
  vpc_id      = aws_vpc.main.id

  # Tráfico interno del propio clúster (EKS lo requiere entre sus nodos).
  ingress {
    description = "Trafico interno del entorno"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Desde el ALB"
    from_port       = local.service_port[each.key]
    to_port         = local.service_port[each.key]
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Este-oeste: el backend acepta al frontend (render en servidor).
  dynamic "ingress" {
    for_each = each.key == "backend" ? [1] : []
    content {
      description = "Backend desde el frontend (este-oeste)"
      from_port   = local.service_port["backend"]
      to_port     = local.service_port["backend"]
      protocol    = "tcp"
      cidr_blocks = [var.private_subnets["frontend"].cidr_block]
    }
  }

  egress {
    description = "Trafico interno del entorno"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "HTTPS saliente: unica salida a Internet"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = local.dns_port
    to_port     = local.dns_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-sg"
    Service = each.key
  })
}

# ---------------------------------------------------------------------------
# Network ACLs (stateless)
# ---------------------------------------------------------------------------

# --- NACL pública ---
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [for s in aws_subnet.public : s.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-nacl"
  })
}

resource "aws_network_acl_rule" "public_internal_in" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 90
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

resource "aws_network_acl_rule" "public_http_in" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.http_port
  to_port        = local.http_port
}

resource "aws_network_acl_rule" "public_https_in" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.https_port
  to_port        = local.https_port
}

resource "aws_network_acl_rule" "public_ephemeral_in" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from_port
  to_port        = local.ephemeral_to_port
}

resource "aws_network_acl_rule" "public_internal_out" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 90
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

resource "aws_network_acl_rule" "public_https_out" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.https_port
  to_port        = local.https_port
}

resource "aws_network_acl_rule" "public_ephemeral_out" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from_port
  to_port        = local.ephemeral_to_port
}

# --- NACL privada (una por servicio) ---
resource "aws_network_acl" "private" {
  for_each = var.private_subnets

  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private[each.key].id]

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-private-nacl"
    Service = each.key
  })
}

resource "aws_network_acl_rule" "private_internal_in" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 90
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
}

resource "aws_network_acl_rule" "private_service_in" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = local.service_port[each.key]
  to_port        = local.service_port[each.key]
}

resource "aws_network_acl_rule" "private_ephemeral_in" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from_port
  to_port        = local.ephemeral_to_port
}

resource "aws_network_acl_rule" "private_internal_out" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 90
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
}

resource "aws_network_acl_rule" "private_service_out" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = local.service_port[each.key]
  to_port        = local.service_port[each.key]
}

resource "aws_network_acl_rule" "private_https_out" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.https_port
  to_port        = local.https_port
}

resource "aws_network_acl_rule" "private_dns_out" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 120
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.dns_port
  to_port        = local.dns_port
}

resource "aws_network_acl_rule" "private_ephemeral_out" {
  for_each = var.private_subnets

  network_acl_id = aws_network_acl.private[each.key].id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from_port
  to_port        = local.ephemeral_to_port
}
