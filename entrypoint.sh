#!/bin/sh

echo "Veritabanı bağlantısı bekleniyor..."
while ! python manage.py showmigrations > /dev/null 2>&1; do
    sleep 1
done

echo "Migration'lar uygulanıyor..."
python manage.py migrate --noinput

echo "Fixture'lar yükleniyor..."
python manage.py loaddata apps/health/fixtures/initial_symptoms.json 2>/dev/null || echo "Fixture zaten yüklenmiş, atlanıyor."

echo "Sunucu başlatılıyor..."
exec "$@"