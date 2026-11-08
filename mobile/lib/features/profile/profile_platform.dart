// Profil fotoğrafı seçicisi. Platform kısmı ince bir arayüzün arkasında durur;
// ekran testlerinde sahtesiyle değiştirilir.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { gallery, camera }

abstract class ProfilePhotoPicker {
  /// Fotoğraf seçtirir ve küçültülmüş JPEG baytlarını verir. Kullanıcı vazgeçerse
  /// `null` döner. Seçici açılamazsa (ör. kamera yok) istisna fırlatır.
  Future<Uint8List?> pick(PhotoSource source);
}

/// Seçici fotoğrafı sistem tarafında küçültür ve JPEG olarak sıkıştırır; böylece
/// veritabanına giren veri yüzlerce KB'ı geçmez. Geçici kopya okunduktan sonra
/// silinir.
class ImagePickerProfilePhotoPicker implements ProfilePhotoPicker {
  const ImagePickerProfilePhotoPicker();

  /// En uzun kenar (piksel) ve JPEG kalitesi.
  static const maxSide = 512.0;
  static const quality = 80;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    if (picked == null) return null;
    try {
      return await picked.readAsBytes();
    } finally {
      try {
        await File(picked.path).delete();
      } catch (_) {
        // Önbellek kopyası silinemezse akış durmaz.
      }
    }
  }
}

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => const ImagePickerProfilePhotoPicker(),
);
