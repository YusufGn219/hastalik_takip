from apps.health.models import Medication,  ChronicCondition, MedicationLog, Episode

def get_medications(user):
    return Medication.objects.filter(
        is_global=True
    ) | Medication.objects.filter(
        user=user,
        is_global=False
    )

def create_medication (user, name, med_type, is_recurring=False, recurring_time=None, recurring_days=None):
    return Medication.objects.create(
        user=user,
        name=name,
        type=med_type,
        is_global=False,
        is_recurring=is_recurring,
        recurring_time=recurring_time,
        recurring_days=recurring_days
    )
    
def create_medication_log(user, medication, taken_at, dose_amount=None, dose_unit='tablet', episode=None, condition=None, notes=''):
    if episode and condition:
        raise ValueError('episode ve condition aynı anda doldurulamaz.')

    if episode and episode.user != user:
        raise ValueError('Bu atağa erişim yetkiniz yok.')

    if condition and condition.user != user:
        raise ValueError('Bu kronik hastalığa erişim yetkiniz yok.')

    return MedicationLog.objects.create(
        user=user,
        medication=medication,
        taken_at=taken_at,
        dose_amount=dose_amount,
        dose_unit=dose_unit,
        episode=episode,
        condition=condition,
        notes=notes,
    )

def get_medication_logs_for_date(user, date):
    return MedicationLog.objects.filter(
        user=user,
        taken_at__date=date
    ).order_by('taken_at')