import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_round.dart';

// -----------------------------------------------------------------------------
// AKOR SORU ÜRETİMİ — sözleşmeler + ÇEŞİTLİLİK nöbetçisi
//
// Track'in tek kazanımı: DUYDUĞUN AKORU ÇALABİLMEK. Cihaz testinde bildirilen
// üç somut kusurun her biri burada teste bağlandı:
//   • "cevap şıklarda yok" → tuş sırası akorun HER sesini içermeli,
//   • "majör akor nasıl kurulur bilmiyorum" → tarif SAYILABİLİR olmalı,
//   • "amaç eksik" → kurma sorularında hedef, akorun kendi sesleridir.
// -----------------------------------------------------------------------------

void main() {
  const majorMinor = [ChordQuality.major, ChordQuality.minor];
  const fourColors = [
    ChordQuality.major,
    ChordQuality.minor,
    ChordQuality.diminished,
    ChordQuality.augmented,
  ];

  List<ChordChoiceRound> choices(
    ChordDrill drill, {
    List<ChordQuality> qualities = majorMinor,
    int seeds = 60,
  }) => [
    for (var seed = 0; seed < seeds; seed++)
      generateChordChoice(drill: drill, qualities: qualities, rng: Random(seed)),
  ];

  List<ChordProduceRound> produces({
    List<ChordQuality> qualities = majorMinor,
    bool colorIsHeard = true,
    int seeds = 60,
  }) => [
    for (var seed = 0; seed < seeds; seed++)
      generateChordProduce(
        qualities: qualities,
        colorIsHeard: colorIsHeard,
        rng: Random(seed),
      ),
  ];

  group('akorun TARİFİ — "nasıl kurulur" öğretilebilir olmalı', () {
    test('tarif sayılabilir adımlar verir (tanım değil)', () {
      // Kromatik tuş sırasında uygulanabilmesi için tarif, ardışık ses
      // aralıkları olmalı: majör 4+3, minör 3+4, eksik 3+3, artık 4+4.
      expect(chordRecipe(ChordQuality.major), [4, 3]);
      expect(chordRecipe(ChordQuality.minor), [3, 4]);
      expect(chordRecipe(ChordQuality.diminished), [3, 3]);
      expect(chordRecipe(ChordQuality.augmented), [4, 4]);
    });

    test('tarif akorun gerçek seslerini üretir', () {
      for (final quality in fourColors) {
        final chord = Chord(Note.fromName('C', 4), quality);
        var midi = chord.root.midi;
        final built = [midi];
        for (final step in chordRecipe(quality)) {
          midi += step;
          built.add(midi);
        }
        expect(built, chord.notes.map((n) => n.midi).toList());
      }
    });

    test('her rengin GÖRÜNEN adı hem hissi hem terimi taşır', () {
      // "Gergin ne demek bilmiyorum" geri bildirimi: his tek başına boşlukta
      // kalıyordu, terim tek başına ezber oluyordu — ikisi birlikte durmalı.
      for (final quality in fourColors) {
        final name = chordColorName(quality);
        expect(name, contains('('));
        expect(name, isNot(quality.label));
      }
    });
  });

  group('1 · Aynısını Bul (eşleştirme)', () {
    test('şıklar DİNLENEBİLİR ve aynı kökte iki renktir', () {
      for (final round in choices(ChordDrill.match)) {
        final options = round.optionChords!;
        expect(options.length, 2);
        expect(options[0].root.midi, options[1].root.midi);
        expect(
          {options[0].quality, options[1].quality},
          {ChordQuality.major, ChordQuality.minor},
        );
      }
    });

    test('doğru şık, çalan akorun TA KENDİSİDİR', () {
      for (final round in choices(ChordDrill.match)) {
        final heard = round.phrase.events.single.notes.map((n) => n.midi);
        expect(round.optionChords![round.answer].notes.map((n) => n.midi), heard);
      }
    });

    test('doğru cevap iki konuma da dengeli dağılır', () {
      final first = choices(
        ChordDrill.match,
        seeds: 120,
      ).where((r) => r.answer == 0);
      expect(first.length, greaterThan(30));
      expect(first.length, lessThan(90));
    });
  });

  group('2 / 6 · algı soruları', () {
    /// Çalan seslerden akorun niteliğini geri çözer (cevabın bayrağa değil
    /// SESE bakarak doğru olduğunu kanıtlar).
    ChordQuality qualityOf(List<int> midis) {
      final intervals = [for (final m in midis) m - midis.first];
      return ChordQuality.values.firstWhere(
        (q) => q.intervals.toString() == intervals.toString(),
      );
    }

    test('renk cevabı çalan akorla tutarlı', () {
      for (final round in choices(ChordDrill.color)) {
        final midis = round.phrase.events.single.notes
            .map((n) => n.midi)
            .toList();
        expect(round.optionKeys[round.answer], colorKeyOf(qualityOf(midis)));
      }
    });

    test('"üç mü dört mü" gerçekten ses sayısını sorar', () {
      final rounds = choices(
        ChordDrill.countTones,
        qualities: const [
          ChordQuality.major,
          ChordQuality.minor,
          ChordQuality.dominant7,
          ChordQuality.major7,
          ChordQuality.minor7,
        ],
      );
      for (final round in rounds) {
        final count = round.phrase.events.single.notes.length;
        expect(round.optionKeys[round.answer], count == 3 ? 'three' : 'four');
      }
      final four = rounds.where((r) => r.optionKeys[r.answer] == 'four').length;
      expect(four, greaterThan(10));
      expect(four, lessThan(50));
    });
  });

  group('3-5-7 · Akoru Kur', () {
    test('hedef akorun kendi sesleridir', () {
      for (final round in produces(qualities: fourColors)) {
        expect(round.targets, round.chord.notes);
        expect(round.targets.length, 3);
      }
    });

    test('renk KULAKLA bulunacaksa akorun tamamı çalar', () {
      for (final round in produces()) {
        expect(round.phrase.events.single.notes.length, 3);
        expect(round.colorIsHeard, isTrue);
      }
    });

    test('renk EKRANDA yazıyorsa yalnızca kök çalar (taklit değil inşa)', () {
      for (final round in produces(colorIsHeard: false)) {
        expect(round.phrase.events.single.notes.single, round.chord.root);
        expect(round.colorIsHeard, isFalse);
      }
    });

    test('ders havuzundaki her renk çıkar', () {
      final qualities = {
        for (final round in produces(qualities: fourColors, seeds: 120))
          round.chord.quality,
      };
      expect(qualities, fourColors.toSet());
    });

    test('ÇEŞİTLİLİK: kökler dolaşır', () {
      final roots = {for (final round in produces()) round.chord.root.name};
      expect(roots.length, greaterThanOrEqualTo(4));
    });
  });

  // Cihazda bildirilen gerçek hata: çevrimli akorda tepe sesi kök+12'ye
  // çıkıyordu ama tuş sırası kök..kök+11'di → doğru cevap ekranda YOKTU.
  group('tuş sırası akorun HER sesini içerir', () {
    test('kromatik ve oktavı kapsar (13 tuş)', () {
      final pads = chromaticPadsFrom(Note.fromName('C', 4));
      expect(pads.length, 13);
      for (var i = 1; i < pads.length; i++) {
        expect(pads[i].midi - pads[i - 1].midi, 1);
      }
    });

    test('her kurma sorusunda hedeflerin hepsi tuşta bulunur', () {
      for (final round in produces(qualities: fourColors, seeds: 120)) {
        final pads = chromaticPadsFrom(round.chord.root).map((n) => n.midi);
        for (final target in round.targets) {
          expect(
            pads,
            contains(target.midi),
            reason: 'hedef ${target.label} tuş sırasında yok',
          );
        }
      }
    });
  });

  group('ders sözleşmeleri', () {
    test('her ders üretilebilir bir soru tanımlar', () {
      for (final lesson in chordLessons) {
        expect(
          () => lesson.isProduction
              ? generateChordProduce(
                  qualities: lesson.qualities,
                  colorIsHeard: lesson.colorIsHeard,
                  rng: Random(1),
                )
              : generateChordChoice(
                  drill: lesson.drill,
                  qualities: lesson.qualities,
                  rng: Random(1),
                ),
          returnsNormally,
          reason: '${lesson.id} üretilemiyor',
        );
      }
    });

    test('REHBERLİ ders önce gelir, sınav sonra', () {
      // "Nasıl kurulur bilmiyorum" geri bildirimi: tarif önce rehberli
      // uygulanmalı (renk yazar + sıradaki tuş işaretlenir), sonra rehber
      // kalkmalı. Sıra bozulursa ders yine boşlukta bırakır.
      final ids = [for (final l in chordLessons) l.id];
      final byId = {for (final l in chordLessons) l.id: l};
      expect(byId['ch_third']!.guided, isTrue);
      expect(byId['ch_third']!.colorIsHeard, isFalse);
      expect(byId['ch_build']!.guided, isFalse);
      expect(byId['ch_build']!.colorIsHeard, isTrue);
      expect(ids.indexOf('ch_third'), lessThan(ids.indexOf('ch_build')));
    });

    test('gergin renkler önce KURULUR, adı sonra rozette gelir', () {
      final tense = chordLessons.firstWhere((l) => l.id == 'ch_tense');
      expect(tense.isProduction, isTrue);
      expect(tense.qualities, contains(ChordQuality.diminished));
      expect(tense.qualities, contains(ChordQuality.augmented));
      expect(tense.badge, isNotNull);
    });

    test('üretim dersleri ile algı dersleri karışmaz', () {
      expect(
        () => generateChordChoice(
          drill: ChordDrill.build,
          qualities: majorMinor,
          rng: Random(1),
        ),
        throwsArgumentError,
      );
    });

    test('her seçenek anahtarının çevirisi ve ikonu var', () {
      for (final key in [
        'soundA',
        'soundB',
        'bright',
        'dark',
        'three',
        'four',
      ]) {
        expect(chordOptionLabel(key), isNot(key));
        expect(chordOptionIcon(key), isNotNull);
      }
    });
  });
}
