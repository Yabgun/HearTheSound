import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';

// -----------------------------------------------------------------------------
// İÇERİK GENİŞLETME — yeni akor derslerinin sözleşmeleri (ch11–ch12).
//
// NOT: iv5–iv6 (harmonik aralık) testleri kaldırıldı; "Aralıklar" track'i
// dağıtıldı. Harmonik aralık içeriği Armoni Kulağı'nın giriş derslerine
// taşınacak ve sözleşmeleri orada yeniden kurulacak.
// -----------------------------------------------------------------------------

void main() {
  group('yeni kök akor dersleri (ch11–ch12)', () {
    test('dersler kavram kartlı ve akor-tanıma modunda', () {
      final byId = {for (final l in chordLessons) l.id: l};
      expect(byId['ch11']!.pool.length, 4);
      expect(byId['ch12']!.pool.length, 6);
      for (final id in ['ch11', 'ch12']) {
        expect(byId[id]!.recognizeBy, ChordRecognizeBy.chord);
        expect(byId[id]!.concept, isNotNull);
      }
    });

    test('ch12 kök çeşitliliği: D majör ve B minör dahil', () {
      final labels = chordLessons
          .firstWhere((l) => l.id == 'ch12')
          .pool
          .map((c) => '${c.root.name}.${c.quality.name}')
          .toSet();
      expect(labels, contains('D.major'));
      expect(labels, contains('B.minor'));
    });
  });

  // NOT: fn3/pr3 (D Majör transferi) testleri kaldırıldı — "Akor İşlevi" ve
  // "İlerlemeler" track'leri müfredattan çıkarıldı (bkz. curriculum.dart).
}
