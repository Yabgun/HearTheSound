import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/features/harmony/harmony_round.dart';
import 'package:hear_the_sound/features/song/song_puzzle.dart';

// -----------------------------------------------------------------------------
// ŞARKI ÇÖZ — bulmaca üretiminin sözleşmeleri
//
// Armoni Kulağı'nda öğrenilen KÖK KURAL burada da geçerli: doğru cevap ÇALAN
// SESİN İÇİNDE olmalı. Ek olarak bu modun kendi vaadi var — şarkı kendini
// TEKRAR eder; kullanıcıya öğretilmek istenen sezgi bu, dolayısıyla formun
// gerçekten iddia edilen şey olması test edilir (yalancı içgörü, hiç içgörü
// olmamasından kötüdür).
// -----------------------------------------------------------------------------

void main() {
  SongDifficulty byId(String id) =>
      kSongDifficulties.firstWhere((d) => d.id == id);

  List<SongPuzzle> songs(SongDifficulty difficulty, {int seeds = 60}) => [
    for (var seed = 0; seed < seeds; seed++)
      generateSongPuzzle(difficulty: difficulty, rng: Random(seed)),
  ];

  group('şarkı iskeleti', () {
    test('ölçü sayısı zorluğun söylediği kadar', () {
      for (final difficulty in kSongDifficulties) {
        for (final song in songs(difficulty, seeds: 20)) {
          expect(song.barCount, difficulty.barCount);
          expect(song.bars.length, difficulty.barCount);
        }
      }
    });

    test('çalınan cümle ölçülerle birebir aynı (cevap seste var)', () {
      for (final song in songs(byId('medium'), seeds: 30)) {
        expect(song.phrase.events.length, song.barCount);
        for (var i = 0; i < song.barCount; i++) {
          expect(
            song.phrase.events[i].notes.map((n) => n.midi),
            song.barVoicing(i).map((n) => n.midi),
          );
        }
      }
    });

    test('tek ölçü sesi o ölçünün akorudur (takıldığın yeri dinle)', () {
      for (final song in songs(byId('easy'), seeds: 20)) {
        for (var i = 0; i < song.barCount; i++) {
          expect(song.barVoicing(i), bandVoicing(song.bars[i]));
        }
      }
    });
  });

  group('palet', () {
    test('benzersizdir ve şarkıdaki her akoru kapsar', () {
      for (final difficulty in kSongDifficulties) {
        for (final song in songs(difficulty, seeds: 20)) {
          expect(song.palette.toSet().length, song.palette.length);
          for (final chord in song.bars) {
            expect(song.palette, contains(chord));
          }
        }
      }
    });

    test('tuzak sayısı zorluğun söylediği kadar', () {
      for (final difficulty in kSongDifficulties) {
        for (final song in songs(difficulty, seeds: 20)) {
          final decoys = song.palette.toSet().difference(song.bars.toSet());
          expect(decoys.length, difficulty.decoyCount);
        }
      }
    });

    test('karışık gelir — sırayla dizmek şarkıyı çözmez', () {
      var sawShuffled = false;
      for (final song in songs(byId('medium'), seeds: 40)) {
        final inOrder = <String>[];
        for (final chord in song.bars) {
          if (!inOrder.contains(fullChordName(chord))) {
            inOrder.add(fullChordName(chord));
          }
        }
        final palette = song.palette.map(fullChordName).toList();
        if (palette.take(inOrder.length).join() != inOrder.join()) {
          sawShuffled = true;
        }
      }
      expect(sawShuffled, isTrue);
    });
  });

  // Modun asıl vaadi: "şarkılar kendini tekrar eder". Sonuç ekranı bunu
  // kullanıcıya SÖYLÜYOR — söylediği şey doğru olmak zorunda.
  group('form gerçekten iddia edilen şey', () {
    test('repeat: ikinci yarı birincinin tıpatıp aynısı', () {
      for (final song in songs(byId('medium'), seeds: 80)) {
        if (song.form != SongForm.repeat) continue;
        expect(song.bars.sublist(4), song.bars.sublist(0, 4));
      }
    });

    test('repeatVariedEnding: yalnızca SON ölçü farklı', () {
      for (final song in songs(byId('medium'), seeds: 80)) {
        if (song.form != SongForm.repeatVariedEnding) continue;
        expect(song.bars.sublist(4, 7), song.bars.sublist(0, 3));
        expect(song.bars[7], isNot(song.bars[3]));
      }
    });

    test('contrast: iki yarı aynı olamaz', () {
      for (final song in songs(byId('medium'), seeds: 80)) {
        if (song.form != SongForm.contrast) continue;
        expect(song.bars.sublist(4), isNot(song.bars.sublist(0, 4)));
      }
    });

    test('tek cümlelik zorlukta form her zaman single', () {
      for (final song in songs(byId('easy'), seeds: 30)) {
        expect(song.form, SongForm.single);
      }
    });

    test('çok ölçülü zorlukta ÜÇ form da çıkar (içgörü hep aynı olmaz)', () {
      final forms = {for (final song in songs(byId('medium'))) song.form};
      expect(forms, {
        SongForm.repeat,
        SongForm.repeatVariedEnding,
        SongForm.contrast,
      });
    });

    test('tekrar eden biçimler baskın — sezgi ancak sık yaşanırsa yerleşir', () {
      final all = songs(byId('medium'), seeds: 100);
      final repeating = all
          .where(
            (s) =>
                s.form == SongForm.repeat ||
                s.form == SongForm.repeatVariedEnding,
          )
          .length;
      expect(repeating, greaterThan(50));
    });
  });

  group('çeşitlilik ve ton', () {
    test('farklı şarkılar üretilir, hep aynısı değil', () {
      final distinct = {
        for (final song in songs(byId('medium')))
          song.bars.map(fullChordName).join('-'),
      };
      expect(distinct.length, greaterThanOrEqualTo(8));
    });

    test('kolay/orta sabit evde, zor her seferinde başka evde', () {
      final easyKeys = {
        for (final song in songs(byId('easy'), seeds: 30)) song.tonic.label,
      };
      expect(easyKeys, {'C4'});

      final hardKeys = {
        for (final song in songs(byId('hard'), seeds: 30)) song.tonic.label,
      };
      expect(hardKeys.length, greaterThan(2));
    });
  });

  group('çözüm kontrolü', () {
    test('doğru cevap ölçü ölçü doğrulanır', () {
      final song = generateSongPuzzle(
        difficulty: byId('medium'),
        rng: Random(7),
      );
      expect(
        checkSongSolution(puzzle: song, answer: song.bars),
        everyElement(isTrue),
      );
    });

    test('boş bırakılan ölçü yanlış sayılır (sessizce doğru olmaz)', () {
      final song = generateSongPuzzle(
        difficulty: byId('easy'),
        rng: Random(3),
      );
      final answer = List<Chord?>.of(song.bars)..[1] = null;
      final result = checkSongSolution(puzzle: song, answer: answer);
      expect(result[1], isFalse);
      expect(result[0], isTrue);
    });

    test('eksik uzunluktaki cevap çökmez, kalan ölçüler yanlış sayılır', () {
      final song = generateSongPuzzle(
        difficulty: byId('medium'),
        rng: Random(5),
      );
      final result = checkSongSolution(
        puzzle: song,
        answer: song.bars.take(2).toList(),
      );
      expect(result.length, song.barCount);
      expect(result.sublist(2), everyElement(isFalse));
    });
  });
}
