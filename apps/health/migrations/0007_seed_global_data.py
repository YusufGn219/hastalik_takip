from django.db import migrations


SYMPTOMS = [
    'Baş ağrısı', 'Ateş', 'Öksürük', 'Yorgunluk', 'Bulantı',
    'Karın ağrısı', 'Nefes darlığı', 'Baş dönmesi',
]

MEDICATIONS = [
    ('Parol',      'symptomatic'),
    ('Aspirin',    'symptomatic'),
    ('Majezik',    'symptomatic'),
    ('Nurofen',    'symptomatic'),
    ('Augmentin',  'symptomatic'),
    ('D Vitamini', 'chronic'),
    ('C Vitamini', 'chronic'),
    ('Omega-3',    'chronic'),
    ('Magnezyum',  'chronic'),
    ('B12 Vitamini', 'chronic'),
]


def seed_data(apps, schema_editor):
    Symptom = apps.get_model('health', 'Symptom')
    Medication = apps.get_model('health', 'Medication')

    for name in SYMPTOMS:
        Symptom.objects.get_or_create(name=name, defaults={'description': ''})

    for name, med_type in MEDICATIONS:
        Medication.objects.get_or_create(
            name=name,
            is_global=True,
            defaults={'type': med_type, 'user': None},
        )


def unseed_data(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('health', '0006_alter_medicationlog_dose_unit'),
    ]

    operations = [
        migrations.RunPython(seed_data, unseed_data),
    ]
