import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/database_swapper.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/features/backup/backup_platform.dart';
import 'package:mobile/features/backup/backup_restore_screen.dart';
import 'package:mobile/features/backup/backup_restorer.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage implements BackupStorage {
  @override
  Future<File> databaseFile() => throw UnimplementedError();
  @override
  Future<String> databaseKey() => throw UnimplementedError();
  @override
  Future<Directory> scratchDirectory() => throw UnimplementedError();
}

class _FakePicker implements BackupFilePicker {
  _FakePicker(this.file);
  final File? file;
  int calls = 0;

  @override
  Future<File?> pick() async {
    calls++;
    return file;
  }
}

/// Gerçek dosya/veritabanı işi yapmadan sonucu önceden belirlenen geri yükleme.
class _FakeRestorer extends BackupRestorer {
  _FakeRestorer({this.error})
      : super(
          service: BackupService(currentSchemaVersion: 3),
          storage: _FakeStorage(),
          swapper: const UnconfiguredDatabaseSwapper(),
        );

  final Object? error;
  final calls = <(String, String)>[];
  final discarded = <String>[];

  @override
  Future<void> run({required File backup, required String passphrase}) async {
    calls.add((backup.path, passphrase));
    if (error != null) throw error!;
  }

  @override
  Future<void> discardPickedCopy(File file) async => discarded.add(file.path);
}

class _NoBiometric implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate(String reason) async => false;
}

class _Env {
  _Env(this.prefs, {File? picked, Object? error})
      : picker = _FakePicker(picked ?? File('/cache/file_picker/yedek.vpbak')),
        restorer = _FakeRestorer(error: error);

  final SharedPreferences prefs;
  final _FakePicker picker;
  final _FakeRestorer restorer;
  int restarts = 0;
}

Future<_Env> _env({String? pin, Object? error}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (pin != null) {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pinIterationsProvider.overrideWithValue(10),
    ]);
    await c.read(appLockProvider.notifier).enable(pin);
    c.dispose();
  }
  return _Env(prefs, error: error);
}

Future<void> _mount(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(env.prefs),
      pinIterationsProvider.overrideWithValue(10),
      biometricAuthenticatorProvider.overrideWithValue(_NoBiometric()),
      backupFilePickerProvider.overrideWithValue(env.picker),
      backupRestorerProvider.overrideWithValue(env.restorer),
      appRestartProvider.overrideWithValue(() async => env.restarts++),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupRestoreScreen(),
    ),
  ));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pickAndType(WidgetTester tester, String pass) async {
  await _tap(tester, find.byKey(const Key('geri_yukle_sec')));
  await tester.enterText(find.byKey(const Key('geri_yukle_parola')), pass);
  await tester.pump();
}

