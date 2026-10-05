# Guía dev local multi-repo (SC-001: de cero a stack arriba en < 30 min)

Los 3 repos se clonan como directorios hermanos:

```text
portafolio/
├── cloud-project-infra/      # este repo: Terraform + Floci + esta guía
├── cloud-project-backend/    # Python + FastAPI + contratos + k8s/
└── cloud-project-frontend/   # Next.js + k8s/
```

Prerrequisitos: Docker con Compose v2, Terraform >= 1.10, `uv` (Python 3.12),
`bun` (TypeScript), AWS CLI v2. `kubectl` no hace falta en el host: se usa vía
`docker exec floci-eks-<cluster> kubectl ...` (ver `research.md`, Decisión 6).

## Orden

1. **Emulador** (en este repo):
   ```bash
   docker compose up -d
   curl -sf http://localhost:4566/_floci/health
   ```
2. **Infraestructura** (en este repo):
   ```bash
   terraform init && terraform fmt -check && terraform validate
   terraform plan && terraform apply -auto-approve
   aws --endpoint-url http://localhost:4566 eks list-clusters  # backend + frontend
   ```
3. **Imágenes** (un shell por repo de app). El registry de Floci es HTTP y hay
   que publicar **las dos rutas** (hallazgo 2026-10-05: el pull del k3s pide el
   path con prefijo `<account>/<region>/` vía el mirror de containerd, pero la
   API ECR local también acepta el path sin prefijo; publicar solo uno de los
   dos acaba en `ImagePullBackOff`):
   ```bash
   # ../cloud-project-backend
   docker build -t backend:local .
   for p in "localhost:5100/backend:local" \
            "localhost:5100/000000000000/us-east-1/backend:local"; do
     docker tag backend:local "$p" && docker push "$p"
   done
   # ../cloud-project-frontend: igual con frontend:local
   ```
   Los manifiestos `k8s/` referencian el nombre ECR
   (`000000000000.dkr.ecr.us-east-1.localhost:4566/<repo>:local`); Floci lo
   resuelve vía el mirror de containerd que inyecta en cada k3s.
4. **Cargas**: `kubectl apply` de cada `k8s/` vía
   `docker exec floci-eks-<cluster> kubectl ...` (helper: `scripts/deploy.sh`
   local hasta que los workflows lo cubran).
5. **Verificar**: humo REST (`quickstart.md` Pasos 5–5b) y reproducibilidad
   (`terraform destroy` + re-`apply`, Paso 6).

## Notas

- Los repos de app solo documentan su build/test unitario; el stack completo se
  orquesta desde aquí.
- ECR es `IMMUTABLE`: en local se usa el tag `:local`; en prod, tags
  `:<git-sha>` / `:<semver>` (nunca `latest`).
- La guía de validación paso a paso vive en `specs/.../quickstart.md` del repo
  de diseño; esta guía es el orden de arranque, no su duplicado.
