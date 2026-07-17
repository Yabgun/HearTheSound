import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/core/vocal_range.dart';
import 'package:hear_the_sound/features/function/function_lesson.dart';

void main() {
  test('Do majör dereceleri doğru işlev ailelerine ayrılır', () {
    final byRoman = {
      for (final degree in functionLessons.last.pool) degree.roman: degree,
    };

    expect(byRoman['I']?.function, HarmonicFunction.tonic);
    expect(byRoman['iii']?.function, HarmonicFunction.tonic);
    expect(byRoman['vi']?.function, HarmonicFunction.tonic);
    expect(byRoman['IV']?.function, HarmonicFunction.subdominant);
    expect(byRoman['ii']?.function, HarmonicFunction.subdominant);
    expect(byRoman['V']?.function, HarmonicFunction.dominant);
    expect(byRoman['vii°']?.function, HarmonicFunction.dominant);
  });

  test('her derece öğrenme ipucuyla gelir', () {
    for (final degree in functionLessons.last.pool) {
      expect(degree.roleHint, isNotEmpty);
      expect(degree.why, isNotEmpty);
    }
  });

  test('dereceler ses aralığına tek blok halinde taşınır', () {
    final range = VocalRange(
      comfortLow: 48,
      comfortHigh: 60,
      stretchLow: 45,
      stretchHigh: 64,
      calibratedAt: DateTime(2026),
    );
    final source = functionLessons.first.pool;
    final shifted = transposeDegreesForVoice(source, range);

    final offset = shifted.first.chord.root.midi - source.first.chord.root.midi;
    expect(offset % 12, 0);
    for (var i = 0; i < source.length; i++) {
      expect(shifted[i].chord.root.midi - source[i].chord.root.midi, offset);
      expect(shifted[i].roman, source[i].roman);
    }
  });

  test('işlev dersi tonalite değiştiğinde derece ve işlevini korur', () {
    final gMajor = functionLessons.last.inKey(MajorKey.g);
    final byRoman = {for (final degree in gMajor.pool) degree.roman: degree};

    expect(byRoman['I']?.chord.root.label, 'G4');
    expect(byRoman['IV']?.chord.root.label, 'C5');
    expect(byRoman['V']?.chord.root.label, 'D5');
    expect(byRoman['V']?.function, HarmonicFunction.dominant);
  });
}
