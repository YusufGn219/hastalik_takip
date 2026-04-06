from apps.health.models import DailyLog
from rest_framework import serializers

class DailyLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyLog
        fields = [
            'id', 'date', 'sleep_hours', 'water_intake', 'mood', 'energy_level', 'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_mood(self, value):
        if not 1<= value <= 5:
            raise serializers.ValidationError("Mood 1 ila 5 arasında olmalıdır.")
        return value

    def validate_energy_level(self, value):
        if not 1 <= value <= 5:
            raise serializers.ValidationError("Energy level 1 ila 5 arasında olmalıdır.")
        return value
    
    def validate_sleep_hours(self, value):
        if value < 0 or value > 24:
            raise serializers.ValidationError("Uyku süresi 0 ile 24 saat arasında olmalıdır.")
        return value

    def validate_water_intake(self, value):
        if value < 0:
            raise serializers.ValidationError("Su tüketimi negatif olamaz.")
        return value