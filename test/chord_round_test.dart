import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_round.dart';

// -----------------------------------------------------------------------------
// AKOR SORU ÜRETİMİ — sözleşmeler + ÇEŞİTLİLİK nöbetçisi
//
// Track'in yeni işi: akorun RENGİ + o rengi ÜRETEBİLMEK. Armoni'de pahalıya
// öğrenilen kök kural burada da geçerli — doğru cevap çalan sesin İÇİNDE
// olmalı; üretim derslerinde hedef, duyulan akorun kendi notalarından biri
// olmak zorunda.
// -----------------------------------------------------------------------------

void main() {
  List<ChordChoiceRound> choices(ChordDrill drill, {int seeds = 60}) => [
    for (var seed = 0; seed < seeds; seed++)
      generateChordChoice(drill: drill, rng: Random(seed)),
  ];

  List<ChordProduceRound> produces(ChordDrill drill, {int seeds = 60}) => [
    for (var seed = 0; seed < seeds; seed++)
      generateChordProduce(drill: drill, rng: Random(seed)),
  ];

  group('1 · Hangisi Parlak?', () {
    test('iki akor AYNI kökte — fark yalnızca üçlüde', () {
      for (final round in choices(ChordDrill.brighter)) {
        final events = round.phrase.events;
        expect(events.length, 2);
        expect(events[0].lowest.midi, events[1].lowest.midi);
        // Üç sesin ikisi ortak: tek nota farkı.
        final a = events[0].notes.map((n) => n.midi).toSet();
        final b = events[1].notes.map((n) => n.midi).toSet();
        expect(a.intersection(b).length, 2);
      }
    });

    test('doğru cevap gerçekten MAJÖR olanı gösterir', () {
      for (final round in choices(ChordDrill.brighter)) {
        final notes = round.phrase.events[round.answer].notes;
        // Majör üçlüde kök→üçlü mesafesi 4 yarım ses (minörde 3).
        expect(notes[1].midi - notes[0].midi, 4);
      }
    });

    test('doğru cevap iki konuma da dengeli dağılır', () {
      final first = choices(ChordDrill.brighter).where((r) => r.answer == 0);
      expect(first.length, greaterThan(10));
      expect(first.length, lessThan(50));
    });
  });

  group('2 / 6 / 7 · algı soruları', () {
    /// Çalan seslerden akorun niteliğini geri çözer (cevabın SESLE tutarlı
    /// olduğunu bayrağa değil, duyulan şeye bakarak doğrular).
    ChordQuality qualityOf(List<int> midis) {
      final intervals = [for (final m in midis) m - midis.first];
      return ChordQuality.values.firstWhere(
        (q) => q.intervals.toString() == intervals.toString(),
      );
    }

    test('cevap çalan akorun gerçek rengiyle tutarlı', () {
      for (final drill in [ChordDrill.color, ChordDrill.tense]) {
        for (final round in choices(drill)) {
          final midis = round.phrase.events.single.notes
              .map((n) => n.midi)
              .toList();
          expect(round.optionKeys[round.answer], colorKeyOf(qualityOf(midis)));
        }
      }
    });

    test('"üç mü dört mü" gerçekten ses sayısını sorar', () {
      for (final round in choices(ChordDrill.countTones)) {
        final count = round.phrase.events.single.notes.length;
        expect(round.optionKeys[round.answer], count == 3 ? 'three' : 'four');
      }
    });

    test('üç ve dört sesli akorlar dengeli gelir', () {
      final four = choices(
        ChordDrill.countTones,
      ).where((r) => r.optionKeys[r.answer] == 'four').length;
      expect(four, greaterThan(10));
      expect(four, lessThan(50));
    });

    test('gergin renklerde dört şık da doğru cevap olarak çıkar', () {
      final answers = {
        for (final round in choices(ChordDrill.tense, seeds: 120))
          round.optionKeys[round.answer],
      };
      expect(answers, {'bright', 'dark', 'tense', 'floating'});
    });

    test('capstone öğrenilen soru tiplerini KARIŞTIRIR', () {
      final shapes = {
        for (final round in choices(ChordDrill.master, seeds: 120))
          round.optionKeys.join(','),
      };
      // Dokuz şıklı dev bir etiketleme ekranı yerine, öğrenilen soru tipleri
      // dönüşümlü gelir → en az iki farklı şık kümesi görünmeli.
      expect(shapes.length, greaterThanOrEqualTo(2));
    });
  });

  group('3 / 4 · bulunacak ses akorun İÇİNDE', () {
    test('üçlü aranırken hedef akorun ortadaki sesidir', () {
      for (final round in produces(ChordDrill.findThird)) {
        expect(round.targets.length, 1);
        expect(round.targets.single, round.chord.notes[1]);
        // Majörde 4, minörde 3 yarım ses — rengi veren tek ses.
        final gap = round.targets.single.midi - round.chord.notes.first.midi;
        expect(gap, anyOf(3, 4));
      }
    });

    test('hem majör hem minör üçlü hedef olur', () {
      final gaps = {
        for (final round in produces(ChordDrill.findThird))
          round.targets.single.midi - round.chord.notes.first.midi,
      };
      expect(gaps, {3, 4});
    });

    test('tepe aranırken hedef akorun EN TİZ sesidir', () {
      for (final round in produces(ChordDrill.findTop)) {
        expect(round.targets.single, round.chord.notes.last);
      }
    });

    test('tepe sesi çevrimle DEĞİŞİR (kapalı pozisyonda tahmin edilirdi)', () {
      final gaps = {
        for (final round in produces(ChordDrill.findTop))
          round.targets.single.midi - round.chord.root.midi,
      };
      expect(
        gaps.length,
        greaterThan(1),
        reason: 'tepe hep beşli olsaydı soru kulak sorusu olmazdı',
      );
    });

    test('hedef her zaman çalan seste geçer', () {
      for (final drill in [ChordDrill.findThird, ChordDrill.findTop]) {
        for (final round in produces(drill)) {
          final heard = round.phrase.events
              .expand((e) => e.notes)
              .map((n) => n.pitchClass);
          expect(heard, contains(round.targets.single.pitchClass));
        }
      }
    });
  });

  group('5 · Akoru Kur', () {
    test('yalnızca KÖK çalar — akorun tamamı çalsa taklit olurdu', () {
      for (final round in produces(ChordDrill.buildChord)) {
        expect(round.phrase.events.single.notes.length, 1);
        expect(round.phrase.events.single.notes.single, round.chord.root);
      }
    });

    test('hedef akorun üç sesi, sırayla', () {
      for (final round in produces(ChordDrill.buildChord)) {
        expect(round.targets, round.chord.notes);
        expect(round.targets.length, 3);
      }
    });

    test('kurulacak renk kullanıcıya söylenmek üzere taşınır', () {
      final qualities = {
        for (final round in produces(ChordDrill.buildChord)) round.buildQuality,
      };
      expect(qualities, {ChordQuality.major, ChordQuality.minor});
    });
  });

  group('çeşitlilik ve tuş sırası', () {
    test('kökler dolaşır — tek akorda takılı kalmaz', () {
      final roots = {
        for (final round in produces(ChordDrill.findThird))
          round.chord.root.name,
      };
      expect(roots.length, greaterThanOrEqualTo(4));
    });

    test('tuş sırası kromatik bir oktav — minör üçlü de tuşta olmalı', () {
      // Diyatonik havuz yetmezdi: minör üçlü çoğu tonda dizinin dışında kalır.
      final pads = chromaticPadsFrom(Note.fromName('C', 4));
      expect(pads.length, 12);
      for (var i = 1; i < pads.length; i++) {
        expect(pads[i].midi - pads[i - 1].midi, 1);
      }
    });
  });

  group('ders sözleşmeleri', () {
    test('her ders üretilebilir bir soru tanımlar', () {
      for (final lesson in chordLessons) {
        expect(
          () => lesson.isProduction
              ? generateChordProduce(drill: lesson.drill, rng: Random(1))
              : generateChordChoice(drill: lesson.drill, rng: Random(1)),
          returnsNormally,
          reason: '${lesson.id} üretilemiyor',
        );
      }
    });

    test('üretim dersleri ile algı dersleri karışmaz', () {
      expect(
        () => generateChordChoice(drill: ChordDrill.findThird, rng: Random(1)),
        throwsArgumentError,
      );
      expect(
        () => generateChordProduce(drill: ChordDrill.color, rng: Random(1)),
        throwsArgumentError,
      );
    });

    test('her seçenek anahtarının çevirisi ve ikonu var', () {
      for (final key in [
        'first',
        'second',
        'bright',
        'dark',
        'tense',
        'floating',
        'three',
        'four',
      ]) {
        expect(chordOptionLabel(key), isNot(key));
        expect(chordOptionIcon(key), isNotNull);
      }
    });
  });
}
