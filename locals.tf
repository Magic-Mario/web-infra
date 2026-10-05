locals {
  # Ambos entornos de ejecución: backend y frontend como clústeres separados.
  services = {
    backend  = { name = "backend" }
    frontend = { name = "frontend" }
  }

  name_prefix = var.project

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Emulator  = "floci"
  }

  # Política de red: ingreso solo HTTP/HTTPS; egreso solo HTTPS (+ DNS).
  http_port           = 80
  https_port          = 443
  dns_port            = 53
  ephemeral_from_port = 1024
  ephemeral_to_port   = 65535

  # Puerto interno (contenedor) de cada servicio detrás del ALB.
  service_port = {
    backend  = 8000
    frontend = 3000
  }

  # Endpoint de Network Firewall por AZ, que el propio firewall expone al
  # crearse. Las subredes privadas enrutan su egreso por el endpoint de su AZ.
  firewall_endpoint_by_az = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }

  # WAF: por defecto en Count (rollout seguro); `block` aplica las reglas.
  waf_count = var.waf_enforcement == "count"
}
