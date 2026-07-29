#!/bin/bash
# Postgres yedeğini geri yükler. BİLİNÇLİ OLARAK MANUEL ÇALIŞTIRILIR —
# otomatik/cron'a bağlanmaz, çünkü yanlış yedeği geri yüklemek veri kaybına
# yol açabilir. Kullanmadan önce mevcut veritabanının bir yedeğini alın.
#
# Kullanım:
#   ./scripts/restore_db.sh /backups/hastalik_takip_20260101_030000.sql.gz
#
# Not: Bu işlem hedef veritabanındaki mevcut veriyi geri yüklenen veriyle
# değiştirmez, üzerine ekler — temiz bir restore için önce veritabanını
# boşaltmanız (drop/create) gerekebilir. Restore'u önce bir test/staging
# ortamında deneyin.

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-hastalik_takip_db_prod}"
BACKUP_FILE="${1:-}"

if [ -z "${BACKUP_FILE}" ]; then
    echo "Kullanım: $0 <yedek_dosyasi.sql.gz>" >&2
    exit 1
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "HATA: Dosya bulunamadı: ${BACKUP_FILE}" >&2
    exit 1
fi

if [ -z "${DB_NAME:-}" ] || [ -z "${DB_USER:-}" ]; then
    echo "HATA: DB_NAME ve DB_USER env değişkenleri tanımlı olmalı (.env.prod'dan yüklenmeli)." >&2
    exit 1
fi

echo "UYARI: Bu işlem '${DB_NAME}' veritabanına '${BACKUP_FILE}' içeriğini geri yükleyecek."
read -r -p "Devam etmek istediğinize emin misiniz? (evet yazın): " CONFIRM
if [ "${CONFIRM}" != "evet" ]; then
    echo "İptal edildi."
    exit 0
fi

echo "[$(date)] Geri yükleme başlıyor..."
gunzip -c "${BACKUP_FILE}" | docker exec -i "${DB_CONTAINER}" psql -U "${DB_USER}" "${DB_NAME}"
echo "[$(date)] Geri yükleme tamamlandı."
