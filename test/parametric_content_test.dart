import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/function/function_lesson.dart';
import 'package:hear_the_sound/features/progression/progression_lesson.dart';

// §1C Parametrik içerik — beşler çemberi genişlemesi + üretilen "Tonalite
// Yolculuğu" işlev/ilerleme dersleri + akor nitelik capstone.

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

  group('İşlev Yolculuğu üretimi', () {
    test('her yeni merkez için bir ders; benzersiz id, 7 derece, kavramlı', () {
      final j = functionJourneyLessons;
      expect(j.length, journeyKeys.length);
      expect(j.map((l) => l.id).toSet().length, j.length); // benzersiz
      for (final l in j) {
        expect(l.id, startsWith('fn_j_'));
        expect(l.pool.length, 7);
        expect(l.concept, isNotNull);
        expect(journeyKeys, contains(l.key));
      }
      // El yazımı id'lerle çakışmaz (ilerleme/kilit paylaşmaz).
      expect(j.map((l) => l.id), isNot(contains('fn1')));
    });

    test('inKey transferi havuzu korur ve hedef tonaliteyi işaretler', () {
      final aFunc = functionJourneyLessons.firstWhere(
        (l) => l.key == MajorKey.a,
      );
      final keyed = aFunc.inKey(aFunc.key);
      expect(keyed.key, MajorKey.a);
      expect(keyed.pool.length, aFunc.pool.length);
    });
  });

  group('İlerleme Yolculuğu üretimi', () {
    test('benzersiz id, dolu havuz, kavramlı', () {
      final j = progressionJourneyLessons;
      expect(j.length, journeyKeys.length);
      expect(j.map((l) => l.id).toSet().length, j.length);
      for (final l in j) {
        expect(l.id, startsWith('pr_j_'));
        expect(l.pool, isNotEmpty);
        expect(l.concept, isNotNull);
      }
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
