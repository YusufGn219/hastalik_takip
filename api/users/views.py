from api.users.serializers import RegisterSerializer, UserSerializer, UpdateProfileSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.permissions import AllowAny
from django.contrib.auth import get_user_model
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from api.users.serializers import RegisterSerializer, UserSerializer, UpdateProfileSerializer, UpdateProfilePhotoSerializer



User = get_user_model()

class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'success': True,
                'message': 'Kayıt başarılı',
                'data': {
                    'user': UserSerializer(user).data,
                    'tokens': {
                        'access': str(refresh.access_token),
                        'refresh': str(refresh),
                    }
                }
            }, status=status.HTTP_201_CREATED)
        return Response({
            'success': False,
            'message': 'Kayıt başarısız',
            'data': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        if not email or not password:
            return Response({
                'success': False,
                'message': 'Email ve şifre zorunludur',
                'data': {}
            }, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email=email).first()

        if not user or not user.check_password(password):
            return Response({
                'success': False,
                'message': 'Email veya şifre hatalı',
                'data': {}
            }, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(user)
        return Response({
            'success': True,
            'message': 'Giriş başarılı',
            'data': {
                'user': UserSerializer(user).data,
                'tokens': {
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                }
            }
        }, status=status.HTTP_200_OK) 

class MeView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        serializer = self.get_serializer(self.get_object())
        return Response({
            'success': True,
            'data': serializer.data,
            'message': ''
        })

    def patch(self, request, *args, **kwargs):
        user = self.get_object()
        serializer = UpdateProfileSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'data': UserSerializer(user).data,
                'message': 'Profil güncellendi'
            })
        return Response({
            'success': False,
            'data': serializer.errors,
            'message': 'Güncelleme başarısız'
        }, status=status.HTTP_400_BAD_REQUEST)

class ChangePasswordView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')

        if not request.user.check_password(old_password):
            return Response({
                'success': False,
                'data': None,
                'message': 'Mevcut şifre yanlış.'
            }, status=status.HTTP_400_BAD_REQUEST)

        if not new_password or len(new_password) < 8:
            return Response({
                'success': False,
                'data': None,
                'message': 'Yeni şifre en az 8 karakter olmalı.'
            }, status=status.HTTP_400_BAD_REQUEST)

        request.user.set_password(new_password)
        request.user.save()

        return Response({
            'success': True,
            'data': None,
            'message': 'Şifre başarıyla değiştirildi.'
        })

class UpdateProfilePhotoView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        user = request.user
        serializer = UpdateProfilePhotoSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            # Eski fotoğrafı sil
            if user.profile_photo:
                user.profile_photo.delete(save=False)
            serializer.save()
            return Response({
                'success': True,
                'data': UserSerializer(user).data,
                'message': 'Fotoğraf güncellendi'
            })
        return Response({
            'success': False,
            'data': serializer.errors,
            'message': 'Fotoğraf yüklenemedi'
        }, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request):
        user = request.user
        if user.profile_photo:
            user.profile_photo.delete(save=False)
            user.profile_photo = None
            user.save()
        return Response({
            'success': True,
            'data': None,
            'message': 'Fotoğraf silindi'
        })