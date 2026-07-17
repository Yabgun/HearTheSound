import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/interval.dart';
import 'package:hear_the_sound/core/note.dart';

void main() {
  test('aralık kökten üst notayı doğru kurar', () {
    final c4 = Note.fromName('C', 4);

    expect(iv(4).topFrom(c4).label, 'E4');
    expect(iv(7).topFrom(c4).label, 'G4');
    expect(iv(12).topFrom(c4).label, 'C5');
  });
}
