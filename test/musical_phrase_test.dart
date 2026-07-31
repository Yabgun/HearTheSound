import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/musical_phrase.dart';
import 'package:hear_the_sound/core/note.dart';

// Müzikal cümle modeli — teori derslerinin yeni uyaran birimi.
// Kilitlenen sözleşmeler: "evde bitti mi" kararı, blok transpoze (anlam korunur)
// ve zıtlık ikilisinin EŞİT SÜRE kuralı (kullanıcı süreyi değil perdeyi dinlesin).

void main() {
  final c4 = Note.fromName('C', 4);

  group('endsAtHome — "Bitti mi?" sorusunun doğru cevabı', () {
    test('tonikte biten cümle evdedir', () {
      final phrase = melodicPhrase(
        tonic: c4,
        semitoneOffsets: [0, 2, 4, 2, 0], // 1-2-3-2-1
      );
      expect(phrase.endsAtHome, isTrue);
    });

    test('yeden üstünde asılı kalan cümle evde DEĞİLDİR', () {
      final phrase = melodicPhrase(
        tonic: c4,
        semitoneOffsets: [0, 2, 4, 5, 7, 9, 11], // ...7. derecede durur
      );
      expect(phrase.endsAtHome, isFalse);
    });

    test('ÜST OKTAVDAKİ tonik de evdir (oktav farkı ev hissini bozmaz)', () {
      final phrase = melodicPhrase(
        tonic: c4,
        semitoneOffsets: [0, 4, 7, 12], // oktav yukarı toniğe varış
      );
      expect(phrase.endsAtHome, isTrue);
    });

    test('boş cümle evde sayılmaz (savunmacı)', () {
      const phrase = MusicalPhrase(events: [], tonic: Note(60));
      expect(phrase.endsAtHome, isFalse);
    });

    test('akor cümlesinde karar EN PES notaya (bas) göre verilir', () {
      final tonicChord = [c4, Note(c4.midi + 4), Note(c4.midi + 7)];
      final dominant = [Note(c4.midi + 7), Note(c4.midi + 11), Note(c4.midi + 14)];

      expect(
        chordPhrase(tonic: c4, chords: [dominant, tonicChord]).endsAtHome,
        isTrue,
      );
      expect(
        chordPhrase(tonic: c4, chords: [tonicChord, dominant]).endsAtHome,
        isFalse,
      );
    });
  });

  group('melodicPhrase kurulumu', () {
    test('offsetler tonikten doğru perdeleri üretir', () {
      final phrase = melodicPhrase(tonic: c4, semitoneOffsets: [0, 4, 7]);
      expect(
        phrase.allNotes.map((n) => n.label),
        ['C4', 'E4', 'G4'],
      );
    });

    test('ZITLIK İKİLİSİ SÖZLEŞMESİ: tüm olaylar eşit süre alır', () {
      // Son notayı uzatmak kullanıcının perdeyi değil SÜREYİ dinlemesine yol
      // açar ve öğrenilmesi gereken ipucunu yok eder. Bu test onu engeller.
      final resolved = melodicPhrase(tonic: c4, semitoneOffsets: [0, 2, 4, 0]);
      final hanging = melodicPhrase(tonic: c4, semitoneOffsets: [0, 2, 4, 2]);

      final beats = resolved.events.map((e) => e.beats).toSet();
      expect(beats, {1}, reason: 'Tüm olaylar aynı süre olmalı');
      expect(resolved.totalBeats, hanging.totalBeats,
          reason: 'İki versiyon aynı uzunlukta olmalı — tek fark PERDE');
      expect(resolved.events.length, hanging.events.length);
    });
  });

  group('transposedBy — anlam korunarak taşıma', () {
    test('tüm notalar ve tonik aynı miktarda kayar', () {
      final phrase = melodicPhrase(tonic: c4, semitoneOffsets: [0, 4, 7, 12]);
      final moved = phrase.transposedBy(5); // F majöre

      expect(moved.tonic.label, 'F4');
      expect(moved.allNotes.map((n) => n.label), ['F4', 'A4', 'C5', 'F5']);
    });

    test('taşıma "evde bitti mi" kararını DEĞİŞTİRMEZ', () {
      final resolved = melodicPhrase(tonic: c4, semitoneOffsets: [0, 2, 0]);
      final hanging = melodicPhrase(tonic: c4, semitoneOffsets: [0, 2, 7]);

      for (final shift in [-12, -5, 3, 7, 12]) {
        expect(resolved.transposedBy(shift).endsAtHome, isTrue);
        expect(hanging.transposedBy(shift).endsAtHome, isFalse);
      }
    });
  });

  test('chordPhrase akorları tek olay olarak tutar', () {
    final phrase = chordPhrase(
      tonic: c4,
      chords: [
        [c4, Note(c4.midi + 4), Note(c4.midi + 7)],
      ],
    );

    expect(phrase.events.single.isChord, isTrue);
    expect(phrase.events.single.notes.length, 3);
    expect(phrase.events.single.lowest.label, 'C4');
  });
}
