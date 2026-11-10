// Adım sayacı okumalarını saklar ve saatlik/günlük adım hesaplar.
//
// Telefonun sayacı "son yeniden başlatmadan beri toplam adım"dır; günlük geçmiş
// tutmaz. Bu servis her okumada ham değeri ve zamanı yazar (`step_samples`),
// adımı ARDIŞIK İKİ OKUMANIN FARKINDAN türetir:
//  * Aynı açılış oturumunda fark = iki okuma arasındaki adım.
//  * Telefon yeniden başlamışsa sayaç sıfırlanır: yeni okumadaki sayı, açılış
//    anından o ana kadar atılan adımdır (açılıştan önceki, okunamayan adımlar
//    kayıptır).
// Bir aralıktaki adım, aralığın içine düşen saatlere SÜREYE ORANTILI dağıtılır
// (okuma atlanmışsa gerçek dağılım bilinmez); uzun aralıklar "tahmini" işaretlenir.
// Okumanın iki yolu (saatlik rutin, uygulama açılışı) birbirinden bağımsızdır:
// ikisi de aynı `record`'u çağırır, biri çalışmasa da diğeri okumasını yapar.

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/step_sample_repository.dart';
import '../../data/repositories/support.dart';
import '../step_source.dart';

/// [StepService.record]'un sonucu.
class StepRecordResult {
  const StepRecordResult(this.status, {required this.stored});

  final StepReadStatus status;

  /// Okuma veritabanına yazıldı mı. Sayaç okunduysa bile, bir önceki okumadan
  /// bir dakikadan az geçtiyse yazılmaz.
  final bool stored;
}

/// Bir günün bir saati.
class HourSteps {
  const HourSteps({required this.hour, required this.steps, required this.estimated});

  /// 0-23 (yerel saat).
  final int hour;

  /// Ondalıklı olabilir: aralıklar süreye orantılı bölünür. Göstermek için yuvarla.
  final double steps;

  /// Bu saatin değeri, uzun bir okuma aralığına ya da yeniden başlatmaya
  /// dayanıyorsa true (gerçek dağılım bilinmiyor).
  final bool estimated;
}

/// Bir günün 24 saatlik adım dağılımı.
class DaySteps {
  const DaySteps({required this.day, required this.hours, required this.hasData});

  final String day;

  /// Her zaman 24 öğe (0..23).
  final List<HourSteps> hours;

  /// O güne düşen herhangi bir okuma ya da okuma aralığı var mı.
  final bool hasData;

  double get total => hours.fold(0.0, (sum, h) => sum + h.steps);

  /// Günlük toplam, tam sayı.
  int get totalRounded => total.round();

  bool get hasEstimate => hours.any((h) => h.estimated);
}

class StepService {
  StepService({
    required StepSource source,
    required StepSampleRepository samples,
    required Clock clock,
  }) : _source = source,
       _samples = samples,
       _clock = clock;

  final StepSource _source;
  final StepSampleRepository _samples;
  final Clock _clock;

  /// Bir önceki okumadan bu kadar kısa süre geçtiyse yeni okuma yazılmaz.
  static const minGap = Duration(minutes: 1);

  /// Bundan uzun okuma aralıkları "tahmini" sayılır.
  static const estimateThreshold = Duration(minutes: 90);

  /// Açılış anları bu kadar yakınsa (açılış sayısı bilinmiyorsa) aynı açılış sayılır.
  static const bootTolerance = Duration(minutes: 2);

  /// Sayacı okur ve yazar. [source]: `StepSampleSources` değerlerinden biri.
  /// Okuma başarısızsa (izin yok, sensör yok...) hiçbir şey yazılmaz.
  Future<StepRecordResult> record(String source) async {
    if (!StepSampleSources.all.contains(source)) {
      throw ArgumentError.value(source, 'source', 'Bilinmeyen okuma yolu');
    }
    final reading = await _source.read();
    if (!reading.isOk) return StepRecordResult(reading.status, stored: false);

    final now = _clock();
    final last = await _samples.latest();
    if (last != null) {
      final gap = now.difference(last.sampledAt);
      if (gap >= Duration.zero && gap < minGap) {
        return const StepRecordResult(StepReadStatus.ok, stored: false);
      }
    }
    await _samples.add(
      counter: reading.counter!,
      bootCount: reading.bootCount,
      uptimeMs: reading.uptimeMs!,
      sampledAt: now,
      source: source,
    );
    return const StepRecordResult(StepReadStatus.ok, stored: true);
  }

