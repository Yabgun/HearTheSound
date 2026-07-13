import 'note.dart';

/// İki nota arasındaki mesafe (yarım ses cinsinden) + adı.
///
/// Flutter'ın animasyon `Interval` sınıfıyla karışmasın diye `MusicInterval`.
/// Aralık göreceli bir kavramdır: bir "kök" nota üstüne kurulunca somut iki nota
/// verir (kök + üst).
class MusicInterval {
  final int semitones; // 1..12
  final String name; // "Büyük 3'lü"
  const MusicInterval(this.semitones, this.name);

  /// Kökten itibaren iki nota (kök + üst).
  List<Note> from(Note root) => [root, Note(root.midi + semitones)];

  /// Sadece üst nota (kök + aralık).
  Note topFrom(Note root) => Note(root.midi + semitones);

  @override
  bool operator ==(Object other) =>
      other is MusicInterval && other.semitones == semitones;

  @override
  int get hashCode => semitones.hashCode;
}

/// 12 aralık kataloğu (yarım ses → aralık).
const Map<int, MusicInterval> kIntervals = {
  1: MusicInterval(1, "Küçük 2'li"),
  2: MusicInterval(2, "Büyük 2'li"),
  3: MusicInterval(3, "Küçük 3'lü"),
  4: MusicInterval(4, "Büyük 3'lü"),
  5: MusicInterval(5, "Tam 4'lü"),
  6: MusicInterval(6, "Triton"),
  7: MusicInterval(7, "Tam 5'li"),
  8: MusicInterval(8, "Küçük 6'lı"),
  9: MusicInterval(9, "Büyük 6'lı"),
  10: MusicInterval(10, "Küçük 7'li"),
  11: MusicInterval(11, "Büyük 7'li"),
  12: MusicInterval(12, "Oktav"),
};

/// Kısayol: yarım sesten aralık.
MusicInterval iv(int semitones) => kIntervals[semitones]!;
