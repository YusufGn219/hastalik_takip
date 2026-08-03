from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0003_user_profile_photo'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='kvkk_consent',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='user',
            name='kvkk_consent_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='deletion_requested_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='is_anonymized',
            field=models.BooleanField(default=False),
        ),
    ]
