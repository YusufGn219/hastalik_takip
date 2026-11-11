import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/drug_search.dart';

void main() {
  group('drugSearchKey', () {
    test('Türkçe büyük/küçük harf kuralları ve sade harfe çevirme', () {
      expect(drugSearchKey('ÇAY AĞACI'), 'cay agaci');
      expect(drugSearchKey('SÜSPANSİYON'), 'suspansiyon');
      expect(drugSearchKey('SUSPANSIYON'), 'suspansiyon', reason: 'kaynaktaki tutarsız yazım aynı anahtara iner');
      expect(drugSearchKey('ISIRGAN'), 'isirgan', reason: 'I → ı → i');
      expect(drugSearchKey('İbuprofen'), 'ibuprofen');
      expect(drugSearchKey('Şeker Öküz'), 'seker okuz');
    });

    test('fazla boşluk tek olur, kenar boşlukları atılır', () {
      expect(drugSearchKey('  PAROL   500 '), 'parol 500');
    });
  });

  group('drugSearchTokens', () {
    test('sözcüklere böler, boşları atar', () {
      expect(drugSearchTokens('  Parol   500  '), ['parol', '500']);
      expect(drugSearchTokens('   '), isEmpty);
      expect(drugSearchTokens(''), isEmpty);
    });
  });

  group('medicationNameFromCatalog', () {
    test('sınır içindeki ad aynen (boşluklar düzeltilmiş) döner', () {
      expect(medicationNameFromCatalog('  PAROL   500 MG TABLET '), 'PAROL 500 MG TABLET');
    });

    test('100 karakteri aşan ad kırpılır; sonuç 100 karakteri geçmez ve kenarı temiz olur', () {
      final long = '${'A' * 99} BBBBBB';
      final cut = medicationNameFromCatalog(long);
      expect(cut.length, lessThanOrEqualTo(medicationNameMaxLength));
      expect(cut, 'A' * 99);
      expect(medicationNameFromCatalog('X' * 100).length, 100);
      expect(medicationNameFromCatalog('X' * 101).length, 100);
    });
  });
}
