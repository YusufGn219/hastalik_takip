from api.users.serializers import RegisterSerializer, UserSerializer, UpdateProfileSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.permissions import AllowAny
from django.contrib.auth import get_user_model, authenticate
from django.utils.decorators import method_decorator
from django_ratelimit.decorators import ratelimit
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from api.users.serializers import RegisterSerializer, UserSerializer, UpdateProfileSerializer, UpdateProfilePhotoSerializer
from django.core import signing
from django.core.mail import send_mail
from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken



User = get_user_model()

@method_decorator(ratelimit(key='ip', rate='10/h', method='POST', block=True), name='post')
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

@method_decorator(ratelimit(key='ip', rate='20/h', method='POST', block=True), name='post')
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

        user = authenticate(request, email=email, password=password)

        if not user:
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

@method_decorator(ratelimit(key='ip', rate='5/h', method='POST', block=True), name='post')
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


DELETION_TOKEN_SALT = 'account-deletion'
DELETION_TOKEN_MAX_AGE = 60 * 60 * 24  # 24 saat


@method_decorator(ratelimit(key='user', rate='3/d', method='POST', block=True), name='post')
class AccountDeletionRequestView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        token = signing.dumps({'user_id': user.pk}, salt=DELETION_TOKEN_SALT)
        confirm_url = f"{settings.SITE_URL}/api/v1/users/delete-account/confirm/?token={token}"

        send_mail(
            subject='Vitapuls — Hesap Silme Talebiniz',
            message=(
                f"Merhaba {user.first_name},\n\n"
                "Hesabınızı silme talebinizi aldık. Bu talebi onaylamak için "
                f"aşağıdaki bağlantıya tıklayın (24 saat geçerlidir):\n\n{confirm_url}\n\n"
                "Bu talebi siz yapmadıysanız bu e-postayı yok sayabilirsiniz."
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
        )

        return Response({
            'success': True,
            'data': None,
            'message': 'Onay e-postası gönderildi. Silme işlemini tamamlamak için e-postanızı kontrol edin.'
        })


class AccountDeletionConfirmView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        token = request.query_params.get('token', '')
        try:
            payload = signing.loads(token, salt=DELETION_TOKEN_SALT, max_age=DELETION_TOKEN_MAX_AGE)
        except signing.BadSignature:
            return HttpResponse(
                '<p>Bağlantı geçersiz ya da süresi dolmuş. Lütfen silme talebini tekrar oluşturun.</p>',
                status=400,
                content_type='text/html; charset=utf-8',
            )

        try:
            user = User.objects.get(pk=payload['user_id'])
        except User.DoesNotExist:
            return HttpResponse(
                '<p>Kullanıcı bulunamadı.</p>',
                status=404,
                content_type='text/html; charset=utf-8',
            )

        if not user.deletion_requested_at:
            user.is_active = False
            user.deletion_requested_at = timezone.now()
            user.save(update_fields=['is_active', 'deletion_requested_at'])

            for outstanding_token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=outstanding_token)

        return HttpResponse(
            '<p>Hesabınız pasif hale getirildi. Kimliğinizi belirleyen bilgileriniz '
            '30 gün içinde kalıcı olarak anonimleştirilecektir.</p>',
            content_type='text/html; charset=utf-8',
        )