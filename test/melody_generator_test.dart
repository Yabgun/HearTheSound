import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/melody/melody_generator.dart';

// Eko oyununun malzemesi. Ezgi her soruda YENİDEN üretilir (ezberlenemesin),
// ama ders şeklinin sözleşmesini asla bozmamalı: zorluk tek tek büyür.

void main() {
  const stepwise = MelodyShape(
    noteCount: 5,
    degrees: [1, 2, 3, 4, 5],
    startOnTonic: true,
  );

  // ÇEŞİTLİLİK — cihazda yakalanan gerçek bug'ın nöbetçisi.
  // İlk sürümde "tonikten başla + yalnızca komşuya adım" kuralı 2 notalık
  // derste TEK bir ezgi üretiyordu; kullanıcı her soruda aynı sesi duyuyordu.
  group('çeşitlilik — her soru farklı ezgi', () {
    List<String> variants(MelodyShape shape, {int seeds = 60}) => [
      for (var seed = 0; seed < seeds; seed++)
        generateDegrees(shape: shape, rng: Random(seed)).join('-'),
    ];

    test('en kısa ders bile bir avuç farklı ezgi üretir', () {
      const shortest = MelodyShape(
        noteCount: 2,
        degrees: [1, 2, 3, 4, 5],
        maxLeap: 2,
      );
      expect(
        variants(shortest).toSet().length,
        greaterThanOrEqualTo(8),
        reason: '2 notalık derste ezgiler tekrara düşmemeli',
      );
    });

    test('uzun/serbest ders yüksek çeşitlilik verir', () {
      const hardest = MelodyShape(
        noteCount: 7,
        degrees: [1, 2, 3, 4, 5, 6, 7, 8],
        maxLeap: 7,
        endOnTonic: true,
      );
      expect(variants(hardest).toSet().length, greaterThanOrEqualTo(50));
    });

    test('ezgiler hep aynı notadan başlamaz (startOnTonic kapalıyken)', () {
      const shape = MelodyShape(
        noteCount: 3,
        degrees: [1, 2, 3, 4, 5],
        maxLeap: 2,
      );
      final firsts = {
        for (var seed = 0; seed < 40; seed++)
          generateDegrees(shape: shape, rng: Random(seed)).first,
      };
      expect(firsts.length, greaterThan(1));
    });
  });

  test('maxLeap sıçrama genişliğini sınırlar', () {
    const shape = MelodyShape(
      noteCount: 6,
      degrees: [1, 2, 3, 4, 5, 6, 7],
      maxLeap: 3,
    );
    for (var seed = 0; seed < 60; seed++) {
      final degrees = generateDegrees(shape: shape, rng: Random(seed));
      for (var i = 1; i < degrees.length; i++) {
        expect((degrees[i] - degrees[i - 1]).abs(), lessThanOrEqualTo(3));
      }
    }
  });

  test('varsayılan olarak aynı nota peş peşe gelmez (söyleme modu netliği)', () {
    const shape = MelodyShape(
      noteCount: 6,
      degrees: [1, 2, 3, 4, 5],
      maxLeap: 2,
      endOnTonic: true,
    );
    for (var seed = 0; seed < 60; seed++) {
      final degrees = generateDegrees(shape: shape, rng: Random(seed));
      for (var i = 1; i < degrees.length; i++) {
        expect(degrees[i], isNot(degrees[i - 1]), reason: '$degrees');
      }
    }
  });

  test('nota sayısı ve derece havuzu sözleşmesi', () {
    for (var seed = 0; seed < 40; seed++) {
      final degrees = generateDegrees(shape: stepwise, rng: Random(seed));
      expect(degrees.length, 5);
      expect(degrees, everyElement(isIn(stepwise.degrees)));
    }
  });

  test('startOnTonic → ezgi evden başlar (ev kulağa kurulur)', () {
    for (var seed = 0; seed < 40; seed++) {
      expect(generateDegrees(shape: stepwise, rng: Random(seed)).first, 1);
    }
  });

  test('sıçrama kapalıyken yalnızca komşu derecelere adım atılır', () {
    for (var seed = 0; seed < 60; seed++) {
      final degrees = generateDegrees(shape: stepwise, rng: Random(seed));
      for (var i = 1; i < degrees.length; i++) {
        final jump = (degrees[i] - degrees[i - 1]).abs();
        expect(jump, lessThanOrEqualTo(1),
            reason: 'Sıçrama kapalıyken $degrees içinde atlama var');
      }
    }
  });

  test('sıçrama açıkken gerçekten sıçrar (ders zorlaşır)', () {
    const leaping = MelodyShape(
      noteCount: 5,
      degrees: [1, 3, 5, 8],
      maxLeap: 3,
    );
    var sawLeap = false;
    for (var seed = 0; seed < 40 && !sawLeap; seed++) {
      final degrees = generateDegrees(shape: leaping, rng: Random(seed));
      for (var i = 1; i < degrees.length; i++) {
        if ((degrees[i] - degrees[i - 1]).abs() > 1) sawLeap = true;
      }
    }
    expect(sawLeap, isTrue);
  });

  group('endOnTonic — "tonik" sezgisinin doğduğu yer', () {
    test('ezgi HER ZAMAN eve döner (adım adım, zorlama sıçrama yok)', () {
      const homing = MelodyShape(
        noteCount: 6,
        degrees: [1, 2, 3, 4, 5],
        endOnTonic: true,
      );
      for (var seed = 0; seed < 80; seed++) {
        final degrees = generateDegrees(shape: homing, rng: Random(seed));
        expect(degrees.last, 1, reason: 'Ezgi eve dönmeli: $degrees');
        for (var i = 1; i < degrees.length; i++) {
          expect((degrees[i] - degrees[i - 1]).abs(), lessThanOrEqualTo(1),
              reason: 'Eve dönerken sıçrama yapmamalı: $degrees');
        }
      }
    });

    test('sıçramalı ezgi de eve döner', () {
      const homing = MelodyShape(
        noteCount: 5,
        degrees: [1, 3, 5, 8],
        maxLeap: 3,
        endOnTonic: true,
      );
      for (var seed = 0; seed < 40; seed++) {
        expect(generateDegrees(shape: homing, rng: Random(seed)).last, 1);
      }
    });
  });

  test('geçersiz şekiller sessizce garip ezgi üretmez, hata verir', () {
    expect(
      () => generateDegrees(
        shape: const MelodyShape(noteCount: 3, degrees: []),
        rng: Random(1),
      ),
      throwsArgumentError,
    );
    expect(
      () => generateDegrees(
        // Tonik havuzda yokken eve dönmesi istenemez.
        shape: const MelodyShape(
          noteCount: 3,
          degrees: [2, 3, 4],
          startOnTonic: false,
          endOnTonic: true,
        ),
        rng: Random(1),
      ),
      throwsArgumentError,
    );
  });

  test('generateMelody dereceleri doğru perdelere çevirir', () {
    final melody = generateMelody(
      tonic: Note.fromName('C', 4),
      shape: const MelodyShape(noteCount: 3, degrees: [1, 2, 3]),
      rng: Random(3),
    );
    expect(melody.events.length, 3);
    expect(melody.tonic.label, 'C4');
    // Tüm notalar Do majör dizisinin ilk üç derecesinden olmalı.
    expect(
      melody.allNotes.map((n) => n.label),
      everyElement(isIn(['C4', 'D4', 'E4'])),
    );
  });

  test('başka evde aynı ezgi şekli üretilir (beceri taşınabilir)', () {
    final melody = generateMelody(
      tonic: Note.fromName('F', 3),
      shape: const MelodyShape(noteCount: 4, degrees: [1, 2, 3]),
      rng: Random(5),
    );
    expect(melody.tonic.label, 'F3');
    // Ezgi artık serbest bir dereceden başlar (çeşitlilik); ama tüm sesler
    // yeni evin dizisinden gelmeli — F majörün 1-2-3. dereceleri.
    expect(
      melody.allNotes.map((n) => n.label),
      everyElement(isIn(['F3', 'G3', 'A3'])),
    );
  });
}
