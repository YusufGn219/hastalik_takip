from apps.health.models import DailyLog, SymptomEntry

def get_timeline(user, date):
    daily_log = DailyLog.objects.filter(user=user, date=date).first()
    symptom_entries = SymptomEntry.objects.filter(
        user=user,
        timestamp__date=date
    ).order_by('timestamp')

    return daily_log, symptom_entries