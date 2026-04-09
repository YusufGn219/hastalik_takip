from rest_framework.permissions import IsAuthenticated
from api.health.serializers import DailyLogSerializer, SymptomSerializer, SymptomEntrySerializer
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.health.models import DailyLog, Symptom, SymptomEntry
from rest_framework import generics
from rest_framework import status
from datetime import date as date_type
from services.health.timeline import get_timeline
from .serializers import TimelineSerializer
from datetime import datetime

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

        daily_log, symptom_entries = get_timeline(request.user, selected_date)

        serializer = TimelineSerializer({
            'date': selected_date,
            'daily_log': daily_log,
            'symptom_entries': symptom_entries
        })
        
        return Response({
            'success': True,
            'data': serializer.data,
            'message': 'Zaman çizelgesi getirildi'
        }, status=status.HTTP_200_OK)
       
            
