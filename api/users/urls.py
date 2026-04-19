from api.users.views import RegisterView, LoginView, MeView, ChangePasswordView, UpdateProfilePhotoView
from django.urls import path

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('me/', MeView.as_view(), name='me'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('profile-photo/', UpdateProfilePhotoView.as_view(), name='profile-photo'),
]