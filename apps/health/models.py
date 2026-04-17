from django.conf import settings
from django.db import models


class DailyLog(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_logs'
    )
    date = models.DateField()
    sleep_hours = models.DecimalField(max_digits=4, decimal_places=1)
    water_intake = models.DecimalField(max_digits=4, decimal_places=1)
    mood = models.IntegerField()
    energy_level = models.IntegerField()
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'daily_logs'
        unique_together = ['user', 'date']
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.email} - {self.date}"


class Symptom(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Episode(models.Model):
    class Status(models.TextChoices):
        ONGOING = "ongoing", "Devam Ediyor"
        RESOLVED = "resolved", "Tamamlandı"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='episodes'
    )
    symptom = models.ForeignKey(
        Symptom,
        on_delete=models.CASCADE,
        related_name='episodes'
    )
    start_time = models.DateTimeField()
    ended_at = models.DateTimeField(blank=True, null=True)
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.ONGOING
    )
    resolution_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_time']


class SymptomEntry(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='symptom_entries'
    )
    symptom = models.ForeignKey(
        Symptom,
        on_delete=models.CASCADE,
        related_name='entries'
    )
    episode = models.ForeignKey(
        Episode,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='entries'
    )
    severity = models.IntegerField()
    timestamp = models.DateTimeField()
    notes = models.TextField(blank=True)
    location = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.user.email} - {self.symptom.name} at {self.timestamp}"


class EpisodeLocationEntry(models.Model):
    episode = models.ForeignKey(
        Episode,
        on_delete=models.CASCADE,
        related_name='location_entries'
    )
    location = models.CharField(max_length=100)
    added_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['added_at']

class Medication(models.Model):
    class Type(models.TextChoices):
        CHRONIC = "chronic", "Kronik"
        SYMPTOMATIC = "symptomatic", "Semptomatik"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='medications'
    )
    name = models.CharField(max_length=100)
    type = models.CharField(max_length=20, choices=Type.choices, default=Type.SYMPTOMATIC)
    is_global = models.BooleanField(default=False)
    is_recurring = models.BooleanField(default=False)
    recurring_time = models.TimeField(blank=True, null=True)
    recurring_days = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
    
    def __str__(self):
        return self.name

class ChronicCondition(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='chronic_conditions'
    )
    name = models.CharField(max_length=200)
    medications = models.ManyToManyField(
        Medication,
        blank = True,
        related_name = 'conditions'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

class MedicationLog(models.Model):
    class DoseUnit(models.TextChoices):
        MG = "mg", "mg"
        ML = "ml", "ml"
        DROP = "drop", "damla"
        CAPSULE = "capsule", "kapsül"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='medication_logs'
    )
    medication = models.ForeignKey(
        Medication,
        on_delete=models.CASCADE,
        related_name='logs'
    )
    taken_at = models.DateTimeField()
    dose_amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        blank=True,
        null=True
    )
    dose_unit = models.CharField(
        max_length=10,
        choices=DoseUnit.choices,
        default="Tablet"
    )
    episode = models.ForeignKey(
        Episode,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='medication_logs'
    )
    condition = models.ForeignKey(
        ChronicCondition,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='medication_logs'
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-taken_at']

    def __str__(self):
        return f"{self.user} - {self.medication.name} - {self.taken_at}"

