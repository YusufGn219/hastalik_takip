import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Yuvarlak profil resmi; fotoğraf yoksa kişi simgesi gösterir.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.photo, this.radius = 28});

  final Uint8List? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = photo;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      child: Icon(Icons.person_outline, size: radius, color: scheme.onPrimaryContainer),
    );
  }
}
