import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/features/profile/profile_platform.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../support/fake_profile_repository.dart';

/// Geçerli 1x1 PNG (resim çözücü hata vermesin).
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _FakePicker implements ProfilePhotoPicker {
  _FakePicker({this.result, this.error});

  Uint8List? result;
  Object? error;
  final sources = <PhotoSource>[];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return result;
  }
}

/// Ekran bir ana ekranın üstüne açılır; kaydedince geri dönüş ve bildirim görülür.
Future<void> _open(
  WidgetTester tester,
  FakeProfileRepository repo, {
  _FakePicker? picker,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profilePhotoPickerProvider.overrideWithValue(picker ?? _FakePicker()),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 8, 12)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  testWidgets('boş profil: alanlar boş, tarih seçilmedi, fotoğraf ekle görünür', (tester) async {
    await _open(tester, FakeProfileRepository());
    expect(_text(tester, 'profil_ad'), '');
    expect(_text(tester, 'profil_soyad'), '');
    expect(find.text('Seçilmedi'), findsOneWidget);
    expect(find.text('Fotoğraf ekle'), findsOneWidget);
    expect(find.byKey(const Key('profil_dogum_temizle')), findsNothing);
  });

  testWidgets('kayıtlı profil alanlara yüklenir', (tester) async {
    final repo = FakeProfileRepository();
    repo.current = repo.current.copyWith(
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    await _open(tester, repo);
    expect(_text(tester, 'profil_ad'), 'Ada');
    expect(_text(tester, 'profil_soyad'), 'Lovelace');
  });

  testWidgets('kaydet: alanlar yazılır, ekran kapanır, bildirim görünür', (tester) async {
    final repo = FakeProfileRepository();
    await _open(tester, repo);
    await tester.enterText(find.byKey(const Key('profil_ad')), 'Ada');
    await tester.enterText(find.byKey(const Key('profil_soyad')), 'Lovelace');
    await tester.tap(find.byKey(const Key('profil_cinsiyet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kadın').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'profil_kaydet');

    expect(repo.saves, hasLength(1));
    final s = repo.saves.single;
    expect(s.firstName.value, 'Ada');
    expect(s.lastName.value, 'Lovelace');
    expect(s.gender.value, Genders.female);
    expect(s.birthDate.value, isNull);
    expect(s.photo.present, isFalse, reason: 'fotoğraf değişmediyse dokunulmaz');
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Profil kaydedildi'), findsOneWidget);
  });

  testWidgets('doğum tarihi seçilir, kaydedilir; temizle ile boşalır', (tester) async {
    final repo = FakeProfileRepository();
    await _open(tester, repo);
    await _tap(tester, 'profil_dogum');
    // Varsayılan başlangıç: bugünden 30 yıl önce (8 Kasım 1996).
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('15 Kasım 1996'), findsOneWidget);

    await _tap(tester, 'profil_dogum_temizle');
    expect(find.text('Seçilmedi'), findsOneWidget);

    await _tap(tester, 'profil_dogum');
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    await _tap(tester, 'profil_kaydet');
    expect(repo.saves.single.birthDate.value, '1996-11-15');
  });

  testWidgets('galeriden fotoğraf seçilir ve kaydedilir', (tester) async {
    final repo = FakeProfileRepository();
    final picker = _FakePicker(result: _png);
    await _open(tester, repo, picker: picker);
    await _tap(tester, 'profil_foto_degistir');
    await tester.tap(find.byKey(const Key('profil_foto_galeri')));
    await tester.pumpAndSettle();
    expect(picker.sources, [PhotoSource.gallery]);
    expect(find.text('Fotoğrafı değiştir'), findsOneWidget);

    await _tap(tester, 'profil_kaydet');
    expect(repo.saves.single.photo.value, _png);
  });

  testWidgets('kamera seçilince kamera kaynağı istenir', (tester) async {
    final picker = _FakePicker(result: _png);
    await _open(tester, FakeProfileRepository(), picker: picker);
    await _tap(tester, 'profil_foto');
    await tester.tap(find.byKey(const Key('profil_foto_kamera')));
    await tester.pumpAndSettle();
    expect(picker.sources, [PhotoSource.camera]);
  });

  testWidgets('seçici vazgeçilirse hiçbir şey değişmez', (tester) async {
    final repo = FakeProfileRepository();
    await _open(tester, repo, picker: _FakePicker());
    await _tap(tester, 'profil_foto_degistir');
    await tester.tap(find.byKey(const Key('profil_foto_galeri')));
    await tester.pumpAndSettle();
    expect(find.text('Fotoğraf ekle'), findsOneWidget);
    await _tap(tester, 'profil_kaydet');
    expect(repo.saves.single.photo.present, isFalse);
  });

  testWidgets('fotoğraf kaldırılır: kayıtta boş değer yazılır', (tester) async {
    final repo = FakeProfileRepository();
    repo.current = repo.current.copyWith(photo: Value(_png));
    await _open(tester, repo);
    expect(find.text('Fotoğrafı değiştir'), findsOneWidget);

    await _tap(tester, 'profil_foto_degistir');
    await tester.tap(find.byKey(const Key('profil_foto_kaldir')));
    await tester.pumpAndSettle();
    expect(find.text('Fotoğraf ekle'), findsOneWidget);

    await _tap(tester, 'profil_kaydet');
    final photo = repo.saves.single.photo;
    expect(photo.present, isTrue);
    expect(photo.value, isNull);
  });

  testWidgets('fotoğrafsız profilde "kaldır" seçeneği yoktur', (tester) async {
    await _open(tester, FakeProfileRepository());
    await _tap(tester, 'profil_foto_degistir');
    expect(find.byKey(const Key('profil_foto_kaldir')), findsNothing);
  });

  testWidgets('seçici hata verirse uyarı çıkar, mevcut fotoğraf bozulmaz', (tester) async {
    final repo = FakeProfileRepository();
    repo.current = repo.current.copyWith(photo: Value(_png));
    await _open(tester, repo, picker: _FakePicker(error: StateError('kamera yok')));
    await _tap(tester, 'profil_foto_degistir');
    await tester.tap(find.byKey(const Key('profil_foto_kamera')));
    await tester.pumpAndSettle();
    expect(find.text('Fotoğraf alınamadı.'), findsOneWidget);
    expect(find.text('Fotoğrafı değiştir'), findsOneWidget);
  });

  testWidgets('kaydedilemezse hata görünür, ekran açık kalır, girilenler durur', (tester) async {
    final repo = FakeProfileRepository(failSaves: true);
    await _open(tester, repo);
    await tester.enterText(find.byKey(const Key('profil_ad')), 'Ada');
    await _tap(tester, 'profil_kaydet');
    expect(find.text('Profil kaydedilemedi.'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(_text(tester, 'profil_ad'), 'Ada');

    // Düzelince tekrar denenebilir.
    repo.failSaves = false;
    await _tap(tester, 'profil_kaydet');
    expect(find.byType(ProfileScreen), findsNothing);
    expect(repo.saves, hasLength(1));
  });

  testWidgets('profil okunamazsa yeniden dene düğmesi çıkar', (tester) async {
    final repo = FakeProfileRepository(failLoads: 1);
    repo.current = repo.current.copyWith(firstName: 'Ada');
    await _open(tester, repo);
    expect(find.byKey(const Key('profil_okunamadi')), findsOneWidget);
    expect(find.byKey(const Key('profil_kaydet')), findsNothing);

    await tester.tap(find.byKey(const Key('profil_tekrar')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'profil_ad'), 'Ada');
  });
}
