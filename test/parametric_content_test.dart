import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';

// Parametrik içerik — beşler çemberi (MajorKey) + akor nitelik capstone.
//
// NOT: "Tonalite Yolculuğu" (üretilen işlev/ilerleme dersleri) testleri
// kaldırıldı; o track müfredattan çıkarıldı. MajorKey çekirdekte kalıyor çünkü
// ezgi/akor içeriğini başka tonlara taşımak hâlâ kullanılıyor.

void main() {
  group('MajorKey — beşler çemberi genişlemesi', () {
    test('yeni merkezlerin C’ye uzaklığı doğru', () {
      expect(MajorKey.a.semitonesFromC, 9);
      expect(MajorKey.e.semitonesFromC, 4);
      expect(MajorKey.f.semitonesFromC, 5);
    });

    test('tonicAtOctave doğru perdeyi verir', () {
      expect(MajorKey.a.tonicAtOctave(4).midi, Note.fromName('A', 4).midi);
      expect(MajorKey.f.tonicAtOctave(3).midi, Note.fromName('F', 3).midi);
    });
  });

  group('Akor Nitelik Ustası capstone', () {
    test('chordLessons içinde, nitelik modunda, dokuz niteliğin tümüyle', () {
      final master = chordLessons.firstWhere((l) => l.id == 'ch_quality_master');
      expect(master.recognizeBy, ChordRecognizeBy.quality);
      final qualities = master.pool.map((c) => c.quality).toSet();
      expect(qualities.length, ChordQuality.values.length); // 9 niteliğin tümü
    });
  });
}
