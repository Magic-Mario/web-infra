# AWS Network Firewall: inspección de la salida de las subredes privadas.
#
# Las subredes privadas enrutan 0.0.0.0/0 por el endpoint del firewall de su AZ
# (ver network.tf). El firewall evalúa el tráfico con un rule group stateful y
# solo permite:
#   - HTTPS (TLS/443) hacia Internet
#   - DNS (53)
#   - el retorno de conexiones establecidas
# Todo lo demás se descarta. El firewall reenvía a continuación al NAT Gateway
# de la subred firewall correspondiente.

resource "aws_networkfirewall_rule_group" "egress" {
  capacity = 100
  name     = "${local.name_prefix}-egress"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<-EOT
        pass tls any any -> any any (msg:"allow HTTPS egress"; sid:100; rev:1;)
        pass udp any any -> any 53 (msg:"allow DNS udp"; sid:101; rev:1;)
        pass tcp any any -> any 53 (msg:"allow DNS tcp"; sid:102; rev:1;)
        pass tcp any any -> any any (msg:"allow established return"; flow:established; sid:103; rev:1;)
        drop tcp any any -> any any (msg:"drop non-HTTPS egress"; sid:200; rev:1;)
        drop udp any any -> any any (msg:"drop non-DNS egress"; sid:201; rev:1;)
      EOT
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-egress"
  })
}

resource "aws_networkfirewall_firewall_policy" "edge" {
  name = "${local.name_prefix}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.egress.arn
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-policy"
  })
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${local.name_prefix}-nfw"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.edge.arn
  vpc_id              = aws_vpc.main.id

  delete_protection                 = false
  subnet_change_protection          = false
  firewall_policy_change_protection = false

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nfw"
  })
}
