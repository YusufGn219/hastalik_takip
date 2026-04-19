# services/health/analytics.py

from django.utils import timezone
from django.db.models import Avg, Count
from datetime import timedelta, datetime

from apps.health.models import (
    SymptomEntry, DailyLog, MedicationLog, Medication
)


def get_symptom_analytics(user, days):
    start_date = timezone.now() - timedelta(days=days)

    # Semptom sıklığı + ortalama şiddet
    symptom_frequency = (
        SymptomEntry.objects
        .filter(user=user, timestamp__gte=start_date)
        .values('symptom__name')
        .annotate(count=Count('id'), avg_severity=Avg('severity'))
        .order_by('-count')
    )

    frequency_list = [
        {
            'symptom_name': item['symptom__name'],
            'count': item['count'],
            'avg_severity': round(item['avg_severity'], 1)
        }
        for item in symptom_frequency
    ]

    # Günlük ortalama severity trendi
    entries = SymptomEntry.objects.filter(user=user, timestamp__gte=start_date)

    daily_severity = {}
    for entry in entries:
        day = entry.timestamp.date().isoformat()
        if day not in daily_severity:
            daily_severity[day] = []
        daily_severity[day].append(entry.severity)

    severity_trend = [
        {
            'date': day,
            'avg_severity': round(sum(vals) / len(vals), 1)
        }
        for day, vals in sorted(daily_severity.items())
    ]

    return {
        'period_days': days,
        'symptom_frequency': frequency_list,
        'severity_trend': severity_trend,
    }


def get_daily_trends(user, days):
    start_date = (timezone.now() - timedelta(days=days)).date()

    logs = DailyLog.objects.filter(user=user, date__gte=start_date).order_by('date')

    trends = [
        {
            'date': log.date.isoformat(),
            'sleep_hours': float(log.sleep_hours) if log.sleep_hours else None,
            'water_intake': float(log.water_intake) if log.water_intake else None,
            'mood': log.mood,
            'energy_level': log.energy_level,
        }
        for log in logs
    ]

    from django.db.models import Avg
    agg = logs.aggregate(
        avg_sleep=Avg('sleep_hours'),
        avg_water=Avg('water_intake'),
        avg_mood=Avg('mood'),
        avg_energy=Avg('energy_level'),
    )

    averages = {
        'sleep_hours': round(agg['avg_sleep'], 1) if agg['avg_sleep'] else None,
        'water_intake': round(agg['avg_water'], 1) if agg['avg_water'] else None,
        'mood': round(agg['avg_mood'], 1) if agg['avg_mood'] else None,
        'energy_level': round(agg['avg_energy'], 1) if agg['avg_energy'] else None,
    }

    return {
        'period_days': days,
        'trends': trends,
        'averages': averages,
    }


def get_medication_effect(user, days):
    start_date = timezone.now() - timedelta(days=days)
    window = timedelta(hours=2)

    med_logs = MedicationLog.objects.filter(
        user=user,
        taken_at__gte=start_date,
        episode__isnull=False  # sadece atağa bağlı ilaç logları
    ).select_related('medication', 'episode')

    effects = {}

    for log in med_logs:
        med_name = log.medication.name
        taken_at = log.taken_at

        # İlaçtan önce (son 2 saat) aynı episodedaki en yüksek severity
        before_entries = SymptomEntry.objects.filter(
            user=user,
            episode=log.episode,
            timestamp__gte=taken_at - window,
            timestamp__lte=taken_at,
        )

        # İlaçtan sonra (sonraki 2 saat)
        after_entries = SymptomEntry.objects.filter(
            user=user,
            episode=log.episode,
            timestamp__gt=taken_at,
            timestamp__lte=taken_at + window,
        )

        if not before_entries.exists() or not after_entries.exists():
            continue

        severity_before = before_entries.aggregate(Avg('severity'))['severity__avg']
        severity_after = after_entries.aggregate(Avg('severity'))['severity__avg']

        # Relief minutes: ilk "düşük" severity kaydına kadar geçen süre
        first_after = after_entries.order_by('timestamp').first()
        relief_minutes = int((first_after.timestamp - taken_at).total_seconds() / 60) if first_after else None

        if med_name not in effects:
            effects[med_name] = {
                'medication_name': med_name,
                'usage_count': 0,
                'severity_before_list': [],
                'severity_after_list': [],
                'relief_minutes_list': [],
            }

        effects[med_name]['usage_count'] += 1
        effects[med_name]['severity_before_list'].append(severity_before)
        effects[med_name]['severity_after_list'].append(severity_after)
        if relief_minutes is not None:
            effects[med_name]['relief_minutes_list'].append(relief_minutes)

    result = []
    for med_name, data in effects.items():
        before_list = data['severity_before_list']
        after_list = data['severity_after_list']
        relief_list = data['relief_minutes_list']
        result.append({
            'medication_name': med_name,
            'usage_count': data['usage_count'],
            'avg_severity_before': round(sum(before_list) / len(before_list), 1),
            'avg_severity_after': round(sum(after_list) / len(after_list), 1),
            'avg_relief_minutes': round(sum(relief_list) / len(relief_list)) if relief_list else None,
        })

    return {
        'period_days': days,
        'effects': result,
    }


def get_medication_adherence(user, days):
    start_date = (timezone.now() - timedelta(days=days)).date()
    today = timezone.now().date()

    recurring_meds = Medication.objects.filter(
        user=user,
        is_recurring=True,
    )

    DAY_MAP = {
        'monday': 0, 'tuesday': 1, 'wednesday': 2,
        'thursday': 3, 'friday': 4, 'saturday': 5, 'sunday': 6,
    }

    adherence = []

    for med in recurring_meds:
        recurring_days = med.recurring_days or []
        allowed_weekdays = [DAY_MAP[d] for d in recurring_days if d in DAY_MAP]

        # Beklenen alım günlerini hesapla
        expected_days = 0
        current = start_date
        while current <= today:
            if not allowed_weekdays or current.weekday() in allowed_weekdays:
                expected_days += 1
            current += timedelta(days=1)

        if expected_days == 0:
            continue

        # Gerçekte alınan farklı günler
        taken_dates = set(
            MedicationLog.objects.filter(
                user=user,
                medication=med,
                taken_at__date__gte=start_date,
                taken_at__date__lte=today,
            ).values_list('taken_at__date', flat=True)
        )
        taken_days = len(taken_dates)
        missed_days = expected_days - taken_days
        adherence_rate = round((taken_days / expected_days) * 100, 1)

        adherence.append({
            'medication_name': med.name,
            'expected_days': expected_days,
            'taken_days': taken_days,
            'missed_days': max(missed_days, 0),
            'adherence_rate': adherence_rate,
        })

    return {
        'period_days': days,
        'adherence': adherence,
    }