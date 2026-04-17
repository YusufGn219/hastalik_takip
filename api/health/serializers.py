from apps.health.models import (
    DailyLog,
    Symptom,
    SymptomEntry,
    Episode,
    EpisodeLocationEntry,
    Medication,
    ChronicCondition,
    MedicationLog
)
from rest_framework import serializers
from services.health.episode import get_duration_minutes


class DailyLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyLog
        fields = [
            'id', 'date', 'sleep_hours', 'water_intake', 'mood',
            'energy_level', 'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_mood(self, value):
        if not 1 <= value <= 5:
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


class EpisodeLocationEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = EpisodeLocationEntry
        fields = ['id', 'location', 'added_at']


class ActiveEpisodeSerializer(serializers.ModelSerializer):
    symptom_name = serializers.CharField(source='symptom.name', read_only=True)
    locations = EpisodeLocationEntrySerializer(source='location_entries', many=True, read_only=True)
    is_active = serializers.SerializerMethodField()

    class Meta:
        model = Episode
        fields = ['id', 'symptom_name', 'start_time', 'locations', 'is_active']

    def get_is_active(self, obj):
        return obj.status == Episode.Status.ONGOING


class SymptomEntrySerializer(serializers.ModelSerializer):
    severity = serializers.IntegerField(min_value=1, max_value=10)
    symptom_name = serializers.CharField(source='symptom.name', read_only=True)
    active_episode = serializers.SerializerMethodField()

    class Meta:
        model = SymptomEntry
        fields = [
            'id', 'symptom', 'symptom_name', 'severity',
            'timestamp', 'notes', 'location', 'episode', 'active_episode',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'episode']

    def get_active_episode(self, obj):
        from services.health.episode import get_active_episode
        episode = get_active_episode(obj.user, obj.symptom)
        if episode:
            return ActiveEpisodeSerializer(episode).data
        return None

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class DailyLogTimelineSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyLog
        fields = ['sleep_hours', 'water_intake', 'mood', 'energy_level', 'notes']


class SymptomEntryTimelineSerializer(serializers.ModelSerializer):
    symptom_name = serializers.CharField(source='symptom.name', read_only=True)

    class Meta:
        model = SymptomEntry
        fields = ['id', 'symptom_name', 'severity', 'timestamp', 'notes']


class MedicationLogTimelineSerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(source='medication.name', read_only=True)

    class Meta:
        model = MedicationLog
        fields = ['id', 'medication_name', 'dose_amount', 'dose_unit', 'taken_at', 'notes']


class TimelineSerializer(serializers.Serializer):
    date = serializers.DateField()
    daily_log = DailyLogTimelineSerializer(allow_null=True)
    symptom_entries = SymptomEntryTimelineSerializer(many=True)
    medication_logs = MedicationLogTimelineSerializer(many=True)


class EpisodeSerializer(serializers.ModelSerializer):
    symptom_name = serializers.CharField(source='symptom.name', read_only=True)
    is_active = serializers.SerializerMethodField()
    duration_minutes = serializers.SerializerMethodField()
    locations = EpisodeLocationEntrySerializer(source='location_entries', many=True, read_only=True)
    entries = serializers.SerializerMethodField()

    class Meta:
        model = Episode
        fields = [
            'id', 'symptom', 'symptom_name', 'start_time', 'ended_at',
            'status', 'is_active', 'duration_minutes', 'resolution_notes',
            'locations', 'entries', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'status', 'created_at', 'updated_at']

    def get_is_active(self, obj):
        return obj.status == Episode.Status.ONGOING

    def get_duration_minutes(self, obj):
        return get_duration_minutes(obj)

    def get_entries(self, obj):
        return SymptomEntryTimelineSerializer(obj.entries.all(), many=True).data


class EpisodeCloseSerializer(serializers.Serializer):
    ended_at = serializers.DateTimeField(required=False)
    resolution_notes = serializers.CharField(required=False, allow_blank=True)


class MedicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medication
        fields = [
            'id', 'name', 'type', 'is_global', 'is_recurring',
            'recurring_time', 'recurring_days', 'created_at'
        ]
        read_only_fields = ['id', 'is_global', 'created_at']


class ChronicConditionSerializer(serializers.ModelSerializer):
    medications = MedicationSerializer(many=True, read_only=True)
    medication_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Medication.objects.all(),
        write_only=True,
        required=False,
        source='medications'
    )

    class Meta:
        model = ChronicCondition
        fields = [
            'id', 'name', 'medications', 'medication_ids',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def create(self, validated_data):
        medications = validated_data.pop('medications', [])
        condition = ChronicCondition.objects.create(**validated_data)
        condition.medications.set(medications)
        return condition

    def update(self, instance, validated_data):
        medications = validated_data.pop('medications', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if medications is not None:
            instance.medications.set(medications)
        return instance


class MedicationLogSerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(source='medication.name', read_only=True)
    episode_id = serializers.PrimaryKeyRelatedField(
        queryset=Episode.objects.all(),
        source='episode',
        required=False,
        allow_null=True
    )
    condition_id = serializers.PrimaryKeyRelatedField(
        queryset=ChronicCondition.objects.all(),
        source='condition',
        required=False,
        allow_null=True
    )

    class Meta:
        model = MedicationLog
        fields = [
            'id', 'medication', 'medication_name', 'taken_at',
            'dose_amount', 'dose_unit', 'episode_id', 'condition_id',
            'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'medication_name', 'created_at', 'updated_at']

    def create(self, validated_data):
        from services.health.medication import create_medication_log
        user = self.context['request'].user
        episode = validated_data.pop('episode', None)
        condition = validated_data.pop('condition', None)
        medication = validated_data.pop('medication')
        taken_at = validated_data.pop('taken_at')
        dose_amount = validated_data.pop('dose_amount', None)
        dose_unit = validated_data.pop('dose_unit', 'tablet')
        notes = validated_data.pop('notes', '')
        try:
            return create_medication_log(
                user=user,
                medication=medication,
                taken_at=taken_at,
                dose_amount=dose_amount,
                dose_unit=dose_unit,
                episode=episode,
                condition=condition,
                notes=notes,
            )
        except ValueError as e:
            raise serializers.ValidationError(str(e))