# Borde público: Application Load Balancer internet-facing en las subredes
# públicas. Termina TLS (ACM) y enruta por path a los servicios privados:
#
#   :80  -> 301 HTTPS (redirección permanente)
#   :443 -> /       => frontend (private subnet)
#           /api/*  => backend  (private subnet)
#
# Los servicios no tienen IP pública: solo son alcanzables a través del ALB.

resource "aws_acm_certificate" "edge" {
  domain_name       = var.certificate_domain
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-edge-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "edge" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-fe-tg"
  port        = local.service_port["frontend"]
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-fe-tg"
    Service = "frontend"
  })
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-be-tg"
  port        = local.service_port["backend"]
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/balance"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-be-tg"
    Service = "backend"
  })
}

# HTTP 80: redirección permanente a HTTPS (no sirve contenido en claro).
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.edge.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = tostring(local.https_port)
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS 443: terminación TLS y forward por defecto al frontend.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.edge.arn
  port              = local.https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.edge.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# /api/* va directo al backend.
resource "aws_lb_listener_rule" "api_to_backend" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
