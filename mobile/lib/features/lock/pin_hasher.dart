import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PIN'in izinli uzunluğu.
const int minPinLength = 4;
const int maxPinLength = 8;

/// PIN geçerli mi: yalnız rakam, [minPinLength]..[maxPinLength] hane.
bool isValidPin(String pin) => RegExp('^[0-9]{$minPinLength,$maxPinLength}\$').hasMatch(pin);

/// PIN'i (ve kurtarma kodunu) düz metin olarak saklamamak için PBKDF2-HMAC-SHA256
/// özeti. Her kurulumda yeni rastgele tuz kullanılır; yinelenme sayısı kaba
/// kuvveti yavaşlatır.
class PinHasher {
  const PinHasher({this.iterations = defaultIterations});

  static const int defaultIterations = 10000;

  final int iterations;

  /// 16 baytlık rastgele tuz (base64).
  String newSalt([Random? random]) {
    final rnd = random ?? Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  /// [pin] ve [salt] (base64) için 32 baytlık özet (base64).
  String hash(String pin, String salt) {
    final key = utf8.encode(pin);
    return base64Encode(pbkdf2(key, base64Decode(salt), iterations, 32));
  }

  /// [pin], [expectedHash] ile eşleşiyor mu (sabit zamanlı karşılaştırma).
  bool verify(String pin, String salt, String expectedHash) {
    final actual = base64Decode(hash(pin, salt));
    final expected = base64Decode(expectedHash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }
}

/// PBKDF2 (RFC 8018) HMAC-SHA256 ile. Testlerde bilinen vektörlerle doğrulanır.
Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
  final hmac = Hmac(sha256, password);
  const hashLength = 32;
  final blocks = (length + hashLength - 1) ~/ hashLength;
  final out = BytesBuilder();
  for (var block = 1; block <= blocks; block++) {
    final index = Uint8List(4)..buffer.asByteData().setUint32(0, block, Endian.big);
    var u = hmac.convert([...salt, ...index]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}
