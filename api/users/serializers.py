from os import write
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import serializers

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    kvkk_consent = serializers.BooleanField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'first_name', 'last_name', 'password', 'kvkk_consent']

    def validate_kvkk_consent(self, value):
        if not value:
            raise serializers.ValidationError(
                'Kayıt olmak için KVKK aydınlatma metnini onaylamanız gerekir.'
            )
        return value

    def create(self, validated_data):
        validated_data.pop('kvkk_consent')
        user = User.objects.create_user(**validated_data)
        user.kvkk_consent = True
        user.kvkk_consent_at = timezone.now()
        user.save(update_fields=['kvkk_consent', 'kvkk_consent_at'])
        return user

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'created_at', 'profile_photo']

class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['first_name', 'last_name']

class UpdateProfilePhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['profile_photo']

    def validate_profile_photo(self, value):
        max_size = 5 * 1024 * 1024
        if value.size > max_size:
            raise serializers.ValidationError("Dosya boyutu 5MB'ı geçemez.")

        allowed_types = {'image/jpeg', 'image/png', 'image/webp'}
        content_type = getattr(value, 'content_type', None)
        if content_type not in allowed_types:
            raise serializers.ValidationError("Sadece JPEG, PNG veya WEBP formatı desteklenir.")

        from PIL import Image
        try:
            image = Image.open(value)
            image.verify()
        except Exception:
            raise serializers.ValidationError("Geçersiz görsel dosyası.")

        value.seek(0)
        image = Image.open(value)
        max_dimension = 4000
        if image.width > max_dimension or image.height > max_dimension:
            raise serializers.ValidationError(f"Görsel boyutları {max_dimension}x{max_dimension} pikseli aşamaz.")
        value.seek(0)

        return value