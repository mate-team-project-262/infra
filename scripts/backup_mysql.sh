#!/usr/bin/env bash
# ==============================================================================
# Script: backup_mysql.sh (Task T2-94)
# Description: Automated logical backup of AWS RDS MySQL with gzip compression,
#              RDS GTID compatibility, and 7-day retention policy.
# ==============================================================================
set -Eeuo pipefail

# 1. Locate the environment configuration file
ENV_FILE=""
if [[ -f "/home/ubuntu/infra/compose/.env" ]]; then
    ENV_FILE="/home/ubuntu/infra/compose/.env"
elif [[ -f "/home/ubuntu/infra/.env" ]]; then
    ENV_FILE="/home/ubuntu/infra/.env"
else
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') - Cannot locate .env file in infra/ or infra/compose/" >&2
    exit 1
fi

echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Loading environment variables from ${ENV_FILE}"

# 2. Safely parse KEY=VALUE pairs and strip carriage returns (\r) or quotes
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    key=$(echo "$key" | tr -d '[:space:]')
    value="${value%$'\r'}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    export "$key"="$value"
done < "$ENV_FILE"

# 3. Validate required database parameters before execution
: "${MYSQL_HOST:?Variable MYSQL_HOST is empty or unset in .env}"
: "${MYSQL_DATABASE:?Variable MYSQL_DATABASE is empty or unset in .env}"
: "${MYSQL_USER:?Variable MYSQL_USER is empty or unset in .env}"
: "${MYSQL_PASSWORD:?Variable MYSQL_PASSWORD is empty or unset in .env}"

BACKUP_DIR="/var/backups/mysql"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Connecting to RDS Host: ${MYSQL_HOST}:${MYSQL_PORT:-3306}"
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Starting logical backup for database '${MYSQL_DATABASE}'..."

# 4. Build mysqldump arguments in a Bash array (prevents backslash line-continuation issues)
# --no-defaults: ignore /etc/mysql/*.cnf overrides (must be the first argument)
# --set-gtid-purged=OFF: prevent FLUSH TABLES WITH READ LOCK and SUPER privilege errors on AWS RDS
DUMP_OPTS=(
    --no-defaults
    --host="${MYSQL_HOST}"
    --port="${MYSQL_PORT:-3306}"
    --user="${MYSQL_USER}"
    --single-transaction
    --skip-lock-tables
    --set-gtid-purged=OFF
    --no-tablespaces
    --quick
    --routines
    --triggers
    "${MYSQL_DATABASE}"
)

export MYSQL_PWD="${MYSQL_PASSWORD}"

if ! mysqldump "${DUMP_OPTS[@]}" | gzip -9 > "${BACKUP_FILE}"; then
    unset MYSQL_PWD
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') - mysqldump pipeline failed!" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi
unset MYSQL_PWD

# 5. Verify gzip archive integrity
if ! gzip -t "${BACKUP_FILE}"; then
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') - Archive integrity check failed!" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[SUCCESS] $(date +'%Y-%m-%d %H:%M:%S') - Backup created successfully: ${BACKUP_FILE} (Size: ${FILE_SIZE})"

# 6. Apply retention policy (delete backups older than 7 days)
find "${BACKUP_DIR}" -type f -name "${MYSQL_DATABASE}_*.sql.gz" -mtime +"${RETENTION_DAYS}" -exec rm -f {} +
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Retention cleanup (> ${RETENTION_DAYS} days) completed."