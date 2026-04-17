from apps.health.models import DailyLog, SymptomEntry, MedicationLog


def get_timeline(user, date):
    daily_log = DailyLog.objects.filter(user=user, date=date).first()

    symptom_entries = SymptomEntry.objects.filter(
        user=user,
        timestamp__date=date
    ).order_by('timestamp')

    medication_logs = MedicationLog.objects.filter(
        user=user,
        taken_at__date=date
    ).order_by('taken_at')

    return daily_log, symptom_entries, medication_logs