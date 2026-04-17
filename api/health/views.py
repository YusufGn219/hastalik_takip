from rest_framework.permissions import IsAuthenticated
from api.health.serializers import (
    DailyLogSerializer,
    SymptomSerializer,
    SymptomEntrySerializer,
    EpisodeSerializer,
    EpisodeCloseSerializer,
    ActiveEpisodeSerializer,
    MedicationLogSerializer,
    MedicationSerializer,
    ChronicConditionSerializer
)
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.health.models import DailyLog, Symptom, SymptomEntry, Episode
from rest_framework import generics
from rest_framework import status
from datetime import date as date_type
from services.health.timeline import get_timeline
from services.health.episode import (
    get_active_episode,
    start_episode,
    add_to_episode,
    close_episode
)
from .serializers import TimelineSerializer
from datetime import datetime
from apps.health.models import (
    Medication,
    ChronicCondition,
    MedicationLog
)


class DailyLogListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        logs = DailyLog.objects.filter(user=request.user)
        serializer = DailyLogSerializer(logs, many=True)
        return Response({
            'success': True,
            'message': 'Kayıtlar getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = DailyLogSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response({
                'success': True,
                'message': 'Kayıt oluşturuldu',
                'data': serializer.data
            }, status=status.HTTP_201_CREATED)
        return Response({
            'success': False,
            'message': 'Kayıt oluşturulamadı',
            'data': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class DailyLogDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return DailyLog.objects.get(pk=pk, user=user)
        except DailyLog.DoesNotExist:
            return None

    def get(self, request, pk):
        log = self.get_object(pk, request.user)
        if not log:
            return Response({
                'success': False,
                'message': 'Kayıt bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)
        serializer = DailyLogSerializer(log)
        return Response({
            'success': True,
            'message': 'Kayıt getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        log = self.get_object(pk, request.user)
        if not log:
            return Response({
                'success': False,
                'message': 'Kayıt bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)
        serializer = DailyLogSerializer(log, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Kayıt güncellendi',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        return Response({
            'success': False,
            'message': 'Kayıt güncellenemedi',
            'data': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        log = self.get_object(pk, request.user)
        if not log:
            return Response({
                'success': False,
                'message': 'Kayıt bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)
        log.delete()
        return Response({
            'success': True,
            'message': 'Kayıt silindi',
            'data': {}
        }, status=status.HTTP_204_NO_CONTENT)


class SymptomListView(generics.ListCreateAPIView):
    serializer_class = SymptomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Symptom.objects.all()


class SymptomDetailView(generics.RetrieveAPIView):
    serializer_class = SymptomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Symptom.objects.all()


class SymptomEntryListCreateView(generics.ListCreateAPIView):
    serializer_class = SymptomEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SymptomEntry.objects.filter(user=self.request.user)


class SymptomEntryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SymptomEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SymptomEntry.objects.filter(user=self.request.user)


class TimelineView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        date_str = request.query_params.get('date')

        if date_str:
            try:
                selected_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response({
                    'success': False,
                    'data': None,
                    'message': 'Geçersiz tarih formatı. YYYY-MM-DD formatında olmalıdır.'
                }, status=status.HTTP_400_BAD_REQUEST)
        else:
            selected_date = date_type.today()

        daily_log, symptom_entries, medication_logs = get_timeline(request.user, selected_date)
        serializer = TimelineSerializer({
            'date': selected_date,
            'daily_log': daily_log,
            'symptom_entries': symptom_entries,
            'medication_logs': medication_logs
        })

        return Response({
            'success': True,
            'data': serializer.data,
            'message': 'Zaman çizelgesi getirildi'
        }, status=status.HTTP_200_OK)


class EpisodeListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        episodes = Episode.objects.filter(user=request.user)
        serializer = EpisodeSerializer(episodes, many=True)
        return Response({
            'success': True,
            'message': 'Episodlar getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)

    def post(self, request):
        symptom_entry_id = request.data.get('symptom_entry_id')
        action = request.data.get('action')

        if not symptom_entry_id or not action:
            return Response({
                'success': False,
                'message': 'symptom_entry_id ve action zorunludur.',
                'data': {}
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            symptom_entry = SymptomEntry.objects.get(
                pk=symptom_entry_id,
                user=request.user
            )
        except SymptomEntry.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Semptom kaydı bulunamadı.',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)

        if action == 'start':
            existing = get_active_episode(request.user, symptom_entry.symptom)
            if existing:
                return Response({
                    'success': False,
                    'message': 'Bu semptom için zaten aktif bir atak var.',
                    'data': ActiveEpisodeSerializer(existing).data
                }, status=status.HTTP_400_BAD_REQUEST)

            episode = start_episode(request.user, symptom_entry)
            return Response({
                'success': True,
                'message': 'Atak başlatıldı.',
                'data': EpisodeSerializer(episode).data
            }, status=status.HTTP_201_CREATED)

        elif action == 'add':
            episode_id = request.data.get('episode_id')
            is_new_location = request.data.get('is_new_location', False)

            if not episode_id:
                return Response({
                    'success': False,
                    'message': 'episode_id zorunludur.',
                    'data': {}
                }, status=status.HTTP_400_BAD_REQUEST)

            try:
                episode = Episode.objects.get(pk=episode_id, user=request.user)
            except Episode.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'Atak bulunamadı.',
                    'data': {}
                }, status=status.HTTP_404_NOT_FOUND)

            add_to_episode(episode, symptom_entry, is_new_location=is_new_location)
            return Response({
                'success': True,
                'message': 'Kayıt atağa eklendi.',
                'data': EpisodeSerializer(episode).data
            }, status=status.HTTP_200_OK)

        return Response({
            'success': False,
            'message': 'Geçersiz action. "start" veya "add" olmalıdır.',
            'data': {}
        }, status=status.HTTP_400_BAD_REQUEST)


class EpisodeActiveView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        episodes = Episode.objects.filter(
            user=request.user,
            status=Episode.Status.ONGOING
        )
        serializer = EpisodeSerializer(episodes, many=True)
        return Response({
            'success': True,
            'message': 'Aktif ataklar getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


class EpisodeHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        episodes = Episode.objects.filter(
            user=request.user,
            status=Episode.Status.RESOLVED
        )
        serializer = EpisodeSerializer(episodes, many=True)
        return Response({
            'success': True,
            'message': 'Geçmiş ataklar getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


class EpisodeDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return Episode.objects.get(pk=pk, user=user)
        except Episode.DoesNotExist:
            return None

    def get(self, request, pk):
        episode = self.get_object(pk, request.user)
        if not episode:
            return Response({
                'success': False,
                'message': 'Atak bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)
        serializer = EpisodeSerializer(episode)
        return Response({
            'success': True,
            'message': 'Atak getirildi',
            'data': serializer.data
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        episode = self.get_object(pk, request.user)
        if not episode:
            return Response({
                'success': False,
                'message': 'Atak bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)
        episode.delete()
        return Response({
            'success': True,
            'message': 'Atak silindi',
            'data': {}
        }, status=status.HTTP_204_NO_CONTENT)


class EpisodeCloseView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            episode = Episode.objects.get(pk=pk, user=request.user)
        except Episode.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Atak bulunamadı',
                'data': {}
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = EpisodeCloseSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Geçersiz veri',
                'data': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            closed = close_episode(
                episode,
                ended_at=serializer.validated_data.get('ended_at'),
                resolution_notes=serializer.validated_data.get('resolution_notes', '')
            )
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e),
                'data': {}
            }, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            'success': True,
            'message': 'Atak kapatıldı',
            'data': EpisodeSerializer(closed).data
        }, status=status.HTTP_200_OK)

class MedicationListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicationSerializer

    def get_queryset(self):
        from services.health.medication import get_medications
        return get_medications(self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user, is_global=False)


class MedicationDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicationSerializer

    def get_queryset(self):
        from services.health.medication import get_medications
        return get_medications(self.request.user)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.is_global:
            return Response(
                {'success': False, 'data': None, 'message': 'Global ilaçlar güncellenemez.'},
                status=status.HTTP_403_FORBIDDEN
            )
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.is_global:
            return Response(
                {'success': False, 'data': None, 'message': 'Global ilaçlar silinemez.'},
                status=status.HTTP_403_FORBIDDEN
            )
        return super().destroy(request, *args, **kwargs)


class ChronicConditionListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ChronicConditionSerializer

    def get_queryset(self):
        return ChronicCondition.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ChronicConditionDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ChronicConditionSerializer

    def get_queryset(self):
        return ChronicCondition.objects.filter(user=self.request.user)


class MedicationLogListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicationLogSerializer

    def get_queryset(self):
        return MedicationLog.objects.filter(user=self.request.user)


class MedicationLogDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicationLogSerializer

    def get_queryset(self):
        return MedicationLog.objects.filter(user=self.request.user)