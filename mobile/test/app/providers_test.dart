import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';

import '../data/test_support.dart';

void main() {
  test('veritabanı geçersiz kılınmazsa anlaşılır hata verir', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(databaseProvider), throwsStateError);
  });

  test('sağlayıcılar bellek içi veritabanıyla uçtan uca çalışır', () async {
    final db = createTestDb();
    addTearDown(db.close);
    await seedLoaderFor(db).seedIfNeeded();

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => utc(2026, 11, 1, 12)),
    ]);
    addTearDown(container.dispose);

    // Semptom girişi → atak başlat → ilaç kaydet → atağı kapat → zaman çizelgesi.
    final entry = await container.read(symptomEntryRepositoryProvider).create(
          symptomId: SeedLoader.symptomId('headache'),
          severity: 6,
          timestamp: utc(2026, 11, 1, 8),
          location: 'alın',
        );
    final episodes = container.read(episodeServiceProvider);
    final episode = await episodes.start(entry);

    final medicationService = container.read(medicationServiceProvider);
    final med = (await medicationService.available()).first;
    await medicationService.logIntake(
      medicationId: med.id,
      takenAt: utc(2026, 11, 1, 9),
      episodeId: episode.id,
    );

    await episodes.close(episode);
    final closed =
        (await container.read(episodeRepositoryProvider).getById(episode.id))!;
    expect(closed.status, EpisodeStatus.resolved);
    expect(closed.endedAt!.toUtc(), utc(2026, 11, 1, 12)); // saat sağlayıcıdan

    final timeline =
        await container.read(timelineServiceProvider).forDay('2026-11-01');
    expect(timeline.symptomEntries, hasLength(1));
    expect(timeline.medicationLogs, hasLength(1));
  });

  test('aynı veritabanı tüm repository sağlayıcılarında paylaşılır', () async {
    final db = createTestDb();
    addTearDown(db.close);
    await seedLoaderFor(db).seedIfNeeded();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Bir sağlayıcıyla yazılan veri diğeriyle okunur: aynı veritabanı.
    final created = await container
        .read(symptomRepositoryProvider)
        .createCustom(name: 'Deneme semptomu');
    final listed = await container.read(symptomRepositoryProvider).listActive();
    expect(listed.map((s) => s.id), contains(created.id));
  });
}
