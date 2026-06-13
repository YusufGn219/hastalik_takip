# Vitapuls v1.0.0 — Release Notes

**Tarih:** 2026-06-14

## Genel Bakış

Vitapuls'un ilk production sürümü. Kişisel sağlık takibi ve semptom analizi için Django REST API + Flutter mobil uygulama.

## Özellikler

- Kullanıcı kaydı, girişi ve profil yönetimi (fotoğraf dahil)
- Semptom günlüğü ve episode takibi
- İlaç ve kronik hastalık kaydı
- Semptom analitikleri ve zaman çizelgesi
- JWT tabanlı güvenli kimlik doğrulama
- Flutter ile Android ve iOS desteği

## Teknik

- Django 5.2.15 + Django REST Framework 3.17.1
- PostgreSQL 16
- Gunicorn + Nginx (Docker Compose)
- Flutter 3.x / Dart 3.x
- Bildirim desteği (flutter_local_notifications)

## Bilinen Kısıtlamalar

- Web paneli henüz mevcut değil (mobil only)
- iOS App Store yayını bir sonraki sürümde planlanmaktadır
