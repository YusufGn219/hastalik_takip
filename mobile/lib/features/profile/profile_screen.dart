// Profil ekranı: ad, soyad, doğum tarihi, cinsiyet ve fotoğraf. Hepsi isteğe
// bağlıdır; veri yalnızca bu telefondaki şifreli veritabanında durur. Fotoğraf
// ve alanlar "Kaydet"e basılınca yazılır.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/support.dart';
import '../../l10n/l10n.dart';
import 'profile_avatar.dart';
import 'profile_platform.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();

  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;

  String? _birth;
  String? _gender;
  Uint8List? _photo;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final p = await ref.read(profileRepositoryProvider).get();
      if (!mounted) return;
      setState(() {
        _first.text = p.firstName;
        _last.text = p.lastName;
        _birth = p.birthDate;
        _gender = p.gender;
        _photo = p.photo;
        _photoChanged = false;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Profil okunamadı: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  // ---------------------------------------------------------------- fotoğraf

  Future<void> _photoSheet() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('profil_foto_galeri'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePhotoGallery),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.gallery),
            ),
            ListTile(
              key: const Key('profil_foto_kamera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profilePhotoCamera),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.camera),
            ),
            if (_photo != null)
              ListTile(
                key: const Key('profil_foto_kaldir'),
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.profilePhotoRemove),
                onTap: () => Navigator.pop(ctx, _PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _PhotoChoice.remove) {
      setState(() {
        _photo = null;
        _photoChanged = true;
        _error = null;
      });
      return;
    }
    try {
      final bytes = await ref.read(profilePhotoPickerProvider).pick(
            choice == _PhotoChoice.camera ? PhotoSource.camera : PhotoSource.gallery,
          );
      if (bytes == null || !mounted) return;
      setState(() {
        _photo = bytes;
        _photoChanged = true;
        _error = null;
      });
    } catch (e) {
      debugPrint('Fotoğraf alınamadı: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _error = context.l10n.profilePhotoFailed);
    }
  }

  // ------------------------------------------------------------ doğum tarihi

  DateTime? _parseBirth() {
    final b = _birth;
    if (b == null) return null;
    final parts = b.split('-');
    if (parts.length != 3) return null;
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Future<void> _pickBirth() async {
    final now = ref.read(clockProvider)();
    final initial = _parseBirth() ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(minBirthYear),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birth = dayKey(picked);
      _error = null;
    });
  }

  // ------------------------------------------------------------------ kaydet

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).save(
            ProfilesCompanion(
              firstName: Value(_first.text),
              lastName: Value(_last.text),
              birthDate: Value(_birth),
              gender: Value(_gender),
              // Fotoğrafa yalnız değiştiyse dokunulur.
              photo: _photoChanged ? Value(_photo) : const Value.absent(),
            ),
          );
    } catch (e) {
      debugPrint('Profil kaydedilemedi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.profileSaveFailed;
      });
      return;
    }
    ref.invalidate(profileProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    if (mounted) navigator.pop();
  }

  // ------------------------------------------------------------------- görünüm

  String _genderLabel(String? gender) {
    final l10n = context.l10n;
    return switch (gender) {
      Genders.female => l10n.profileGenderFemale,
      Genders.male => l10n.profileGenderMale,
      Genders.other => l10n.profileGenderOther,
      _ => l10n.profileGenderNone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadFailed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.profileLoadFailed, key: const Key('profil_okunamadi')),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('profil_tekrar'),
                onPressed: _load,
                child: Text(l10n.profileRetry),
              ),
            ],
          ),
        ),
      );
    } else {
      final birth = _parseBirth();
      final locale = Localizations.localeOf(context).toString();
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.profileIntro, style: text.bodyMedium),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                InkWell(
                  key: const Key('profil_foto'),
                  customBorder: const CircleBorder(),
                  onTap: _saving ? null : _photoSheet,
                  child: ProfileAvatar(photo: _photo, radius: 52),
                ),
                TextButton(
                  key: const Key('profil_foto_degistir'),
                  onPressed: _saving ? null : _photoSheet,
                  child: Text(_photo == null ? l10n.profilePhotoAdd : l10n.profilePhotoChange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('profil_ad'),
            controller: _first,
            enabled: !_saving,
            maxLength: maxProfileNameLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.profileFirstName, counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profil_soyad'),
            controller: _last,
            enabled: !_saving,
            maxLength: maxProfileNameLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.profileLastName, counterText: ''),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('profil_dogum'),
            onTap: _saving ? null : _pickBirth,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.profileBirthDate,
                suffixIcon: birth == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(
                        key: const Key('profil_dogum_temizle'),
                        tooltip: l10n.profileBirthDateClear,
                        icon: const Icon(Icons.clear),
                        onPressed: _saving ? null : () => setState(() => _birth = null),
                      ),
              ),
              child: Text(
                birth == null ? l10n.profileBirthDateNone : DateFormat('d MMMM y', locale).format(birth),
                key: const Key('profil_dogum_deger'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('profil_cinsiyet'),
            initialValue: _gender,
            decoration: InputDecoration(labelText: l10n.profileGender),
            items: [
              for (final g in <String?>[null, ...Genders.all])
                DropdownMenuItem<String?>(value: g, child: Text(_genderLabel(g))),
            ],
            onChanged: _saving ? null : (g) => setState(() => _gender = g),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, key: const Key('profil_hata'), style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('profil_kaydet'),
            onPressed: _saving ? null : _save,
            child: Text(l10n.profileSave),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(child: body),
    );
  }
}

enum _PhotoChoice { gallery, camera, remove }
