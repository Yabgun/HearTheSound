import 'content_locale.dart';
import 'note.dart';

/// Akor niteliği — üçlüler (3 nota) ve yedililer (4 nota).
enum ChordQuality {
  major,
  minor,
  diminished,
  augmented,
  dominant7,
  major7,
  minor7,
  halfDiminished7,
  diminished7,
}

extension ChordQualityInfo on ChordQuality {
  /// Kök notadan itibaren yarım-ses aralıkları (3 ya da 4 nota).
  List<int> get intervals => switch (this) {
    ChordQuality.major => const [0, 4, 7],
    ChordQuality.minor => const [0, 3, 7],
    ChordQuality.diminished => const [0, 3, 6],
    ChordQuality.augmented => const [0, 4, 8],
    ChordQuality.dominant7 => const [0, 4, 7, 10],
    ChordQuality.major7 => const [0, 4, 7, 11],
    ChordQuality.minor7 => const [0, 3, 7, 10],
    ChordQuality.halfDiminished7 => const [0, 3, 6, 10],
    ChordQuality.diminished7 => const [0, 3, 6, 9],
  };

  /// Nitelik adı — aktif içerik diline göre (EN varsayılan, TR seçilebilir).
  String get label => switch (this) {
    ChordQuality.major => t(en: 'Major', tr: 'Majör'),
    ChordQuality.minor => t(en: 'Minor', tr: 'Minör'),
    ChordQuality.diminished => t(en: 'Diminished', tr: 'Eksik'),
    ChordQuality.augmented => t(en: 'Augmented', tr: 'Artık'),
    ChordQuality.dominant7 => t(en: 'Dominant 7th', tr: 'Dominant 7\'li'),
    ChordQuality.major7 => t(en: 'Major 7th', tr: 'Majör 7\'li'),
    ChordQuality.minor7 => t(en: 'Minor 7th', tr: 'Minör 7\'li'),
    ChordQuality.halfDiminished7 => t(
      en: 'Half-diminished 7th',
      tr: 'Yarım Eksik 7\'li',
    ),
    ChordQuality.diminished7 => t(en: 'Diminished 7th', tr: 'Tam Eksik 7\'li'),
  };

  /// Dört notalı (yedili) akor mu?
  bool get isSeventh => intervals.length == 4;
}

/// Bir akor = kök nota + nitelik (+ çevrim). Notaları kökten yarım-ses
/// aralıklarıyla üretilir; çevrim, alttaki notaları oktav yukarı taşır.
class Chord {
  final Note root;
  final ChordQuality quality;

  /// 0 = kapalı (kök pozisyon), 1 = 1. çevrim, 2 = 2. çevrim …
  final int inversion;

  const Chord(this.root, this.quality, {this.inversion = 0});

  /// Akoru oluşturan notalar (bastan tize). Çevrim için en alttaki [inversion]
  /// nota bir oktav yukarı taşınır, sonra yeniden sıralanır.
  List<Note> get notes {
    final ms = quality.intervals.map((i) => root.midi + i).toList();
    for (var k = 0; k < inversion && k < ms.length; k++) {
      ms[k] += 12;
    }
    ms.sort();
    return ms.map(Note.new).toList();
  }

  /// Çevrim adı — aktif içerik diline göre.
  String get inversionName => switch (inversion) {
    1 => t(en: '1st inversion', tr: '1. çevrim'),
    2 => t(en: '2nd inversion', tr: '2. çevrim'),
    3 => t(en: '3rd inversion', tr: '3. çevrim'),
    _ => t(en: 'root position', tr: 'kapalı'),
  };

  /// Tam etiket (ör. "C Major" / "C Majör"; çevrimliyse " · 1. çevrim" eklenir).
  String get label {
    final base = '${root.name} ${quality.label}';
    return inversion == 0 ? base : '$base · $inversionName';
  }

  @override
  bool operator ==(Object other) =>
      other is Chord &&
      other.root == root &&
      other.quality == quality &&
      other.inversion == inversion;

  @override
  int get hashCode => Object.hash(root, quality, inversion);
}
