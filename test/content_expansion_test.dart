import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/function/function_lesson.dart';
import 'package:hear_the_sound/features/intervals/interval_lesson.dart';
import 'package:hear_the_sound/features/progression/progression_lesson.dart';

// -----------------------------------------------------------------------------
// İÇERİK GENİŞLETME (A7–A9) — yeni derslerin sözleşmeleri
//
// iv5–iv6 (harmonik aralıklar), ch11–ch12 (yeni kökler), fn3/pr3 (D Majör).
// Kural: her yeni ders kavram kartıyla gelir; harmonik bayrak doğru derslerde
// açık; D Majör transferi blok halinde ve doğru notalara taşınır.
// -----------------------------------------------------------------------------

void main() {
  group('harmonik aralık dersleri (iv5–iv6)', () {
    test('yalnızca iv5 ve iv6 harmonik işaretli', () {
      final byId = {for (final l in intervalLessons) l.id: l};
      expect(byId.keys, containsAll(['iv1', 'iv4', 'iv5', 'iv6']));
      expect(byId['iv5']!.harmonic, isTrue);
      expect(byId['iv6']!.harmonic, isTrue);
      for (final id in ['iv1', 'iv2', 'iv3', 'iv4']) {
        expect(byId[id]!.harmonic, isFalse, reason: '$id melodik kalmalı');
      }
    });

    test(
      'harmonik havuzlar geçerli aralıklardan oluşur ve kavram kartlıdır',
      () {
        for (final id in ['iv5', 'iv6']) {
          final lesson = intervalLessons.firstWhere((l) => l.id == id);
          expect(lesson.concept, isNotNull, reason: 'kural: kavram kartı şart');
          for (final interval in lesson.pool) {
            expect(interval.semitones, inInclusiveRange(1, 12));
          }
        }
      },
    );
  });

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

  group('D Majör transferi (fn3/pr3)', () {
    test('fn3 tüm dereceleri D Majör merkezine taşır', () {
      final fn3 = functionLessons.firstWhere((l) => l.id == 'fn3');
      expect(fn3.key, MajorKey.d);
      expect(fn3.concept, isNotNull);

      final inD = fn3.inKey(fn3.key);
      final byRoman = {for (final d in inD.pool) d.roman: d};
      expect(byRoman['I']!.chord.root.label, 'D4');
      expect(byRoman['IV']!.chord.root.label, 'G4');
      expect(byRoman['V']!.chord.root.label, 'A4');
      expect(byRoman['V']!.function, HarmonicFunction.dominant);
    });

    test('pr3 kalıpları D Majörde doğru akor zincirini verir', () {
      final pr3 = progressionLessons.firstWhere((l) => l.id == 'pr3');
      expect(pr3.key, MajorKey.d);
      expect(pr3.concept, isNotNull);
      expect(pr3.pool.length, 4);

      final inD = pr3.inKey(pr3.key);
      final cadence = inD.pool.firstWhere((p) => p.name == 'I – IV – V – I');
      expect(cadence.chordChain, 'D – G – A – D');
      // Roman kimliği tonaliteden bağımsız kalır (tanıma şıkları buna dayanır).
      expect(cadence.name, 'I – IV – V – I');
    });
  });
}
