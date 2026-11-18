# Claude Code Instructions (`CLAUDE.md`)

@AGENTS.md

Please read and strictly follow all validation workflows, directory boundaries, and security guardrails defined in [`AGENTS.md`](./AGENTS.md) and the domain guides under [`docs/`](./docs/).

## Quick Verification Checklist for Claude Code

Before completing any task or creating a commit in this repository, run:

1. **Terraform Check:**
   `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate`

2. **App Compose Check:**
   `docker compose -f compose/docker-compose.yml --env-file compose/.env.example config -q`

3. **Monitoring Compose Check:**
   `docker compose -f monitoring/docker-compose.yml --env-file monitoring/.env.example config -q`

4. **ShellCheck Linter:**
   `shellcheck --severity=error scripts/*.sh`

### Critical Invariants

* **No Secrets:** Never stage `.env`, `terraform.tfstate*`, `tfplan`, or `*.tfvars`.
* **Nginx Parity:** Keep routing, security headers, `/actuator` blocking (`403`), and `429` JSON error contracts synchronized between `compose/nginx/nginx.conf` and `compose/nginx/nginx.local.conf`.
* **RDS Backups:** Preserve `--no-defaults` (first argument), `--set-gtid-purged=OFF`, and `--no-tablespaces` in `scripts/backup_mysql.sh`.
* **Documentation Sync:** Keep the root `README.md` concise (~75 lines) with the unified multi-repo overview at the top, and place detailed technical runbooks in `docs/architecture-and-network.md`, `docs/ci-cd-and-deployment.md`, or `docs/monitoring-backups-and-finops.md`.