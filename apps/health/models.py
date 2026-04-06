from django.conf import settings
from django.db import models

class DailyLog(models.Model):
    user= models.ForeignKey(
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