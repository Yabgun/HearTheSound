import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_lesson.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_pattern.dart';

// -----------------------------------------------------------------------------
// RİTİM ÇEKİRDEĞİ — sözleşmeler + ÇEŞİTLİLİK nöbetçisi
//
// Melodi tarafında cihazda çıkan "hep aynı ezgi" bug'ının ritim karşılığı daha
// da sinsi olurdu: kalıp çeşitlenmezse kullanıcı DİNLEMEDEN, ezberden vurur.
// Bu yüzden hem kalıpların hem de ZORLUK SÖZLEŞMELERİNİN (senkop kapalıyken
// vuruş dışına düşmemek gibi) testi burada.
// -----------------------------------------------------------------------------

void main() {
  List<List<int>> patterns(RhythmShape shape, {int seeds = 60}) => [
    for (var seed = 0; seed < seeds; seed++)
      generateRhythm(shape: shape, rng: Random(seed)),
  ];

  group('kalıp üretimi', () {
    const onBeat = RhythmShape(beats: 4, onsetCount: 3);
    const syncopated = RhythmShape(
      beats: 4,
      onsetCount: 5,
      subdivision: 2,
      allowOffbeat: true,
    );

    test('istenen sayıda ses üretir, artan sırada, yinelemesiz', () {
      for (final shape in [onBeat, syncopated]) {
        for (final slots in patterns(shape)) {
          expect(slots.length, shape.onsetCount);
          expect(slots.toSet().length, slots.length, reason: 'yinelenen yuva');
          for (var i = 1; i < slots.length; i++) {
            expect(slots[i], greaterThan(slots[i - 1]));
          }
          expect(slots.last, lessThan(shape.slotCount));
        }
      }
    });

    test('kalıp HER ZAMAN sıfırıncı yuvada başlar', () {
      // Hizalama ilk vuruşa göre yapıldığı için "sessizlikle başlamak"
      // ölçülemez bir farktır; üretim de bunu vaat etmemeli.
      for (final shape in [onBeat, syncopated]) {
        for (final slots in patterns(shape)) {
          expect(slots.first, 0);
        }
      }
    });

    test('senkop KAPALIYKEN hiçbir ses vuruş dışına düşmez', () {
      const shape = RhythmShape(beats: 4, onsetCount: 3, subdivision: 2);
      for (final slots in patterns(shape)) {
        for (final slot in slots) {
          expect(slot % shape.subdivision, 0, reason: 'vuruş dışı ses: $slots');
        }
      }
    });

    test('senkop AÇIKKEN gerçekten vuruş arasına düşer', () {
      var sawOffbeat = false;
      for (final slots in patterns(syncopated)) {
        if (slots.any((s) => s % syncopated.subdivision != 0)) {
          sawOffbeat = true;
        }
      }
      expect(sawOffbeat, isTrue, reason: 'senkop dersi senkop üretmiyor');
    });

    test('ÇEŞİTLİLİK: kalıplar tekrara düşmez', () {
      expect(
        patterns(onBeat).map((p) => p.join('-')).toSet().length,
        greaterThanOrEqualTo(3),
      );
      expect(
        patterns(syncopated).map((p) => p.join('-')).toSet().length,
        greaterThanOrEqualTo(15),
      );
    });

    test('geçersiz şekil sessizce garip kalıp üretmez, hata verir', () {
      expect(
        () => generateRhythm(
          shape: const RhythmShape(beats: 4, onsetCount: 1),
          rng: Random(1),
        ),
        throwsArgumentError,
        reason: 'tek sesli kalıp tekrarlanacak aralık taşımaz',
      );
      expect(
        () => generateRhythm(
          // 4 vuruşta yalnızca vuruş üstü = 4 yuva; 6 ses sığmaz.
          shape: const RhythmShape(beats: 4, onsetCount: 6),
          rng: Random(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => generateRhythm(
          shape: const RhythmShape(beats: 4, onsetCount: 3, subdivision: 4),
          rng: Random(1),
        ),
        throwsArgumentError,
        reason: 'onaltılık, dokunma hassasiyetinin altında kalır',
      );
    });

    test('yuvalar milisaniyeye doğru çevrilir', () {
      const shape = RhythmShape(beats: 4, onsetCount: 3, subdivision: 2);
      expect(
        onsetTimesMs(slots: const [0, 3, 6], shape: shape),
        [0, 900, 1800], // sekizlik = 300 ms (100 BPM)
      );
      expect(shape.totalMs, 4 * kRhythmBeatMs);
    });
  });

  group('karşılaştırma — ölçülen şey ARALIKLAR, başlama anı değil', () {
    const target = [0, 600, 1200];

    test('geç başlamak cezalandırılmaz (kullanıcı hazır olunca başlar)', () {
      final comparison = compareRhythm(
        targetMs: target,
        tapMs: const [5000, 5600, 6200], // 5 sn sonra, ama aralıklar birebir
        toleranceMs: 150,
      );
      expect(comparison.isPerfect, isTrue);
    });

    test('tolerans içindeki sapma kabul, dışındaki ret', () {
      expect(
        compareRhythm(
          targetMs: target,
          tapMs: const [0, 700, 1300],
          toleranceMs: 150,
        ).isPerfect,
        isTrue,
      );
      expect(
        compareRhythm(
          targetMs: target,
          tapMs: const [0, 800, 1400],
          toleranceMs: 150,
        ).isPerfect,
        isFalse,
      );
    });

    test('sapmanın YÖNÜ korunur (erken − / geç +)', () {
      final comparison = compareRhythm(
        targetMs: target,
        tapMs: const [0, 500, 1400],
        toleranceMs: 50,
      );
      expect(comparison.offsetsMs[1], -100); // erken
      expect(comparison.offsetsMs[2], 200); // geç
    });

    test('eksik vuruş yanlış sayılır ve sapması bilinmez', () {
      final comparison = compareRhythm(
        targetMs: target,
        tapMs: const [0, 600],
        toleranceMs: 150,
      );
      expect(comparison.matches, [true, true, false]);
      expect(comparison.offsetsMs.last, isNull);
      expect(comparison.accuracy, closeTo(2 / 3, 0.001));
    });

    test('hiç vurulmadıysa çökmez, hepsi yanlış', () {
      final comparison = compareRhythm(
        targetMs: target,
        tapMs: const [],
        toleranceMs: 150,
      );
      expect(comparison.matches, everyElement(isFalse));
      expect(comparison.isPerfect, isFalse);
    });
  });

  group('ders sözleşmeleri', () {
    test('her ders üretilebilir bir şekil tanımlar', () {
      for (final lesson in rhythmLessons) {
        expect(
          () => generateRhythm(shape: lesson.shape, rng: Random(1)),
          returnsNormally,
          reason: '${lesson.id} üretilemiyor',
        );
      }
    });

    test('tolerans ders ilerledikçe genelde DARALIR (ölçüt keskinleşir)', () {
      final first = rhythmLessons.first.toleranceMs;
      final last = rhythmLessons.last.toleranceMs;
      expect(last, lessThan(first));
    });

    test('tolerans en küçük birimin yarısını aşmaz (soru belirsizleşmesin)', () {
      // Aksi hâlde bir sesin "doğru" penceresi komşu yuvayla örtüşür ve
      // yanlış kalıp da doğru sayılırdı.
      for (final lesson in rhythmLessons) {
        expect(
          lesson.toleranceMs,
          lessThanOrEqualTo(lesson.shape.slotMs ~/ 2),
          reason: '${lesson.id}: tolerans çok geniş',
        );
      }
    });
  });
}
