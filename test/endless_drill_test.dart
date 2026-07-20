import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/endless_drill.dart';

// Sonsuz Pratik ağırlıklandırması — saf mantık sözleşmeleri:
// "zayıf beceri (düşük ustalık / çok karıştırılan tip) daha sık gelir."

void main() {
  group('typeConfusionTotal', () {
    test('yalnızca eşleşen tip önekini toplar', () {
      final counts = {
        'note:C>E': 3,
        'note:G>A': 2,
        'quality:major7>dominant7': 5,
        'interval:7>12': 1,
      };
      expect(typeConfusionTotal(counts, 'note'), 5); // 3 + 2
      expect(typeConfusionTotal(counts, 'quality'), 5);
      expect(typeConfusionTotal(counts, 'interval'), 1);
      expect(typeConfusionTotal(counts, 'chord'), 0); // hiç yok
    });

    test("başka tipin önekiyle kısmi eşleşme sızmaz ('note' vs 'notez')", () {
      final counts = {'note:C>E': 4, 'degree:1>3': 2};
      // 'degree' toplarken 'note' sayılmamalı; önek ':' ile biter.
      expect(typeConfusionTotal(counts, 'degree'), 2);
      expect(typeConfusionTotal(counts, 'note'), 4);
    });
  });

  group('drillWeight', () {
    const note = DrillCandidate(skillId: 'l1', type: 'note');

    test('taban ağırlık her zaman pozitif', () {
      final w = drillWeight(note, skillXp: const {}, confusionCounts: const {});
      expect(w, greaterThan(0));
    });

    test('ustalık arttıkça ağırlık azalır (zayıf beceri daha ağır)', () {
      final weak = drillWeight(
        note,
        skillXp: const {'l1': 0},
        confusionCounts: const {},
      );
      final strong = drillWeight(
        note,
        skillXp: const {'l1': 200},
        confusionCounts: const {},
      );
      expect(weak, greaterThan(strong));
    });

    test('o tipteki karıştırma sayısı ağırlığı artırır', () {
      final calm = drillWeight(
        note,
        skillXp: const {'l1': 50},
        confusionCounts: const {},
      );
      final confused = drillWeight(
        note,
        skillXp: const {'l1': 50},
        confusionCounts: const {'note:C>E': 4},
      );
      expect(confused, greaterThan(calm));
    });
  });

  group('pickWeightedIndex', () {
    test('deterministik: roll ağırlıklı dilimlere düşer', () {
      final weights = [3.0, 7.0]; // toplam 10
      expect(pickWeightedIndex(weights, 0.0), 0); // 0.0 → dilim 0
      expect(pickWeightedIndex(weights, 0.29), 0); // 2.9 < 3
      expect(pickWeightedIndex(weights, 0.30), 1); // 3.0 → dilim 1
      expect(pickWeightedIndex(weights, 0.99), 1); // 9.9 < 10
    });

    test('boş liste -1; toplam 0 ise ilk indeks', () {
      expect(pickWeightedIndex(const [], 0.5), -1);
      expect(pickWeightedIndex(const [0.0, 0.0], 0.5), 0);
    });
  });

  group('pickDrillIndex — zayıf beceri daha sık seçilir', () {
    test('düzgün roll taramasında zayıf/karıştırılan aday çoğunlukta', () {
      final candidates = const [
        DrillCandidate(skillId: 'strong', type: 'note'), // ustalaşılmış
        DrillCandidate(skillId: 'weak', type: 'quality'), // yeni + karıştırılan
      ];
      final skillXp = const {'strong': 200, 'weak': 0};
      final confusionCounts = const {
        'quality:major7>dominant7': 6,
      }; // 'weak' tipinde karıştırma

      var weakCount = 0;
      var strongCount = 0;
      const n = 1000;
      for (var i = 0; i < n; i++) {
        final idx = pickDrillIndex(
          candidates,
          skillXp: skillXp,
          confusionCounts: confusionCounts,
          roll: i / n, // [0,1) düzgün tarama — deterministik
        );
        if (candidates[idx].skillId == 'weak') {
          weakCount++;
        } else {
          strongCount++;
        }
      }

      // Zayıf/karıştırılan beceri açık ara daha sık gelmeli.
      expect(weakCount, greaterThan(strongCount));
      expect(weakCount, greaterThan((n * 0.7).round()));
    });

    test('boş aday listesi -1 döner', () {
      expect(
        pickDrillIndex(
          const [],
          skillXp: const {},
          confusionCounts: const {},
          roll: 0.5,
        ),
        -1,
      );
    });
  });
}
