import 'dart:math';

/// Kurtarma kodunda kullanılan okunaklı alfabe: karıştırılan 0/O, 1/I/L yok
/// (31 karakter; 12 karakter ≈ 59 bit).
const String recoveryAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int recoveryCodeLength = 12;

/// Rastgele kurtarma kodu üretir (ayraçsız, 12 karakter).
String generateRecoveryCode([Random? random]) {
  final rnd = random ?? Random.secure();
  return String.fromCharCodes(
    List<int>.generate(
      recoveryCodeLength,
      (_) => recoveryAlphabet.codeUnitAt(rnd.nextInt(recoveryAlphabet.length)),
    ),
  );
}

/// Kullanıcının yazdığı kodu karşılaştırılabilir hâle getirir: büyük harf,
/// boşluk ve tire yok.
String normalizeRecoveryCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

/// Normalleştirilmiş kod biçim olarak geçerli mi.
bool isValidRecoveryCode(String normalized) {
  if (normalized.length != recoveryCodeLength) return false;
  return normalized.split('').every(recoveryAlphabet.contains);
}

/// Gösterim için dörderli gruplar: `ABCD-EFGH-JKMN`.
String formatRecoveryCode(String code) {
  final parts = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    parts.add(code.substring(i, min(i + 4, code.length)));
  }
  return parts.join('-');
}
