#!/bin/bash
# Günlük Postgres yedeği: pg_dump + gzip + (opsiyonel) uzak depolamaya kopyalama.
#
# Kurulum (sunucu hazır olduğunda):
#   1. .env.prod'a RCLONE_REMOTE değişkenini ekle (örn. "b2:hastalik-takip-backups")
#      ve rclone'u remote için configure et (`rclone config`).
#   2. Host'ta cron'a ekle:
#        0 3 * * * /path/to/scripts/backup_db.sh >> /var/log/hastalik_backup.log 2>&1
#   3. Uzak depolamada retention/lifecycle kuralını (örn. 30 gün) sağlayıcı
#      panelinden ayarla — bu script sadece local retention'ı yönetir.
#
# RCLONE_REMOTE boşsa script sadece local yedek alır, uzak depolamaya kopyalamaz.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups}"
DB_CONTAINER="${DB_CONTAINER:-hastalik_takip_db_prod}"
LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/hastalik_takip_${TIMESTAMP}.sql.gz"

if [ -z "${DB_NAME:-}" ] || [ -z "${DB_USER:-}" ]; then
    echo "HATA: DB_NAME ve DB_USER env değişkenleri tanımlı olmalı (.env.prod'dan yüklenmeli)." >&2
    exit 1
fi

mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Yedek alınıyor: ${BACKUP_FILE}"
docker exec "${DB_CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"

if [ ! -s "${BACKUP_FILE}" ]; then
    echo "HATA: Yedek dosyası boş oluştu, bir şeyler ters gitti." >&2
    exit 1
fi
echo "[$(date)] Yedek tamamlandı: $(du -h "${BACKUP_FILE}" | cut -f1)"

if [ -n "${RCLONE_REMOTE:-}" ]; then
    echo "[$(date)] Uzak depolamaya kopyalanıyor: ${RCLONE_REMOTE}"
    rclone copy "${BACKUP_FILE}" "${RCLONE_REMOTE}/"
else
    echo "[$(date)] RCLONE_REMOTE tanımlı değil, sadece local yedek alındı."
fi

echo "[$(date)] ${LOCAL_RETENTION_DAYS} günden eski local yedekler siliniyor..."
find "${BACKUP_DIR}" -name "hastalik_takip_*.sql.gz" -mtime "+${LOCAL_RETENTION_DAYS}" -delete

echo "[$(date)] Backup işlemi bitti."
