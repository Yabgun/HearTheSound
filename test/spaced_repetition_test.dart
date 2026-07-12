import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/spaced_repetition.dart';

void main() {
  final day0 = DateTime(2026, 7, 12);

  group('qualityFromAccuracy', () {
    test('eşikler doğru kaliteye çevrilir', () {
      expect(qualityFromAccuracy(1.0), 5);
      expect(qualityFromAccuracy(0.90), 4);
      expect(qualityFromAccuracy(0.75), 3);
      expect(qualityFromAccuracy(0.60), 2);
      expect(qualityFromAccuracy(0.40), 1);
      expect(qualityFromAccuracy(0.10), 0);
    });
  });

  group('applyReview — başarılı seri aralıkları büyütür', () {
    test('ilk üç başarılı tekrar 1 → 6 → ~16 gün', () {
      final r1 = applyReview(prev: null, accuracy: 1.0, now: day0);
      expect(r1.intervalDays, 1);
      expect(r1.reps, 1);
      expect(r1.dueDay, '2026-07-13');

      final r2 = applyReview(prev: r1, accuracy: 1.0, now: DateTime(2026, 7, 13));
      expect(r2.intervalDays, 6);
      expect(r2.reps, 2);
      expect(r2.dueDay, '2026-07-19');

      final r3 = applyReview(prev: r2, accuracy: 1.0, now: DateTime(2026, 7, 19));
      // ease r2 ≈ 2.7 → 6*2.7 = 16.2 → 16 gün.
      expect(r3.intervalDays, 16);
      expect(r3.reps, 3);
    });

    test('ease başarılı tekrarla artar, min 1.3 altına düşmez', () {
      final good = applyReview(prev: null, accuracy: 1.0, now: day0);
      expect(good.ease, greaterThan(2.5));

      // Arka arkaya başarısızlıklar ease'i düşürür ama tabana takılır.
      var s = applyReview(prev: null, accuracy: 0.0, now: day0);
      for (var i = 0; i < 10; i++) {
        s = applyReview(prev: s, accuracy: 0.0, now: day0);
      }
      expect(s.ease, 1.3);
    });
  });

  group('applyReview — başarısızlık sıfırlar', () {
    test('q<3 reps sıfırlanır, yarına planlanır, lapse artar', () {
      final r1 = applyReview(prev: null, accuracy: 1.0, now: day0);
      final r2 = applyReview(prev: r1, accuracy: 1.0, now: DateTime(2026, 7, 13));
      expect(r2.reps, 2);

      final fail =
          applyReview(prev: r2, accuracy: 0.4, now: DateTime(2026, 7, 19));
      expect(fail.reps, 0);
      expect(fail.intervalDays, 1);
      expect(fail.lapses, 1);
      expect(fail.dueDay, '2026-07-20');
    });
  });

  group('isDueOn', () {
    final s = applyReview(prev: null, accuracy: 1.0, now: day0); // due 07-13
    test('vade günü ve sonrası due, öncesi değil', () {
      expect(s.isDueOn('2026-07-12'), isFalse);
      expect(s.isDueOn('2026-07-13'), isTrue);
      expect(s.isDueOn('2026-07-20'), isTrue);
    });
  });

  group('serileştirme', () {
    test('toMap/fromMap gidiş-dönüş korunur', () {
      final s = applyReview(prev: null, accuracy: 0.9, now: day0);
      final back = ReviewState.fromMap(s.toMap());
      expect(back.ease, s.ease);
      expect(back.intervalDays, s.intervalDays);
      expect(back.reps, s.reps);
      expect(back.lapses, s.lapses);
      expect(back.dueDay, s.dueDay);
    });
  });
}
