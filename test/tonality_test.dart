import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/tonality/tonality_lesson.dart';

void main() {
  test('Do majör derece notaları doğru üretilir', () {
    final tonic = Note.fromName('C', 4);
    final notes = majorScaleDegrees.map((d) => d.noteFrom(tonic).label);

    expect(notes, ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4']);
  });

  test('majör dizi oktavdaki toniğe çözülür', () {
    final tonic = Note.fromName('C', 4);
    final scale = majorScaleFrom(tonic).map((n) => n.label);

    expect(scale, ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5']);
  });

  test('tonalite dersleri kavram kartıyla gelir', () {
    for (final lesson in tonalityLessons) {
      expect(lesson.concept.sections, isNotEmpty);
    }
  });
}
