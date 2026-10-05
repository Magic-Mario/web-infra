# AWS WAFv2 delante del ALB.
#
# Una Web ACL regional (scope REGIONAL, misma región que el ALB) filtra el
# tráfico HTTP/HTTPS antes de que llegue a los target groups.
#
# Postura (guía AWS WAF):
#   - `default_action = allow` de forma deliberada: la aplicación es pública y la
#     aplicación de la seguridad la llevan las reglas (managed rules + rate-based).
#   - Las reglas arrancan en **Count** (`waf_enforcement = "count"`), que registra
#     coincidencias sin bloquear. Tras revisar los logs se cambia a **block**.
#   - Managed rules ajustadas a la carga: Core Rule Set (OWASP Top 10, ~700 WCU) +
#     Known Bad Inputs (~200 WCU) = ~900 WCU (< 1500, dentro del precio base;
#     máximo duro 5000).
#   - Rate-based por IP (no hay CDN delante), ventana válida de 300 s.
#   - Asociar la Web ACL al ALB es el paso que la hace efectiva: sin asociación no
#     filtra nada.

data "aws_caller_identity" "current" {}

# --- Logging (la guía exige logs antes de afinar reglas) --------------------

resource "aws_kms_key" "waf_logs" {
  description         = "Cifrado en reposo de los logs de AWS WAF (${local.name_prefix})"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.name_prefix}"
          }
        }
      },
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-waf-logs" })
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.waf_logs.arn

  tags = merge(local.common_tags, { Name = "aws-waf-logs-${local.name_prefix}" })
}

# --- Web ACL ----------------------------------------------------------------

resource "aws_wafv2_web_acl" "edge" {
  name        = "${local.name_prefix}-web-acl"
  description = "Protege el ALB de ${local.name_prefix}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Core Rule Set: cobertura amplia OWASP Top 10.
  rule {
    name     = "aws-common"
    priority = 1

    override_action {
      dynamic "count" {
        for_each = local.waf_count ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = local.waf_count ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common"
    }
  }

  # Known Bad Inputs: patrones de explotación conocidos.
  rule {
    name     = "aws-known-bad-inputs"
    priority = 2

    override_action {
      dynamic "count" {
        for_each = local.waf_count ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = local.waf_count ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
    }
  }

  # Rate-based: mitiga floods HTTP por IP (sin CDN delante => IP directa).
  rule {
    name     = "rate-limit-per-ip"
    priority = 3

    action {
      dynamic "count" {
        for_each = local.waf_count ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = local.waf_count ? [] : [1]
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.waf_rate_limit
        evaluation_window_sec = 300
        aggregate_key_type    = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-web-acl"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-acl" })
}

# La asociación es lo que hace efectiva la Web ACL.
resource "aws_wafv2_web_acl_association" "edge" {
  resource_arn = aws_lb.edge.arn
  web_acl_arn  = aws_wafv2_web_acl.edge.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "edge" {
  resource_arn            = aws_wafv2_web_acl.edge.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  # No registrar credenciales ni sesiones.
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
