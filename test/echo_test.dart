import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/echo.dart';
import 'package:hear_the_sound/core/note.dart';

// Eko oyunu: uygulama çalar → kullanıcı TEKRARLAR. Bu dosya tekrarın nasıl
// puanlandığını kilitler. Kritik sözleşme: söyleme modunda oktav toleranslıdır
// (kullanıcı kendi ses aralığında söyler), tuş modunda değildir.

void main() {
  Note n(String name, int octave) => Note.fromName(name, octave);

  final target = [n('C', 4), n('E', 4), n('G', 4)];

  test('birebir doğru tekrar tam puandır', () {
    final result = compareEcho(target: target, attempt: target);
    expect(result.isPerfect, isTrue);
    expect(result.correctCount, 3);
    expect(result.accuracy, 1.0);
    expect(result.firstMistakeIndex, isNull);
  });

  test('yanlış nota yalnızca kendi pozisyonunu düşürür', () {
    final result = compareEcho(
      target: target,
      attempt: [n('C', 4), n('F', 4), n('G', 4)],
    );
    expect(result.matches, [true, false, true]);
    expect(result.correctCount, 2);
    expect(result.firstMistakeIndex, 1);
    expect(result.isPerfect, isFalse);
  });

  test('eksik kalan notalar yanlış sayılır (yarım bırakma tam puan almaz)', () {
    final result = compareEcho(target: target, attempt: [n('C', 4)]);
    expect(result.matches, [true, false, false]);
    expect(result.length, 3);
  });

  test('fazladan nota puanı şişirmez (hedef uzunluğu esastır)', () {
    final result = compareEcho(
      target: target,
      attempt: [...target, n('B', 4), n('D', 5)],
    );
    expect(result.length, 3);
    expect(result.isPerfect, isTrue);
  });

  group('oktav toleransı — söyleme modu', () {
    final octaveDown = [n('C', 3), n('E', 3), n('G', 3)];

    test('AÇIKKEN başka oktavda söylemek doğrudur', () {
      // Kadın/erkek ses farkı yüzünden kullanıcı çoğu zaman uygulamanın
      // çaldığı oktavı taklit edemez; önemli olan doğru perdeyi tutturması.
      final result = compareEcho(
        target: target,
        attempt: octaveDown,
        octaveTolerant: true,
      );
      expect(result.isPerfect, isTrue);
    });

    test('KAPALIYKEN (tuş modu) oktav da tutmalıdır', () {
      final result = compareEcho(target: target, attempt: octaveDown);
      expect(result.correctCount, 0);
    });

    test('tolerans yanlış notayı affetmez', () {
      final result = compareEcho(
        target: target,
        attempt: [n('C', 3), n('F', 3), n('G', 3)],
        octaveTolerant: true,
      );
      expect(result.matches, [true, false, true]);
    });
  });

  group('söylenen nota kabulü', () {
    test('doğru perde + akortta → kabul', () {
      expect(
        isSungNoteAccepted(
          reading: NoteReading(note: n('C', 3), cents: 12, frequency: 130),
          target: n('C', 4),
        ),
        isTrue,
      );
    });

    test('doğru perde ama çok pes/tiz → kabul EDİLMEZ', () {
      // Eşik PitchMeter'ın yeşil bölgesiyle aynı (±50 cent) — kullanıcının
      // ekranda gördüğü geri bildirimle puanlama birbirini tutsun.
      expect(
        isSungNoteAccepted(
          reading: NoteReading(note: n('C', 4), cents: 60, frequency: 270),
          target: n('C', 4),
        ),
        isFalse,
      );
    });

    test('yanlış perde → kabul EDİLMEZ', () {
      expect(
        isSungNoteAccepted(
          reading: NoteReading(note: n('D', 4), cents: 0, frequency: 293),
          target: n('C', 4),
        ),
        isFalse,
      );
    });
  });
}
