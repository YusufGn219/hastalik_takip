// İlaç kataloğu araması için metin yardımcıları.

import '../core/utils/turkish_text.dart';

/// `medications.name` sütununun en çok aldığı karakter sayısı.
const medicationNameMaxLength = 100;

/// Arama anahtarı: [foldTr] ile küçültülür, sonra Türkçe harfler sade harfe
/// çevrilir (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u). Böylece "cay" da "ÇAY" bulur ve
/// kaynaktaki tutarsız yazım ("SÜSPANSİYON" / "SUSPANSIYON") aynı anahtara iner.
String drugSearchKey(String text) {
  return foldTr(text)
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}

/// Arama sözcüklerine böler (boşluğa göre, boşlar atılır).
List<String> drugSearchTokens(String query) =>
    drugSearchKey(query).split(' ').where((t) => t.isNotEmpty).toList();

/// Katalogdan seçilen adı ilaç adı sınırına (100 karakter) uydurur: sınırı
/// aşıyorsa kırpılır ve kenar boşlukları atılır.
String medicationNameFromCatalog(String catalogName) {
  final clean = catalogName.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.length <= medicationNameMaxLength) return clean;
  return clean.substring(0, medicationNameMaxLength).trim();
}