  /// Yerel [day] ('YYYY-MM-DD') gününün saatlik adımları.
  Future<DaySteps> forDay(String day) async {
    final p = day.split('-').map(int.parse).toList();
    final start = DateTime(p[0], p[1], p[2]);
    final end = DateTime(p[0], p[1], p[2] + 1);

    final before = await _samples.latestBefore(start);
    final inside = await _samples.listBetween(start, end);
    final after = await _samples.firstAtOrAfter(end);
    final sequence = <StepSample>[?before, ...inside, ?after];

    final steps = List<double>.filled(24, 0);
    final estimated = List<bool>.filled(24, false);
    var hasData = inside.isNotEmpty;

    for (var i = 0; i + 1 < sequence.length; i++) {
      final iv = _interval(sequence[i], sequence[i + 1]);
      if (iv.end.isAfter(start) && iv.start.isBefore(end)) hasData = true;
      if (!iv.end.isAfter(iv.start)) {
        // Süresi sıfır ya da saat geri alınmış: adım bitiş anının saatine yazılır.
        if (!iv.end.isBefore(start) && iv.end.isBefore(end)) {
          steps[iv.end.hour] += iv.steps;
          estimated[iv.end.hour] = true;
        }
        continue;
      }
      final total = iv.end.difference(iv.start).inMicroseconds;
      final tooLong = iv.end.difference(iv.start) > estimateThreshold;
      for (var h = 0; h < 24; h++) {
        final hourStart = DateTime(p[0], p[1], p[2], h);
        final hourEnd = DateTime(p[0], p[1], p[2], h + 1);
        final from = iv.start.isAfter(hourStart) ? iv.start : hourStart;
        final to = iv.end.isBefore(hourEnd) ? iv.end : hourEnd;
        final overlap = to.difference(from).inMicroseconds;
        if (overlap <= 0) continue;
        steps[h] += iv.steps * overlap / total;
        if (iv.estimated || tooLong) estimated[h] = true;
      }
    }

    return DaySteps(
      day: day,
      hours: [for (var h = 0; h < 24; h++) HourSteps(hour: h, steps: steps[h], estimated: estimated[h])],
      hasData: hasData,
    );
  }

  /// Bugünün (saatin yerel gününün) adımları.
  Future<DaySteps> today() {
    final now = _clock();
    return forDay(dayKey(now));
  }

  // --- iç yardımcılar ---

  /// Yeniden başlatma anı: okuma anı eksi açılıştan beri geçen süre.
  DateTime _bootInstant(StepSample s) => s.sampledAt.subtract(Duration(milliseconds: s.uptimeMs));

  bool _sameBoot(StepSample a, StepSample b) {
    final ba = a.bootCount;
    final bb = b.bootCount;
    if (ba != null && bb != null) return ba == bb;
    final diff = _bootInstant(a).difference(_bootInstant(b)).abs();
    return diff < bootTolerance;
  }

  _Interval _interval(StepSample a, StepSample b) {
    if (_sameBoot(a, b) && b.counter >= a.counter) {
      return _Interval(
        start: a.sampledAt,
        end: b.sampledAt,
        steps: (b.counter - a.counter).toDouble(),
        estimated: false,
      );
    }
    // Yeniden başlatma: yeni sayaç, açılıştan beri atılan adımdır.
    final boot = _bootInstant(b);
    return _Interval(
      start: boot.isAfter(a.sampledAt) ? boot : a.sampledAt,
      end: b.sampledAt,
      steps: b.counter.toDouble(),
      estimated: true,
    );
  }
}

class _Interval {
  const _Interval({
    required this.start,
    required this.end,
    required this.steps,
    required this.estimated,
  });

  final DateTime start;
  final DateTime end;
  final double steps;
  final bool estimated;
}
