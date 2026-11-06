import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/turkish_text.dart';

void main() {
  group('foldTr', () {
    test('Türkçe I/İ kuralıyla küçültür', () {
      expect(foldTr('IŞIK'), 'ışık'); // I → ı (Dart varsayılanı i derdi)
      expect(foldTr('İSTANBUL'), 'istanbul'); // İ → i
      expect(foldTr('BAŞ AĞRISI'), 'baş ağrısı');
    });

    test('kenar ve ardışık boşlukları temizler', () {
      expect(foldTr('  baş   ağrısı '), 'baş ağrısı');
    });

    test('şapkalı harfleri sadeleştirir', () {
      expect(foldTr('Hâlâ'), 'hala');
    });

    test('aynı ad farklı yazımlarla eşit çıkar', () {
      expect(foldTr('Işık hassasiyeti'), foldTr('IŞIK HASSASİYETİ'));
      expect(foldTr('Baş ağrısı'), isNot(foldTr('Baş dönmesi')));
    });
  });

  group('compareTr', () {
    test('Türkçe alfabe sırasını izler', () {
      final names = ['Yorgunluk', 'Öksürük', 'Ateş', 'Ulaş', 'Ağrı', 'İyi', 'Ilık']
        ..sort(compareTr);
      expect(names, ['Ağrı', 'Ateş', 'Ilık', 'İyi', 'Öksürük', 'Ulaş', 'Yorgunluk']);
    });

    test('ç, ğ, ş, ö, ü kendi yerlerinde', () {
      final letters = ['z', 'ü', 'u', 'ş', 's', 'ö', 'o', 'ğ', 'g', 'ç', 'c']
        ..sort(compareTr);
      expect(letters, ['c', 'ç', 'g', 'ğ', 'o', 'ö', 's', 'ş', 'u', 'ü', 'z']);
    });

    test('büyük/küçük harf sırayı etkilemez, kısa olan önce gelir', () {
      expect(compareTr('ağrı', 'AĞRI'), 0);
      expect(compareTr('Baş', 'Baş ağrısı'), lessThan(0));
    });

    test('boşluk harflerden önce gelir ("Baş ağrısı" < "Bulantı")', () {
      expect(compareTr('Baş ağrısı', 'Bulantı'), lessThan(0));
      expect(compareTr('Baş ağrısı', 'Baş dönmesi'), lessThan(0));
    });
  });
}
