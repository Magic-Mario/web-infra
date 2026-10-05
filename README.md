# cloud-project-infra

Todo el Terraform del proyecto (red, 2 clústeres EKS, ALB, NAT, Network
Firewall, WAF, IAM, ECR) más el entorno local (Floci) y su pipeline.

## Layout

- `*.tf`, `modules/eks-cluster/` — infraestructura (ECR `IMMUTABLE`, FR-019)
- `docker-compose.yaml` — emulador Floci (EKS real mode)
- `docs/LOCAL_DEV.md` — guía canónica dev local multi-repo (SC-001)
- `.github/workflows/plan.yaml` — `fmt -check`, `validate`, `plan` en PR
- `.github/workflows/apply.yaml` — `apply` solo en `main` (FR-018)

## Uso local

```bash
docker compose up -d
terraform init && terraform fmt -check && terraform validate
terraform plan && terraform apply -auto-approve
aws --endpoint-url http://localhost:4566 eks list-clusters
```

## Repos hermanos

- `cloud-project-backend` — Python + FastAPI + contratos + su `k8s/`
- `cloud-project-frontend` — Next.js + su `k8s/`

Un deploy aquí no toca las apps; un deploy de app no toca esta infra (SC-007).
