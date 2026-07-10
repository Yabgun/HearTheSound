import 'dart:math' as math;

/// Nota adları — harf sistemi (kararımız), diyez (sharp) formu.
/// Index = pitch class: 0 = C, 1 = C#, ... 11 = B.
const List<String> noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
];

/// Bir müzik notası. Kanonik temsil: MIDI numarası (60 = C4, 69 = A4 = 440 Hz).
///
/// Uygulamanın çekirdek müzik birimidir — hem çalma (frekans) hem tanıma
/// (ad/oktav) tarafında bunu kullanacağız.
class Note {
  final int midi;
  const Note(this.midi);

  /// Ad + oktavdan üret (ör. `Note.fromName('A', 4)` -> A4).
  factory Note.fromName(String name, int octave) {
    final pc = noteNames.indexOf(name);
    if (pc < 0) throw ArgumentError('Geçersiz nota adı: $name');
    return Note((octave + 1) * 12 + pc);
  }

  /// Eşit tamperaman frekansı (A4 = 440 Hz referans).
  double get frequency => 440.0 * math.pow(2, (midi - 69) / 12.0).toDouble();

  /// Pitch class 0..11 (0 = C).
  int get pitchClass => midi % 12;

  /// Bilimsel perde notasyonu oktavı (C4 = orta Do).
  int get octave => (midi ~/ 12) - 1;

  /// Oktavsız harf adı (ör. "A", "C#").
  String get name => noteNames[pitchClass];

  /// Oktavlı tam etiket (ör. "A4").
  String get label => '$name$octave';

  @override
  bool operator ==(Object other) => other is Note && other.midi == midi;

  @override
  int get hashCode => midi.hashCode;

  @override
  String toString() =>
      'Note($label, midi=$midi, ${frequency.toStringAsFixed(1)}Hz)';
}

/// İki nota arasındaki (ikisi dahil) tüm notalar — egzersiz havuzu kurmak için.
List<Note> noteRange(Note from, Note to) =>
    [for (var m = from.midi; m <= to.midi; m++) Note(m)];

/// Bir frekanstan (Hz) en yakın nota + akort sapması (cent). Perde tespiti
/// (mikrofon) tarafında kullanılır.
class NoteReading {
  final Note note;
  final double cents; // -50..+50 arası sapma (0 = tam akortta)
  final double frequency; // ölçülen ham frekans

  const NoteReading({
    required this.note,
    required this.cents,
    required this.frequency,
  });

  String get label => note.label;

  /// Ham frekanstan en yakın notayı ve cinsinden sapmayı çıkarır.
  factory NoteReading.fromFrequency(double freq) {
    final midiFloat = 69 + 12 * (math.log(freq / 440.0) / math.ln2);
    final midi = midiFloat.round();
    final cents = (midiFloat - midi) * 100.0;
    return NoteReading(note: Note(midi), cents: cents, frequency: freq);
  }
}
