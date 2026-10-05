# Módulo `eks-cluster`

Crea un clúster EKS con su node group y addon. Pensado para invocarse una vez
por entorno de ejecución (backend y frontend).

## Uso

```hcl
module "eks" {
  source = "./modules/eks-cluster"

  cluster_name       = "backend"
  kubernetes_version = "1.29"
  cluster_role_arn   = aws_iam_role.cluster["backend"].arn
  node_role_arn      = aws_iam_role.node["backend"].arn
  subnet_ids         = aws_subnet.main[*].id
  tags               = { Project = "cloud-project" }
}
```

## Entradas

| Nombre | Tipo | Obligatorio | Descripción |
|--------|------|-------------|-------------|
| `cluster_name` | string | sí | Nombre del clúster |
| `kubernetes_version` | string | sí | Versión de Kubernetes |
| `cluster_role_arn` | string | sí | Rol IAM del plano de control |
| `node_role_arn` | string | sí | Rol IAM de los nodos |
| `subnet_ids` | list(string) | sí | Subredes del clúster |
| `security_group_ids` | list(string) | no | Security groups adicionales |
| `node_instance_type` | string | no | Tipo de instancia |
| `node_desired_size` | number | no | Nodos deseados |
| `create_addons` | bool | no | Crear addons (metadata en Floci) |
| `tags` | map(string) | no | Etiquetas |

## Salidas

`cluster_name`, `cluster_arn`, `cluster_endpoint`, `cluster_version`,
`node_group_name`, `node_group_status`.
