import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/features/progression/progression_lesson.dart';

void main() {
  test('ilerleme yeni tonalitede aynı Roman hareketini korur', () {
    final gMajor = progressionLessons.last.inKey(MajorKey.g);
    final cadence = gMajor.pool.first;

    expect(cadence.name, 'I – IV – V – I');
    expect(cadence.chordChain, 'G – C – D – G');
    expect(cadence.functionPath, 'Tonik → Subdominant → Dominant → Tonik');
  });
}
