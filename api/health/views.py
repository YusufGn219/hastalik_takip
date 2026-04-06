from rest_framework.permissions import IsAuthenticated
from api.health.serializers import DailyLogSerializer
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.health.models import DailyLog
from rest_framework import status

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