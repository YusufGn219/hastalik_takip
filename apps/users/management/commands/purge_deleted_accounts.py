from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

User = get_user_model()

GRACE_PERIOD_DAYS = 30


class Command(BaseCommand):
    help = (
        "Silme talebi e-posta ile onaylanıp 30 gün bekleme süresini dolduran "
        "hesapların kimliğini belirleyen bilgilerini (e-posta, ad, profil "
        "fotoğrafı) kalıcı olarak anonimleştirir. Sağlık kayıtları (semptom, "
        "episode, ilaç vb.) silinmez; aynı (artık anonim) kullanıcı ID'sine "
        "bağlı kalarak gruplanabilir kalır — ML/araştırma amaçlı kullanım için."
    )

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(days=GRACE_PERIOD_DAYS)
        candidates = User.objects.filter(
            deletion_requested_at__isnull=False,
            deletion_requested_at__lte=cutoff,
            is_anonymized=False,
        )

        count = 0
        for user in candidates:
            if user.profile_photo:
                user.profile_photo.delete(save=False)

            user.email = f'silinmis-kullanici-{user.pk}@anonim.vitapuls'
            user.first_name = ''
            user.last_name = ''
            user.profile_photo = None
            user.is_anonymized = True
            user.set_unusable_password()
            user.save(update_fields=[
                'email', 'first_name', 'last_name', 'profile_photo',
                'is_anonymized', 'password',
            ])
            count += 1

        self.stdout.write(self.style.SUCCESS(f'{count} hesap anonimleştirildi.'))
