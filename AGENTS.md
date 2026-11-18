# AI Coding Assistant Instructions (`AGENTS.md`)

This file defines the architectural boundaries, security guardrails, and mandatory validation commands for AI coding assistants (GitHub Copilot, Cursor, Claude Code, Windsurf, etc.) working in the `infra` repository.

---

## 1. Repository Map & Domain Boundaries

```text
infra/
├── .github/
│   ├── workflows/
│   │   ├── infra-ci.yml             # PR & main branch linter/validator (Terraform, Compose, ShellCheck)
│   │   ├── infra-cd.yml             # Post-CI deployment sync to App EC2 & Monitoring EC2
│   │   └── aws-power-schedule.yml   # FinOps start/stop orchestration for EC2 & RDS
│   └── PULL_REQUEST_TEMPLATE.md     # Standardized PR checklist & verification template
├── compose/
│   ├── docker-compose.yml       # App stack (gateway, frontend, backend, node-exporter, local mysql)
│   ├── .env.example             # Environment variable template (safe to commit)
│   └── nginx/
│       ├── nginx.conf           # Production HTTPS + Let's Encrypt + strict rate limits (10r/m, 10r/s)
│       └── nginx.local.conf     # Local/QA HTTP + relaxed rate limits (120r/m, 50r/s)
├── docs/                        # Technical runbooks (Architecture, CI/CD, Monitoring/Backups/FinOps)
├── monitoring/
│   ├── docker-compose.yml       # Observability stack (prometheus, grafana, uptime-kuma)
│   ├── prometheus.yml           # Private VPC scrape targets (10.0.1.171:8080 & :9100)
│   ├── alert.rules.yml          # BackendDown, HighJvmHeapUsage, HighHttp5xxErrorRate rules
│   └── .env.example             # Template for Grafana credentials & APP_PRIVATE_IP
├── scripts/
│   ├── bootstrap.sh             # Ubuntu 22.04 cloud-init (2GB swap, Docker CE, log rotation)
│   └── backup_mysql.sh          # RDS MySQL logical backup with GTID/non-superuser flags & 7d retention
└── terraform/
    ├── main.tf                  # VPC, Subnets, Security Groups, EC2 (App + Mon), RDS MySQL 8.4
    ├── variables.tf             # Input variables (Free Tier volume sizing: 20GB App + 10GB Mon)
    ├── outputs.tf               # Public/Private IPs, RDS endpoint, Dashboard URLs
    └── providers.tf             # AWS provider configuration
```

---

## 2. Mandatory Pre-Commit Validation Commands

Whenever you modify Terraform files, Docker Compose manifests, Nginx configs, or Bash scripts, you **MUST** run and pass the following checks before finalizing your changes:

```bash
# 1. Terraform syntax & schema validation (no AWS credentials required)
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate

# 2. Application Docker Compose validation
cp compose/.env.example compose/.env
docker compose -f compose/docker-compose.yml config -q

# 3. Monitoring Docker Compose validation
cp monitoring/.env.example monitoring/.env
docker compose -f monitoring/docker-compose.yml config -q

# 4. Bash script static analysis
shellcheck --severity=error scripts/*.sh
```

---

## 3. Strict Security & Architectural Guardrails

### A. Zero Secrets in Git
* **NEVER** commit `.env`, `*.tfvars`, `*.tfstate`, `*.pem`, `*.key`, or hardcoded credentials.
* Always document new environment variables in `compose/.env.example` or `monitoring/.env.example` using safe placeholder values (`CHANGE_ME_*`).

### B. AWS RDS MySQL Non-Superuser Flags (`scripts/backup_mysql.sh`)
* AWS RDS restricts `SUPER` and `SYSTEM_VARIABLES_ADMIN` privileges.
* Any `mysqldump` invocation targeting RDS **must** keep `--no-defaults` as the **first** argument and include `--single-transaction`, `--skip-lock-tables`, `--set-gtid-purged=OFF`, and `--no-tablespaces`.

### C. Nginx Gateway Parity & Upstream DNS Resolution (`compose/nginx/`)
* **Configuration Parity:** Any routing, security header, or error-contract change in `compose/nginx/nginx.conf` **must** be mirrored in `compose/nginx/nginx.local.conf` (excluding TLS directives and rate-limit thresholds).
* **429 Error Contract:** Rate-limited endpoints must return HTTP `429` with `{"code":"TOO_MANY_REQUESTS","message":"Rate limit exceeded. Please wait a moment and try again.","fieldErrors":[]}` and preserve the `X-QA-Bypass: team262-qa` exemption.
* **Actuator Isolation:** Never expose `/actuator` or `/api/actuator` publicly in Nginx; keep the `403 FORBIDDEN` block intact. Prometheus scrapes `:8080/actuator/prometheus` strictly over the internal AWS VPC (`monitoring_sg` $\rightarrow$ `web_sg`).
* **Dynamic DNS / Upstream Reloads:** Nginx resolves `http://backend:8080` and `http://frontend:80` via Docker's embedded DNS. When recreating upstream containers, always run `docker exec moviematch_gateway nginx -t && docker exec moviematch_gateway nginx -s reload` to avoid stale container IPs.

### D. `t3.micro` Memory & AWS Free Tier Constraints
* Both EC2 instances (`team262-app-ec2` and `team262-app-monitoring-ec2`) are `t3.micro` (`1 GB` RAM). Do not increase container `deploy.resources.limits.memory` in `compose/docker-compose.yml` beyond a combined total of `~850 MB` for production services (`gateway: 64M`, `frontend: 64M`, `backend: 680M`, `node-exporter: 32M`).
* Keep EBS root volume sizes at `20 GB` (`root_volume_size`) + `10 GB` (`monitoring_volume_size`) = `30 GB` total to remain compliant with the AWS Free Tier limit.