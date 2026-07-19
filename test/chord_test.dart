import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/core/note.dart';

Chord c(String root, ChordQuality q, {int inversion = 0}) =>
    Chord(Note.fromName(root, 4), q, inversion: inversion);

void main() {
  group('Yedili akorlar (4 nota)', () {
    test('dominant7 notaları [0,4,7,10]', () {
      final notes = c('C', ChordQuality.dominant7).notes.map((n) => n.label);
      expect(notes, ['C4', 'E4', 'G4', 'A#4']);
    });
    test('major7 ve minor7 doğru', () {
      expect(c('C', ChordQuality.major7).notes.map((n) => n.midi), [
        60,
        64,
        67,
        71,
      ]);
      expect(c('C', ChordQuality.minor7).notes.map((n) => n.midi), [
        60,
        63,
        67,
        70,
      ]);
    });
    test('isSeventh 4 notada true, üçlüde false', () {
      expect(ChordQuality.dominant7.isSeventh, isTrue);
      expect(ChordQuality.major.isSeventh, isFalse);
    });
  });

  group('Akor çevrimleri', () {
    test('C majör kapalı = C-E-G', () {
      expect(c('C', ChordQuality.major).notes.map((n) => n.label), [
        'C4',
        'E4',
        'G4',
      ]);
    });
    test('1. çevrim: 3\'lü bası (E-G-C)', () {
      final n = c('C', ChordQuality.major, inversion: 1).notes;
      expect(n.map((e) => e.label), ['E4', 'G4', 'C5']);
    });
    test('2. çevrim: 5\'li bası (G-C-E)', () {
      final n = c('C', ChordQuality.major, inversion: 2).notes;
      expect(n.map((e) => e.label), ['G4', 'C5', 'E5']);
    });
    test('çevrim etiketi ve eşitlik', () {
      // Etiketler aktif içerik diline göre çözülür: EN varsayılan, TR seçilince
      // Türkçe. İki dili de doğrula, sonra varsayılana dön.
      ContentLocale.code = 'en';
      expect(
        c('C', ChordQuality.major, inversion: 1).label,
        'C Major · 1st inversion',
      );
      ContentLocale.code = 'tr';
      expect(
        c('C', ChordQuality.major, inversion: 1).label,
        'C Majör · 1. çevrim',
      );
      ContentLocale.code = 'en';
      expect(
        c('C', ChordQuality.major, inversion: 0),
        isNot(c('C', ChordQuality.major, inversion: 1)),
      );
    });
  });
}
