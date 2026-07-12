import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/core/octave_mapping.dart';
import 'package:hear_the_sound/core/vocal_range.dart';

/// Kısayol: ad+oktavdan MIDI.
int m(String name, int oct) => Note.fromName(name, oct).midi;

void main() {
  // C4-E4-G4 = kanonik C majör üçlüsü (60, 64, 67).
  final cMajor = [m('C', 4), m('E', 4), m('G', 4)];

  group('octaveOffsetFor', () {
    test('kalibre edilmemişse (null) offset 0 → içerik olduğu gibi kalır', () {
      expect(octaveOffsetFor(cMajor, null), 0);
    });

    test('boş hedef listesi 0 döner', () {
      expect(octaveOffsetFor(const [], _range('A', 2, 'A', 3)), 0);
    });

    test('içerik zaten rahat aralıktaysa offset 0', () {
      final range = _range('C', 4, 'C', 5); // 60..72
      expect(octaveOffsetFor(cMajor, range), 0);
    });

    test('içerik rahat aralığın üstündeyse bir oktav iner', () {
      final range = _range('A', 2, 'A', 3); // 45..57 (pes ses)
      expect(octaveOffsetFor(cMajor, range), -12);
    });

    test('içerik rahat aralığın altındaysa oktav çıkar', () {
      final range = _range('C', 5, 'C', 6); // 72..84 (tiz ses)
      expect(octaveOffsetFor(cMajor, range), 12);
    });

    test('offset her zaman tam oktav katıdır', () {
      for (final r in [
        _range('A', 2, 'A', 3),
        _range('D', 3, 'B', 3),
        _range('C', 5, 'C', 6),
      ]) {
        expect(octaveOffsetFor(cMajor, r) % 12, 0);
      }
    });
  });

  group('transposeForVoice — blok tutarlılığı', () {
    test('transpoze sonrası akorun aralık şekli (majör üçlü) korunur', () {
      final range = _range('A', 2, 'A', 3);
      final notes =
          [m('C', 4), m('E', 4), m('G', 4)].map(Note.new).toList();
      final out = transposeForVoice(notes, range);
      // Ardışık yarım-ses farkları majör üçlüde [4, 3] olmalı.
      final diffs = [
        out[1].midi - out[0].midi,
        out[2].midi - out[1].midi,
      ];
      expect(diffs, [4, 3]);
      // Ve hepsi bir oktav inmiş olmalı: C3-E3-G3.
      expect(out.map((n) => n.label), ['C3', 'E3', 'G3']);
    });

    test('kalibre edilmemişse notalar değişmeden döner', () {
      final notes = cMajor.map(Note.new).toList();
      final out = transposeForVoice(notes, null);
      expect(out.map((n) => n.midi), cMajor);
    });
  });

  group('reachZoneFor', () {
    final range = VocalRange(
      comfortLow: m('C', 4), // 60
      comfortHigh: m('C', 5), // 72
      stretchLow: m('G', 3), // 55
      stretchHigh: m('E', 5), // 76
    );

    test('rahat aralık içi → comfort', () {
      expect(reachZoneFor(m('E', 4), range), ReachZone.comfort);
    });
    test('rahatın dışı ama esneme içi → stretch', () {
      expect(reachZoneFor(m('D', 5), range), ReachZone.stretch); // 74
      expect(reachZoneFor(m('A', 3), range), ReachZone.stretch); // 57
    });
    test('esnemenin de dışı → beyond', () {
      expect(reachZoneFor(m('A', 5), range), ReachZone.beyond); // 81
      expect(reachZoneFor(m('C', 3), range), ReachZone.beyond); // 48
    });
  });

  group('kenar durum — aralık içerikten dar/kaymış', () {
    test('hiçbir tam-oktav kayması tam sığmıyorsa taşmayı en aza indirir', () {
      // Rahat G3-D4 (55..62), tam bir P5 genişliğinde ama C majör üçlüsüyle
      // hizasız. En iyi yerleşim yine de bir notayı esneme/dışına taşırabilir.
      final range = VocalRange(
        comfortLow: m('G', 3), // 55
        comfortHigh: m('D', 4), // 62
        stretchLow: m('E', 3), // 52
        stretchHigh: m('F', 4), // 65
      );
      // Aşağı inmek (C3 çok pes) yerine yukarıda kalmak daha az taşma → offset 0.
      expect(octaveOffsetFor(cMajor, range), 0);
    });
  });
}

/// Test kısayolu: rahat aralığı ad+oktavla kur; esnemeyi ±2 yarım-ses genişlet.
VocalRange _range(String loName, int loOct, String hiName, int hiOct) {
  final lo = Note.fromName(loName, loOct).midi;
  final hi = Note.fromName(hiName, hiOct).midi;
  return VocalRange(
    comfortLow: lo,
    comfortHigh: hi,
    stretchLow: lo - 2,
    stretchHigh: hi + 2,
  );
}