Future<void> _pin(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('pin_$d')));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('uyarı görünür: mevcut verinin yerine geçer, geri alınamaz', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);

    expect(find.byKey(const Key('geri_yukle_uyari')), findsOneWidget);
    expect(find.textContaining('yerine yedektekileri koyar'), findsOneWidget);
    expect(find.text('Henüz dosya seçilmedi'), findsOneWidget);
  });

  testWidgets('dosya seçilince adı gösterilir; seçimden vazgeçilirse bir şey değişmez', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);
    await _tap(tester, find.byKey(const Key('geri_yukle_sec')));
    expect(find.text('yedek.vpbak'), findsOneWidget);

    final cancelled = (await tester.runAsync(() => _env()))!;
    final nullEnv = _Env(cancelled.prefs, picked: null);
    // Vazgeçme: sahte seçici null döndürür.
    final noPick = _FakePicker(null);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(nullEnv.prefs),
        backupFilePickerProvider.overrideWithValue(noPick),
        backupRestorerProvider.overrideWithValue(nullEnv.restorer),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BackupRestoreScreen(),
      ),
    ));
    await _tap(tester, find.byKey(const Key('geri_yukle_sec')));
    expect(noPick.calls, 1);
    expect(find.text('Henüz dosya seçilmedi'), findsOneWidget);
  });

  testWidgets('dosya ya da parola yoksa geri yükleme başlamaz', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);

    await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));
    expect(find.text('Önce bir yedek dosyası seçin'), findsOneWidget);
    expect(find.text('Yedek parolasını yazın'), findsOneWidget);
    expect(env.restorer.calls, isEmpty);
    expect(find.text('Geri yüklensin mi?'), findsNothing);
  });

  testWidgets('onay penceresinde vazgeçilirse hiçbir şey yapılmaz', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);
    await _pickAndType(tester, 'yedek parolam 2026');
    await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));

    expect(find.text('Geri yüklensin mi?'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('geri_yukle_vazgec')));

    expect(env.restorer.calls, isEmpty);
    expect(env.restarts, 0);
  });

  testWidgets('onaylanırsa geri yüklenir, bilgi penceresi gösterilir ve uygulama baştan kurulur', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);
    await _pickAndType(tester, 'yedek parolam 2026');
    await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));
    await _tap(tester, find.byKey(const Key('geri_yukle_onay')));

    expect(env.restorer.calls, [('/cache/file_picker/yedek.vpbak', 'yedek parolam 2026')]);
    expect(env.restorer.discarded, ['/cache/file_picker/yedek.vpbak']);
    expect(find.text('Geri yüklendi'), findsOneWidget);
    expect(env.restarts, 0, reason: 'kullanıcı Tamam diyene kadar yeniden kurulmaz');

    await _tap(tester, find.byKey(const Key('geri_yukle_tamam')));
    expect(env.restarts, 1);
  });

  testWidgets('hata türüne göre anlaşılır mesaj çıkar ve uygulama yeniden kurulmaz', (tester) async {
    final cases = {
      BackupFailure.wrongPassphraseOrCorrupt: 'Parola yanlış ya da dosya bozuk',
      BackupFailure.newerVersion: 'daha yeni bir sürümüyle alınmış',
      BackupFailure.notABackup: 'bir Vitapuls yedeği değil',
      BackupFailure.io: 'Geri yüklenemedi',
    };
    for (final entry in cases.entries) {
      final env = (await tester.runAsync(() => _env(error: BackupException(entry.key))))!;
      await _mount(tester, env);
      await _pickAndType(tester, 'yedek parolam 2026');
      await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));
      await _tap(tester, find.byKey(const Key('geri_yukle_onay')));

      expect(find.textContaining(entry.value), findsOneWidget, reason: entry.key.name);
      expect(find.textContaining('Mevcut verileriniz değişmedi'), findsOneWidget);
      expect(env.restarts, 0);
      expect(env.restorer.discarded, isNotEmpty, reason: 'hata olsa da seçici kopyası silinir');
    }
  });

  testWidgets('parola göster/gizle çalışır', (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);
    TextField field() => tester.widget<TextField>(find.byKey(const Key('geri_yukle_parola')));

    expect(field().obscureText, isTrue);
    await _tap(tester, find.byKey(const Key('geri_yukle_goster')));
    expect(field().obscureText, isFalse);
  });

  group('uygulama kilidi açıkken', () {
    testWidgets('önce PIN istenir; vazgeçilirse onay penceresi bile açılmaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await _pickAndType(tester, 'yedek parolam 2026');
      await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));

      expect(find.byKey(const Key('pin_dogrula_vazgec')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('pin_dogrula_vazgec')));

      expect(find.text('Geri yüklensin mi?'), findsNothing);
      expect(env.restorer.calls, isEmpty);
    });

    testWidgets('yanlış PIN geri yüklemeyi açmaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await _pickAndType(tester, 'yedek parolam 2026');
      await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));
      await _pin(tester, '9999');

      expect(find.byKey(const Key('pin_dogrula_hata')), findsOneWidget);
      expect(find.text('Geri yüklensin mi?'), findsNothing);
      expect(env.restorer.calls, isEmpty);
    });

    testWidgets('doğru PIN + onay geri yüklemeyi çalıştırır', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await _pickAndType(tester, 'yedek parolam 2026');
      await _tap(tester, find.byKey(const Key('geri_yukle_baslat')));
      await _pin(tester, '1234');
      expect(find.text('Geri yüklensin mi?'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('geri_yukle_onay')));

      expect(env.restorer.calls, hasLength(1));
    });
  });
}
