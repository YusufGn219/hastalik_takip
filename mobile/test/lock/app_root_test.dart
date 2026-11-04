import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_root.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/test_support.dart';

void main() {
  group('Denetleyici: kurtarma kodu yardımcıları', () {
    Future<(ProviderContainer, AppLockController, String)> setUp() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pinIterationsProvider.overrideWithValue(10),
      ]);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      return (c, n, await n.enable('1234'));
    }

    test('checkRecoveryCode: doğruysa PIN değişmez ve kilit açılmaz; yanlış sayaca işler', () async {
      final (c, n, code) = await setUp();
      n.lockNow();

      expect(await n.checkRecoveryCode('AAAA-BBBB-CCCC'), PinResult.wrong);
      expect(c.read(appLockProvider).failures, 1);
      expect(await n.checkRecoveryCode(code), PinResult.ok);
      expect(c.read(appLockProvider).failures, 0);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.checkPin('1234', unlock: false), PinResult.ok);
    });

    test('recoverWithCode(unlock: false): kilit kapalı kalır; finishRecovery ile açılır; ikinci çağrı etkisiz', () async {
      final (c, n, code) = await setUp();
      n.lockNow();

      final out = await n.recoverWithCode(code, '5678', unlock: false);
      expect(out.result, PinResult.ok);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.checkPin('5678', unlock: false), PinResult.ok, reason: 'PIN yazıldı');

      n.finishRecovery();
      expect(c.read(appLockProvider).locked, isFalse);

      n.lockNow();
      n.finishRecovery(); // bekleyen kurtarma yok: kilidi açmamalı
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('yanlış kodla unlock: false denemesi finishRecovery\'yi etkinleştirmez', () async {
      final (c, n, _) = await setUp();
      n.lockNow();
      final out = await n.recoverWithCode('AAAA-BBBB-CCCC', '5678', unlock: false);
      expect(out.result, PinResult.wrong);
      n.finishRecovery();
      expect(c.read(appLockProvider).locked, isTrue);
    });
  });

  group('eraseDatabaseStorage', () {
    test('veritabanı dosyası ve yan dosyaları silinir, anahtar silici çağrılır, başka dosyaya dokunulmaz', () async {
      final dir = await Directory.systemTemp.createTemp('vitapuls_erase_');
      addTearDown(() => dir.delete(recursive: true));
      for (final name in ['vitapuls.db', 'vitapuls.db-wal', 'vitapuls.db-shm', 'vitapuls.db-journal', 'baska.txt']) {
        await File('${dir.path}/$name').writeAsString('x');
      }
      var keyDeleted = 0;

      await eraseDatabaseStorage(directory: dir, deleteKey: () async => keyDeleted++);

      final left = dir.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(left, ['baska.txt']);
      expect(keyDeleted, 1);
    });

    test('dosyalar yoksa da hata vermez, anahtar yine silinir', () async {
      final dir = await Directory.systemTemp.createTemp('vitapuls_erase_');
      addTearDown(() => dir.delete(recursive: true));
      var keyDeleted = 0;
      await eraseDatabaseStorage(directory: dir, deleteKey: () async => keyDeleted++);
      expect(keyDeleted, 1);
    });

    test('anahtar silici hata verirse hata yukarı çıkar', () async {
      final dir = await Directory.systemTemp.createTemp('vitapuls_erase_');
      addTearDown(() => dir.delete(recursive: true));
      await expectLater(
        eraseDatabaseStorage(directory: dir, deleteKey: () async => throw StateError('keystore')),
        throwsStateError,
      );
    });
  });

  group('AppRoot', () {
    testWidgets('wipe: veritabanı kapatılır, silinir, yenisi açılır; restart yeni kapsamı yeni veritabanıyla kurar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = createTestDb();
      final second = createTestDb();
      var opened = 0;
      var erased = 0;
      final order = <String>[];
      AppDatabase? seenDb;
      late WidgetRef seenRef;

      await tester.pumpWidget(AppRoot(
        database: first,
        prefs: prefs,
        openDatabase: () async {
          opened++;
          order.add('open');
          return second;
        },
        eraseStorage: () async {
          erased++;
          order.add('erase');
        },
        child: Consumer(builder: (context, ref, _) {
          seenRef = ref;
          seenDb = ref.watch(databaseProvider);
          return const SizedBox();
        }),
      ));
      expect(seenDb, same(first));

      await seenRef.read(dataWiperProvider).wipe();
      expect(opened, 1);
      expect(erased, 1);
      expect(order, ['erase', 'open'], reason: 'önce sil, sonra yeni aç');
      expect(seenDb, same(first), reason: 'restart gelene kadar eski kapsam sürer');

      await seenRef.read(appRestartProvider)();
      await tester.pump();
      expect(seenDb, same(second));
      addTearDown(second.close);
    });

    testWidgets('wipe başarısız olursa hata yukarı çıkar ve yeni veritabanı açılmaz', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var opened = 0;
      late WidgetRef seenRef;

      await tester.pumpWidget(AppRoot(
        database: createTestDb(),
        prefs: prefs,
        openDatabase: () async {
          opened++;
          return createTestDb();
        },
        eraseStorage: () async => throw StateError('disk'),
        child: Consumer(builder: (context, ref, _) {
          seenRef = ref;
          return const SizedBox();
        }),
      ));

      await expectLater(seenRef.read(dataWiperProvider).wipe(), throwsStateError);
      expect(opened, 0);
    });
  });
}
