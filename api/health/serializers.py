from apps.health.models import DailyLog, Symptom, SymptomEntry
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

class SymptomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Symptom
        fields = ['id', 'name', 'description']

class SymptomEntrySerializer(serializers.ModelSerializer):
    severity = serializers.IntegerField(min_value=1, max_value=10)
    symptom_name = serializers.CharField(source='symptom.name', read_only=True)

    class Meta:
        model = SymptomEntry
        fields = [
            'id', 'symptom', 'symptom_name', 'severity',
            'timestamp', 'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)