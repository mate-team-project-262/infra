# Observability, Automated Backups, FinOps & SSH Tunnels

This document covers the dedicated monitoring stack, Prometheus alert rules, RDS MySQL logical backups, automated AWS cost-optimization workflows, and SSH port-forwarding tunnels.

---

## 1. Observability Stack (`monitoring/`)

To prevent observability workloads from competing with the Spring Boot JVM for memory, the monitoring stack runs on a dedicated EC2 instance (`team262-app-monitoring-ec2`) and scrapes the Primary App EC2 (`10.0.1.171`) over the private AWS VPC network.

| Service | Container Name | Image | Port | Memory Limit | Purpose & Configuration |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Prometheus** | `monitoring_prometheus` | `prom/prometheus:v2.54.1` | `9090` (internal) | **256 MB** | 15s scrape interval, 7-day TSDB retention (`--storage.tsdb.retention.time=7d`), lifecycle reload enabled. |
| **Grafana** | `monitoring_grafana` | `grafana/grafana-oss:11.2.0` | `3000:3000` | **256 MB** | Dashboards for Host metrics (Node Exporter), JVM memory/GC, HTTP latency, and HikariCP MySQL pool (`GF_USERS_ALLOW_SIGN_UP=false`). |
| **Uptime Kuma** | `monitoring_uptime_kuma` | `louislam/uptime-kuma:1` | `3001:3001` | **192 MB** | External HTTPS availability probing of `https://what2watch.duckdns.org/gateway-health` and Let's Encrypt SSL expiry alerts. |

### Private VPC Scrape Targets (`monitoring/prometheus.yml`)
1. `prometheus` (`127.0.0.1:9090`): Prometheus self-health.
2. `app-ec2-node-exporter` (`10.0.1.171:9100`): Host CPU, RAM, swap usage, disk I/O, and network traffic on the App EC2 instance.
3. `moviematch_backend_jvm` (`10.0.1.171:8080/actuator/prometheus`): Spring Boot Actuator Micrometer metrics (JVM heap/non-heap, garbage collection, HTTP request histograms, and HikariCP active/idle connections).

---

## 2. Prometheus Alerting Rules & Telegram Notifications (`monitoring/alert.rules.yml`)

Alert rules are evaluated every `15s` under `moviematch_backend_application_alerts` and delivered to the engineering team's Telegram channel via Grafana Contact Points and Uptime Kuma webhooks:

| Alert Name | Severity | Trigger Condition & Window | Operational Meaning & Remediation |
| :--- | :--- | :--- | :--- |
| **`BackendDown`** | `critical` | `up{job="moviematch_backend_jvm"} == 0` for `1m` | Spring Boot container is down or unreachable over VPC port `8080`. Inspect `docker logs moviematch_backend`. |
| **`HighJvmHeapUsage`** | `warning` | `sum(jvm_memory_used_bytes{area="heap"}) / sum(jvm_memory_max_bytes{area="heap"}) * 100 > 85` for `2m` | JVM heap utilization exceeds 85% for 2 minutes. High risk of container `OOMKilled`. |
| **`HighHttp5xxErrorRate`** | `critical` | `5xx rate > 5%` AND `>= 3 errors` over `5m` (`for: 1m`) | Elevated server-side errors (e.g., database connectivity issues or unhandled exceptions). |

---

## 3. Automated RDS MySQL Backups (`scripts/backup_mysql.sh`)

Alongside AWS RDS automated daily snapshots (`03:00–04:00 UTC`), `scripts/backup_mysql.sh` creates portable logical backups on the App EC2 instance.

### Backup Architecture & RDS Compatibility
* **Credential Parsing:** Automatically loads database settings from `/home/ubuntu/infra/compose/.env` (or `/home/ubuntu/infra/.env`), sanitizing carriage returns (`\r`) and quotes.
* **AWS RDS Non-Superuser Flags:** Uses `mysqldump` options designed for managed AWS RDS instances (where master users do not hold `SUPER` privileges):
  * `--no-defaults` (placed first to ignore host `/etc/mysql/*.cnf` overrides)
  * `--single-transaction` & `--skip-lock-tables` (consistent InnoDB snapshot without locking active game rooms)
  * `--set-gtid-purged=OFF` & `--no-tablespaces` (avoids `Access denied; you need the SUPER or SYSTEM_VARIABLES_ADMIN privilege` errors on RDS)
  * `--quick --routines --triggers`
* **Compression & Integrity Check:** Compresses dumps via `gzip -9` into `/var/backups/mysql/moviematch_YYYYMMDD_HHMMSS.sql.gz` (`chmod 700`) and verifies archive integrity using `gzip -t`.
* **7-Day Retention Policy:** Purges archives older than 7 days (`find ... -mtime +7 -delete`) and supports syncing backups to S3 storage.

### Execution & Restore Runbook
```bash
# Run an immediate backup on App EC2:
sudo /home/ubuntu/infra/scripts/backup_mysql.sh

# Crontab schedule (daily at 02:30 UTC):
30 2 * * * /home/ubuntu/infra/scripts/backup_mysql.sh >> /var/log/mysql_backup.log 2>&1

# Restore a verified .sql.gz archive into AWS RDS MySQL:
zcat /var/backups/mysql/moviematch_YYYYMMDD_HHMMSS.sql.gz | \
  mysql --no-defaults -h "$MYSQL_HOST" -P 3306 -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

---

## 4. FinOps: AWS Nightly Cost Saver (`.github/workflows/aws-power-schedule.yml`)

To conserve AWS Free Tier compute hours and minimize cloud spend outside demonstration hours, the **AWS Nightly Cost Saver** workflow manages the power state of:
* Primary App EC2 (`tag:Name=team262-app-ec2`)
* Monitoring EC2 (`tag:Name=team262-app-monitoring-ec2`)
* AWS RDS MySQL (`team262-app-db`)

### Schedule & Dependency-Aware Boot Sequence
* **Nightly Shutdown (`stop`):** `19:47 UTC` (`21:47` Kyiv Winter Time) — stops both running EC2 instances first, then stops the RDS instance.
* **Morning Boot (`start`):** `05:47 UTC` (`07:47` Kyiv Winter Time) — starts the RDS database first and waits (`aws rds wait db-instance-available`) until MySQL is online **before** starting the App and Monitoring EC2 instances, ensuring Spring Boot HikariCP connects cleanly on boot.
* **Manual Control (`workflow_dispatch`):** Triggerable anytime from the GitHub Actions tab with `action: status | start | stop`.

---

## 5. Secure SSH Tunnels for Database & Metrics Access

Because AWS RDS (`3306`), Prometheus (`9090`), and Spring Boot Actuator (`8080`) are isolated from the public internet, engineers use SSH local port forwarding.

```bash
# 1. Connect local DBeaver / DataGrip / MySQL CLI (port 3307) to private AWS RDS:
ssh -i ~/.ssh/id_ed25519 \
  -L 3307:<RDS_ENDPOINT_FROM_TERRAFORM_OUTPUT>:3306 \
  ubuntu@<APP_EC2_EIP> -N

# 2. Access internal Prometheus UI on http://localhost:9090:
ssh -i ~/.ssh/id_ed25519 -L 9090:127.0.0.1:9090 ubuntu@<MONITORING_EC2_PUBLIC_IP> -N

# 3. Access internal Spring Boot Actuator on http://localhost:8081/actuator/health:
ssh -i ~/.ssh/id_ed25519 -L 8081:127.0.0.1:8080 ubuntu@<APP_EC2_EIP> -N
```