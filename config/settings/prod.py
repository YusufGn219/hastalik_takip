from .base import *
import os
from django.core.exceptions import ImproperlyConfigured

DEBUG = False

ALLOWED_HOSTS = [h.strip() for h in os.getenv('ALLOWED_HOSTS', '').split(',') if h.strip()]
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured(
        "ALLOWED_HOSTS env değişkeni production'da boş olamaz — sunucu domain/IP'sini virgülle ayırarak girin."
    )

# HTTPS güvenlik başlıkları
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# CORS — production'da sadece kendi origin'e izin ver
CORS_ALLOWED_ORIGINS = [
    o.strip() for o in os.getenv('CORS_ALLOWED_ORIGINS', '').split(',') if o.strip()
]

# Sentry — hata izleme (SENTRY_DSN env'e eklenince aktif olur)
SENTRY_DSN = os.getenv('SENTRY_DSN', '')


def _sentry_scrub_sensitive_data(event, hint):
    """Authorization/Cookie header'larını ve request body'sini Sentry'ye
    göndermeden önce temizler — sağlık verisi (semptom/ilaç bilgisi) request
    body'sinde taşınabildiği için tamamı filtrelenir."""
    request = event.get('request')
    if request:
        headers = request.get('headers')
        if headers:
            for key in list(headers.keys()):
                if key.lower() in ('authorization', 'cookie'):
                    headers[key] = '[Filtered]'
        if 'data' in request:
            request['data'] = '[Filtered]'
        if 'cookies' in request:
            request['cookies'] = '[Filtered]'
    return event


if SENTRY_DSN:
    import sentry_sdk
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        traces_sample_rate=0.2,
        profiles_sample_rate=0.1,
        send_default_pii=False,
        environment=os.getenv('SENTRY_ENVIRONMENT', 'production'),
        release=f"vitapuls@{os.getenv('APP_VERSION', '1.0.0')}",
        before_send=_sentry_scrub_sensitive_data,
    )