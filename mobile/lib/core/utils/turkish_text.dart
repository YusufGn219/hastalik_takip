// Türkçe metin karşılaştırma yardımcıları.
//
// Dart'ın `toLowerCase()` yöntemi Türkçe'ye özel değildir: 'I' → 'i' (doğrusu
// 'ı') ve 'İ' → birleşik noktalı 'i' verir. Aynı ad kontrolü ve sıralama için
// bu yüzden önce [foldTr] ile normalleştirilir.

import 'dart:math' as math;

/// Karşılaştırma için normalleştirir: kenar boşlukları atılır, ardışık
/// boşluklar tek olur, Türkçe büyük/küçük harf kurallarıyla küçültülür,
/// şapkalı harfler (â î û) sade hâline çevrilir.
String foldTr(String s) {
  return s
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');
}

const _alphabet = 'abcçdefgğhıijklmnoöprsştuüvwxyz';

/// Harfler Türkçe alfabe sırasında, harf olmayanlar (boşluk, rakam) harflerden
/// önce gelir.
int _rank(int unit) {
  final i = _alphabet.indexOf(String.fromCharCode(unit));
  return i >= 0 ? 1000 + i : unit;
}

/// Türkçe alfabe sırasına göre karşılaştırır ("Öksürük", "Yorgunluk"tan önce
/// gelir). Büyük/küçük harf ve fazla boşluk sırayı etkilemez.
int compareTr(String a, String b) {
  final x = foldTr(a);
  final y = foldTr(b);
  final n = math.min(x.length, y.length);
  for (var i = 0; i < n; i++) {
    final c = _rank(x.codeUnitAt(i)).compareTo(_rank(y.codeUnitAt(i)));
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}
