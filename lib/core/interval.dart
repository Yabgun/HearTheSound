import 'content_locale.dart';
import 'note.dart';

/// İki nota arasındaki mesafe (yarım ses cinsinden).
///
/// Flutter'ın animasyon `Interval` sınıfıyla karışmasın diye `MusicInterval`.
/// Aralık göreceli bir kavramdır: bir "kök" nota üstüne kurulunca somut iki nota
/// verir (kök + üst). [name] sabit veri değil GETTER'dır: aktif içerik diline
/// göre çözülür — böylece const havuzlardaki aralıklar da dil değişimini izler.
class MusicInterval {
  final int semitones; // 1..12
  const MusicInterval(this.semitones);

  /// Aralığın adı (aktif dile göre; ör. "Major 3rd" / "Büyük 3'lü").
  String get name => switch (semitones) {
    1 => t(en: 'Minor 2nd', tr: "Küçük 2'li"),
    2 => t(en: 'Major 2nd', tr: "Büyük 2'li"),
    3 => t(en: 'Minor 3rd', tr: "Küçük 3'lü"),
    4 => t(en: 'Major 3rd', tr: "Büyük 3'lü"),
    5 => t(en: 'Perfect 4th', tr: "Tam 4'lü"),
    6 => t(en: 'Tritone', tr: 'Triton'),
    7 => t(en: 'Perfect 5th', tr: "Tam 5'li"),
    8 => t(en: 'Minor 6th', tr: "Küçük 6'lı"),
    9 => t(en: 'Major 6th', tr: "Büyük 6'lı"),
    10 => t(en: 'Minor 7th', tr: "Küçük 7'li"),
    11 => t(en: 'Major 7th', tr: "Büyük 7'li"),
    12 => t(en: 'Octave', tr: 'Oktav'),
    _ => t(en: '$semitones semitones', tr: '$semitones yarım ses'),
  };

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

/// 12 aralık kataloğu (yarım ses → aralık). Adlar [MusicInterval.name]
/// getter'ından dile göre çözülür.
const Map<int, MusicInterval> kIntervals = {
  1: MusicInterval(1),
  2: MusicInterval(2),
  3: MusicInterval(3),
  4: MusicInterval(4),
  5: MusicInterval(5),
  6: MusicInterval(6),
  7: MusicInterval(7),
  8: MusicInterval(8),
  9: MusicInterval(9),
  10: MusicInterval(10),
  11: MusicInterval(11),
  12: MusicInterval(12),
};

/// Kısayol: yarım sesten aralık.
MusicInterval iv(int semitones) => kIntervals[semitones]!;
