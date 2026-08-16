import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/harmony/harmony_chords.dart';
import 'package:hear_the_sound/features/harmony/harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ SORU ÜRETİMİ — sözleşmeler + ÇEŞİTLİLİK nöbetçisi
//
// EN ÖNEMLİ SÖZLEŞME (cihaz testinde pahalıya öğrenildi): doğru cevap ÇALAN
// SESİN İÇİNDE olmalı. Kullanıcı, cevabı duyulan sesten çıkarılamayan üç dersi
// ("Ev Neresi?", "Dinlendi mi?", "Sıradaki Akor") reddetti. Aşağıdaki testler
// kalan derslerin bu kuralı çiğnemediğini kilitler: her "bul/diz" sorusunda
// hedef, çalınan cümleden okunabilir olmalı.
//
// İkinci nöbetçi ÇEŞİTLİLİK: hem sesler hem CEVAPLAR dağılmalı. İki seçenekli
// sorularda cevap dağılımı bozulursa kullanıcı dinlemeden "hep aynısını"
// işaretleyerek geçer.
// -----------------------------------------------------------------------------

void main() {
  final c4 = Note.fromName('C', 4);

  /// Aynı soru tipini farklı tohumlarla üretir (deterministik).
  List<ChoiceRound> choices(
    HarmonyDrill drill, {
    List<int> degrees = const [1, 2, 3, 4, 5, 6],
    int seeds = 60,
  }) => [
    for (var seed = 0; seed < seeds; seed++)
      generateChoiceRound(
        drill: drill,
        tonic: c4,
        degrees: degrees,
        rng: Random(seed),
      ),
  ];

  List<FindRound> finds(
    HarmonyDrill drill, {
    List<int> degrees = const [1, 2, 4, 5, 6],
    int seeds = 60,
  }) => [
    for (var seed = 0; seed < seeds; seed++)
      generateFindRound(
        drill: drill,
        tonic: c4,
        degrees: degrees,
        rng: Random(seed),
      ),
  ];

  List<PatternRound> patterns({
    int length = 4,
    int decoyCount = 0,
    int seeds = 40,
  }) => [
    for (var seed = 0; seed < seeds; seed++)
      generatePatternRound(
        tonic: c4,
        rng: Random(seed),
        length: length,
        decoyCount: decoyCount,
      ),
  ];

  group('grup seslendirmesi — bas duyulabilir olmalı', () {
    test('bandVoicing basi bir oktav altta ikiler', () {
      final chord = chordForDegree(tonic: c4, degree: 1); // C4 E4 G4
      final voiced = bandVoicing(chord);
      expect(voiced.first.label, 'C3');
      expect(voiced.length, chord.notes.length + 1);
      // İkilenen ses akorun kendi basıdır → akorun kimliği değişmez.
      expect(voiced.first.pitchClass, chord.notes.first.pitchClass);
    });

    test('cümlenin en pes sesi hâlâ akorun basıdır', () {
      final phrase = bandPhrase(
        tonic: c4,
        chords: [
          chordForDegree(tonic: c4, degree: 5),
          chordForDegree(tonic: c4, degree: 1),
        ],
      );
      expect(bassLineOf(phrase).map((n) => n.name), ['G', 'C']);
    });
  });

  // Track'in kök sözleşmesi. Bir ders bunu çiğnerse kullanıcı "ne yaptığımı
  // anlamıyorum" der — bu testin varlık sebebi tam olarak o geri bildirim.
  group('KÖK KURAL: cevap çalan sesin İÇİNDE', () {
    test('bulunacak her hedef, duyulan bas hattından okunabilir', () {
      for (final drill in [HarmonyDrill.findBass, HarmonyDrill.bassLine]) {
        for (final round in finds(drill)) {
          final heard = bassLineOf(round.phrase).map((n) => n.pitchClass);
          for (final target in round.targets) {
            expect(
              heard,
              contains(target.pitchClass),
              reason: '$drill: hedef ${target.name} çalan seste yok',
            );
          }
        }
      }
    });

    test('dizilecek her akor gerçekten çalmıştır', () {
      for (final round in patterns()) {
        final heard = round.phrase.events
            .map((e) => e.notes.map((n) => n.midi).toSet())
            .toList();
        for (var i = 0; i < round.sequence.length; i++) {
          expect(
            heard[i].containsAll(bandVoicing(round.sequence[i]).map((n) => n.midi)),
            isTrue,
            reason: '${i + 1}. yuvanın doğru cevabı o anda çalmalı',
          );
        }
      }
    });
  });

  group('1 · Kaç Ses?', () {
    test('cevap gerçekten çalan ses sayısını anlatır', () {
      for (final round in choices(HarmonyDrill.howMany)) {
        final notes = round.phrase.events.single.notes;
        expect(notes.length, round.answer == 0 ? 1 : 2);
      }
    });

    test('tek ses ve iki ses DENGELİ gelir (işaretleyip geçilemez)', () {
      final answers = choices(HarmonyDrill.howMany).map((r) => r.answer);
      final two = answers.where((a) => a == 1).length;
      expect(two, greaterThan(10));
      expect(two, lessThan(50));
    });

    test('iki ses hiçbir zaman oktav değil (kulağa tek ses gelirdi)', () {
      for (final round in choices(HarmonyDrill.howMany)) {
        final notes = round.phrase.events.single.notes;
        if (notes.length == 2) {
          final gap = (notes[1].midi - notes[0].midi).abs();
          expect(gap % 12, isNot(0), reason: 'oktav/unison ayırt edilemez');
        }
      }
    });
  });

  group('2 · Değişti mi?', () {
    test('cevap akorların gerçekten farklı olmasıyla tutarlı', () {
      for (final round in choices(HarmonyDrill.changed)) {
        final events = round.phrase.events;
        expect(events.length, 2);
        final same =
            events[0].notes.map((n) => n.midi).join() ==
            events[1].notes.map((n) => n.midi).join();
        expect(round.answer, same ? 0 : 1);
      }
    });

    test('"aynı" ve "değişti" dengeli dağılır', () {
      final changed =
          choices(HarmonyDrill.changed).where((r) => r.answer == 1).length;
      expect(changed, greaterThan(10));
      expect(changed, lessThan(50));
    });
  });

  group('3 · Bas Nereye Gitti?', () {
    test('bas asla yerinde saymaz (cevapsız soru olamaz)', () {
      for (final round in choices(HarmonyDrill.bassDirection)) {
        final line = bassLineOf(round.phrase);
        expect(line.first.midi, isNot(line.last.midi));
      }
    });

    test('cevap basın GERÇEK yönünü söyler', () {
      for (final round in choices(HarmonyDrill.bassDirection)) {
        final line = bassLineOf(round.phrase);
        final wentUp = line.last.midi > line.first.midi;
        expect(round.answer, wentUp ? 0 : 1);
      }
    });

    test('iki yön de dengeli gelir', () {
      final up = choices(
        HarmonyDrill.bassDirection,
      ).where((r) => r.answer == 0).length;
      expect(up, greaterThan(10));
      expect(up, lessThan(50));
    });
  });

  group('4 · Bası Bul', () {
    test('tek hedef vardır ve o, çalan akorun basıdır', () {
      for (final round in finds(HarmonyDrill.findBass)) {
        expect(round.targets.length, 1);
        final bass = bassLineOf(round.phrase).single;
        expect(round.targets.single.pitchClass, bass.pitchClass);
      }
    });

    test('ÇEŞİTLİLİK: hedef havuzdaki tüm dereceleri dolaşır', () {
      final targets = {
        for (final round in finds(
          HarmonyDrill.findBass,
          degrees: const [1, 4, 5, 6],
        ))
          round.targets.single.name,
      };
      expect(targets, containsAll(['C', 'F', 'G', 'A']));
    });
  });

  group('5 · Bas Hattını Çıkar', () {
    test('hedefler çalan bas hattının TAMAMI ve AYNI SIRADA', () {
      for (final round in finds(HarmonyDrill.bassLine)) {
        expect(
          round.targets.map((n) => n.pitchClass),
          bassLineOf(round.phrase).map((n) => n.pitchClass),
        );
      }
    });

    test('hat tek sesten uzun (yoksa 4. dersin tekrarı olurdu)', () {
      for (final round in finds(HarmonyDrill.bassLine)) {
        expect(round.targets.length, greaterThan(1));
      }
    });

    test('ÇEŞİTLİLİK: farklı hatlar gelir, hep aynı hat değil', () {
      final lines = {
        for (final round in finds(HarmonyDrill.bassLine))
          round.targets.map((n) => n.name).join('-'),
      };
      expect(lines.length, greaterThanOrEqualTo(4));
    });
  });

  group('6-8 · Kalıbı Çöz', () {
    test('istenen uzunlukta kalıp üretilir', () {
      for (final round in patterns(length: 2)) {
        expect(round.sequence.length, 2);
        expect(round.phrase.events.length, 2);
      }
      for (final round in patterns()) {
        expect(round.sequence.length, 4);
        expect(round.phrase.events.length, 4);
      }
    });

    test('palet benzersizdir ve sıradaki her akoru kapsar', () {
      for (final round in patterns()) {
        expect(round.palette.toSet().length, round.palette.length);
        for (final chord in round.sequence) {
          expect(round.palette, contains(chord));
        }
      }
    });

    test('tuzaksız derste palette fazladan akor YOK', () {
      for (final round in patterns()) {
        expect(round.palette.toSet(), round.sequence.toSet());
      }
    });

    test('tuzaklı derste palette hiç çalmamış akorlar VAR', () {
      for (final round in patterns(decoyCount: 2)) {
        final decoys = round.palette.toSet().difference(round.sequence.toSet());
        expect(decoys.length, 2);
        // Tuzaklar tonun İÇİNDEN gelmeli: ton dışı akor kulağa hemen yanlış
        // gelir ve soruyu kolaylaştırırdı.
        for (final decoy in decoys) {
          expect(
            [
              for (var degree = 1; degree <= 7; degree++)
                chordForDegree(tonic: c4, degree: degree),
            ],
            contains(decoy),
          );
        }
      }
    });

    test('palet KARIŞIK gelir — sırayla dizmek cevabı vermez', () {
      var sawShuffled = false;
      for (final round in patterns()) {
        final inOrder = <String>[];
        for (final chord in round.sequence) {
          final name = shortChordName(chord);
          if (!inOrder.contains(name)) inOrder.add(name);
        }
        if (round.palette.map(shortChordName).join() != inOrder.join()) {
          sawShuffled = true;
        }
      }
      expect(sawShuffled, isTrue);
    });

    test('ÇEŞİTLİLİK: farklı kalıplar gelir', () {
      final four = {
        for (final round in patterns())
          round.sequence.map(shortChordName).join('-'),
      };
      expect(four.length, greaterThanOrEqualTo(3));

      final two = {
        for (final round in patterns(length: 2))
          round.sequence.map(shortChordName).join('-'),
      };
      expect(two.length, greaterThanOrEqualTo(4));
    });

    test('akor sembolleri okunur ve niteliği yansıtır', () {
      expect(shortChordName(chordForDegree(tonic: c4, degree: 1)), 'C');
      expect(shortChordName(chordForDegree(tonic: c4, degree: 6)), 'Am');
      expect(shortChordName(chordForDegree(tonic: c4, degree: 7)), 'B°');
    });
  });

  // Cihaz geri bildirimi: "bazı yerlerde F akoru C'den daha kalın çıkıyor" —
  // oktavsız etiket hangi sesin daha pes olduğunu söylemiyordu.
  group('etiketler oktavı taşır (hangi ses daha pes, okunabilsin)', () {
    test('akorun tam yazımı kök oktavını içerir', () {
      expect(fullChordName(chordForDegree(tonic: c4, degree: 1)), 'C4');
      expect(fullChordName(chordForDegree(tonic: c4, degree: 6)), 'Am4');
      final g4 = Note.fromName('G', 4);
      // Sol majörde 4. derece C5'tir: harf sırası "G, C" olsa da C DAHA TİZdir.
      // Etiket bunu söylemezse kullanıcı tam olarak yanılır.
      expect(fullChordName(chordForDegree(tonic: g4, degree: 4)), 'C5');
    });

    test('karıştırma anahtarı OKTAVSIZ kalır (doğruluk perde sınıfına bakar)', () {
      // shortChordName mistake key'lerde kullanılır: 'progression:C>F' iki
      // farklı oktavda aynı hatadır, oktav girerse istatistik parçalanır.
      expect(shortChordName(chordForDegree(tonic: Note.fromName('G', 4), degree: 4)), 'C');
    });

    test('tuş sırası etiketleriyle birlikte gerçekten yükselir', () {
      final pads = padNotesFor(
        tonic: Note.fromName('G', 4),
        degrees: const [1, 2, 4, 5, 6],
      );
      expect(pads.map((n) => n.label), ['G4', 'A4', 'C5', 'D5', 'E5']);
      // Perde sırası artan; harf sırası değil → oktav şart.
      for (var i = 1; i < pads.length; i++) {
        expect(pads[i].midi, greaterThan(pads[i - 1].midi));
      }
    });
  });

  group('ev değişimi (varyKey) ve tuş sırası', () {
    test('varyKey kapalıyken ev sabit, açıkken gezinir', () {
      final fixed = {
        for (var seed = 0; seed < 30; seed++)
          harmonyTonic(varyKey: false, rng: Random(seed)).label,
      };
      expect(fixed, {'C4'});

      final varied = {
        for (var seed = 0; seed < 30; seed++)
          harmonyTonic(varyKey: true, rng: Random(seed)).label,
      };
      expect(varied.length, greaterThan(2));
    });

    test('tuş sırası havuzun dereceleri, pesten tize', () {
      final pads = padNotesFor(tonic: c4, degrees: const [5, 1, 4]);
      expect(pads.map((n) => n.label), ['C4', 'F4', 'G4']);
    });
  });

  group('yanlış ekrana yanlış soru gitmez', () {
    test('bas bulma tipi iki seçenekli üretimde hata verir', () {
      expect(
        () => generateChoiceRound(
          drill: HarmonyDrill.bassLine,
          tonic: c4,
          degrees: const [1, 4, 5],
          rng: Random(1),
        ),
        throwsArgumentError,
      );
    });

    test('algı tipi bas bulma üretiminde hata verir', () {
      expect(
        () => generateFindRound(
          drill: HarmonyDrill.changed,
          tonic: c4,
          degrees: const [1, 4, 5],
          rng: Random(1),
        ),
        throwsArgumentError,
      );
    });

    test('boş derece havuzu sessizce garip soru üretmez', () {
      expect(
        () => generateChoiceRound(
          drill: HarmonyDrill.howMany,
          tonic: c4,
          degrees: const [],
          rng: Random(1),
        ),
        throwsArgumentError,
      );
    });

    test('desteklenmeyen kalıp uzunluğu sessizce geçilmez', () {
      expect(
        () => generatePatternRound(tonic: c4, rng: Random(1), length: 3),
        throwsArgumentError,
      );
    });
  });
}
