BACKUP_DIR="/var/backups/mysql"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Starting mysqldump for database '${MYSQL_DATABASE}'..."

# Pass password via MYSQL_PWD environment variable to hide it from process table (ps aux)
export MYSQL_PWD="${MYSQL_PASSWORD}"
mysqldump \
    --host="${MYSQL_HOST}" \
    --port="${MYSQL_PORT:-3306}" \
    --user="${MYSQL_USER}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    "${MYSQL_DATABASE}" | gzip -9 > "${BACKUP_FILE}"
unset MYSQL_PWD

# Verify archive integrity
if gzip -t "${BACKUP_FILE}"; then
    FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "[SUCCESS] $(date +'%Y-%m-%d %H:%M:%S') - Backup created successfully: ${BACKUP_FILE} (${FILE_SIZE})"
else
    echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') - Backup archive integrity check failed!" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# Apply retention policy (remove backups older than 7 days)
find "${BACKUP_DIR}" -type f -name "${MYSQL_DATABASE}_*.sql.gz" -mtime +"${RETENTION_DAYS}" -exec rm -f {} +
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - Retention cleanup (> ${RETENTION_DAYS} days) completed."