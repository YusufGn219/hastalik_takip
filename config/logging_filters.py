import logging
import re

# Log mesajı içinde ham geçebilecek yaygın secret formatlarını maskeler
# (JWT'ler, Authorization header değerleri). Bu son bir güvenlik ağıdır —
# asıl kural: request.data / password / token hiçbir yerde logger.*() ile
# loglanmamalı (bkz. views.py'lerdeki convention).
_JWT_PATTERN = re.compile(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+')
_BEARER_PATTERN = re.compile(r'Bearer\s+[A-Za-z0-9_\-.]+', re.IGNORECASE)


class SensitiveDataFilter(logging.Filter):
    def filter(self, record):
        if isinstance(record.msg, str):
            record.msg = _JWT_PATTERN.sub('[REDACTED_TOKEN]', record.msg)
            record.msg = _BEARER_PATTERN.sub('Bearer [REDACTED_TOKEN]', record.msg)
        if record.args:
            record.args = tuple(
                _BEARER_PATTERN.sub('Bearer [REDACTED_TOKEN]', _JWT_PATTERN.sub('[REDACTED_TOKEN]', arg))
                if isinstance(arg, str) else arg
                for arg in record.args
            )
        return True
