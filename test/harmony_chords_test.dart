import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/harmony/harmony_chords.dart';

// Armoni çekirdeği. Kuzey yıldızı "duyunca akorları çıkarmak" olduğu için
// buradaki sözleşmelerin ikisi kritik: (a) derecelerin akor niteliği doğru
// kurulmalı, (b) BAS hattı doğru okunmalı — akor çıkarmanın en pratik yolu.

void main() {
  final c4 = Note.fromName('C', 4);

  test('majör tonalitede derecelerin nitelikleri doğru', () {
    expect(majorKeyChordQuality(1), ChordQuality.major);
    expect(majorKeyChordQuality(4), ChordQuality.major);
    expect(majorKeyChordQuality(5), ChordQuality.major);
    expect(majorKeyChordQuality(2), ChordQuality.minor);
    expect(majorKeyChordQuality(3), ChordQuality.minor);
    expect(majorKeyChordQuality(6), ChordQuality.minor);
    expect(majorKeyChordQuality(7), ChordQuality.diminished);
    expect(() => majorKeyChordQuality(8), throwsArgumentError);
  });

  test('Do majörde dereceler doğru akorları verir', () {
    expect(chordForDegree(tonic: c4, degree: 1).root.label, 'C4');
    expect(chordForDegree(tonic: c4, degree: 4).root.label, 'F4');
    expect(chordForDegree(tonic: c4, degree: 5).root.label, 'G4');
    expect(chordForDegree(tonic: c4, degree: 6).root.label, 'A4');
    expect(chordForDegree(tonic: c4, degree: 6).quality, ChordQuality.minor);
  });

  test('başka bir evde aynı ilişkiler korunur (beceri taşınabilir)', () {
    final g3 = Note.fromName('G', 3);
    expect(chordForDegree(tonic: g3, degree: 1).root.label, 'G3');
    expect(chordForDegree(tonic: g3, degree: 4).root.label, 'C4');
    expect(chordForDegree(tonic: g3, degree: 5).root.label, 'D4');
    // Nitelikler dereceye bağlıdır, tonaliteye değil.
    expect(chordForDegree(tonic: g3, degree: 2).quality, ChordQuality.minor);
  });

  group('yaygın kalıplar', () {
    test('hepsi geçerli derecelerden oluşur ve benzersiz id taşır', () {
      final ids = <String>{};
      for (final pattern in kCommonProgressions) {
        expect(ids.add(pattern.id), isTrue, reason: 'yinelenen id ${pattern.id}');
        expect(pattern.degrees, isNotEmpty);
        expect(pattern.degrees, everyElement(inInclusiveRange(1, 7)));
      }
    });

    test('"dört akorlu şarkı" kalıbı listede', () {
      expect(
        kCommonProgressions.map((p) => p.id),
        contains('I-V-vi-IV'),
      );
    });
  });

  test('progressionPhrase her akoru tek olay olarak dizer', () {
    final phrase = progressionPhrase(tonic: c4, degrees: [1, 4, 5, 1]);
    expect(phrase.events.length, 4);
    expect(phrase.events.every((e) => e.isChord), isTrue);
    expect(phrase.tonic.label, 'C4');
    // Kalıp evde bitiyor → "kapandı" hissi.
    expect(phrase.endsAtHome, isTrue);
  });

  group('bas hattı — akor çıkarmanın iskeleti', () {
    test('bassLineOf her akorun EN PES notasını verir', () {
      final phrase = progressionPhrase(tonic: c4, degrees: [1, 4, 5]);
      expect(
        bassLineOf(phrase).map((n) => n.name),
        ['C', 'F', 'G'],
      );
    });

    test('bassDirection yönü doğru okur', () {
      final i = chordForDegree(tonic: c4, degree: 1); // C
      final iv = chordForDegree(tonic: c4, degree: 4); // F (yukarı)
      expect(bassDirection(i, iv), 1);
      expect(bassDirection(iv, i), -1);
      expect(bassDirection(i, i), 0);
    });

    test('çevrim basi değiştirir — yön kararı buna duyarlıdır', () {
      final root = chordForDegree(tonic: c4, degree: 1);
      final firstInv = chordForDegree(tonic: c4, degree: 1, inversion: 1);
      // Aynı akor ama bası farklı → yön sıfır olmamalı.
      expect(bassDirection(root, firstInv), isNot(0));
    });
  });
}
