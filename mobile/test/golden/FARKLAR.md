# Altın veri: eski ve yeni beklenen çıktı arasındaki farklar

Tarih: 2026-11-04 (Sprint 2)

İki beklenen dosya aynı örnek veriyi (`dataset.json`) kullanır:

- `expected_analytics.json`: eski Django/Python kodunun davranışının kaydı
  (`scripts/golden/generate_golden.py`). **Tarihçedir, değiştirilmez.**
- `expected_analytics_v2.json`: düzeltilmiş kurallarla, Django'dan bağımsız
  yazılmış betikle üretilir (`scripts/golden/generate_golden_v2.py`). Dart
  servisi bu dosyayla karşılaştırılır (`analytics_golden_test.dart`).

İki dosya arasındaki her fark aşağıdaki altı düzeltmeden birine bağlanır. Bu
listede olmayan bir fark görülürse hata vardır.

## Düzeltmeler

**T1 — Gün, kaydın yerel gününe göre.** Şiddet eğilimi günleri UTC gününe göre
gruplanıyordu; gece 00:00–03:00 (Türkiye) arası kayıtlar bir önceki güne
düşüyordu. Artık kaydın kendi UTC farkıyla yerel gün kullanılır.
Etki: `severity_trend` tarihleri (ör. 12→13 Ekim, 26→27 Ekim, 27→28 Ekim) ve bu
günlerin ortalamaları.

**T2 — Sıfır geçerli değerdir.** Uyku/su 0 ise "veri yok" sayılıyordu. Artık 0
olarak gösterilir; ortalama yalnız hiç kayıt yoksa boş.
Etki: 13 Ekim `water_intake` `null` → `0.0` (30 ve 90 günlük pencere).

**T3 — Geçersiz gün adı.** İlaç eklenirken reddedilir
(`MedicationService.create`, `invalid_recurring_day`). Analitik, eski veride
geçersiz ad bulursa yok sayar; kalan boşsa her gün beklenir. Veri kümesindeki
"Hatali gun adi" (`funday`) ilacı bu yolu sınar.
Etki: bu ilacın sayıları yalnız T5 nedeniyle değişir; ad işleme davranışı aynı.

**T4 — Uyum yalnız programlı günler üzerinden.** Programda olmayan günlerde
alınan dozlar "alınan gün"e katılıyordu (oran %100'ü aşabilir, kaçırma
gizlenebilir). Artık ayrı bir `extra_days` sayısı olarak çıkar.
Etki: "Hafta ici ilac" 30 gün: alınan 11 → 10, `extra_days` 1, oran 84,6 → 83,3;
90 gün: alınan 11 → 10, `extra_days` 1.

**T5 — Pencere: bugün dahil son N yerel gün.** Eski pencere N+1 gün sayıyordu
(başlangıç ve bugün dahil) ve semptom/ilaç etkisi hesapları tam an hesabıyla,
uyum/günlük eğilim hesapları gün hesabıyla çalışıyordu. Artık dördü de aynı
pencereyi kullanır; "bugün" yerel güne göre.
Etki: `expected_days` 8→7, 31→30, 91→90 (günlük vitamin ve benzerleri);
7 günlük pencerede 25 Ekim günlük kaydı ve 25 Ekim eğilim noktası çıktı
(pencere artık 26 Ekim'de başlar); 30 günlük pencerede 2 Ekim çıktı; günlük
ortalamalar (uyku, su, ruh hali, enerji) ve sınırdaki `Yorgunluk` kayıtlarının
sayıları/ortalamaları buna göre değişti (bazı eğilim noktaları T1 ile de
etkilenir).

**T6 — Rahatlama süresi gerçek düşüşe bağlı.** Eski kod dozdan sonraki ilk
kaydın süresini "rahatlama" sayıyordu (şiddete bakmadan). Artık dozdan sonraki 2
saatte şiddetin, dozdan önceki ortalamanın altına ilk indiği kayda kadar geçen
süre; düşüş yoksa o doz süreye katılmaz, hiçbirinde yoksa değer boş.
Etki: Aspirin `avg_relief_minutes` 80 → 60 (30 ve 90 gün).
"Önce" penceresi alım anını içerir, "sonra" içermez (değişmedi).
Bilinen sınır: iki doz 2 saatten yakınsa pencereleri üst üste biner.

## Yuvarlama

Yarım değerler yukarı yuvarlanır (iki tarafta da aynı kural). Eski Python çift
sayıya yuvarlıyordu; bu yüzden eski üretici yarım değerli veriyi reddediyordu.
Yeni betik yalnız "yarıma çok yakın ama eşit olmayan" değerleri reddeder.

## Yeniden üretme

```
python -I scripts/golden/generate_golden_v2.py
```

Çıktı iki çalıştırmada aynıdır (md5 aynı). Eski dosyayı yeniden üretmek için
`scripts/golden/generate_golden.py` projenin `venv`'iyle çalıştırılır.
