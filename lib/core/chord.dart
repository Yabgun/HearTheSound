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

  /// Türkçe nitelik adı.
  String get label => switch (this) {
        ChordQuality.major => 'Majör',
        ChordQuality.minor => 'Minör',
        ChordQuality.diminished => 'Eksik',
        ChordQuality.augmented => 'Artık',
        ChordQuality.dominant7 => 'Dominant 7\'li',
        ChordQuality.major7 => 'Majör 7\'li',
        ChordQuality.minor7 => 'Minör 7\'li',
        ChordQuality.halfDiminished7 => 'Yarım Eksik 7\'li',
        ChordQuality.diminished7 => 'Tam Eksik 7\'li',
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

  /// Çevrimin Türkçe adı.
  String get inversionName => switch (inversion) {
        1 => '1. çevrim',
        2 => '2. çevrim',
        3 => '3. çevrim',
        _ => 'kapalı',
      };

  /// Tam etiket (ör. "C Majör" ya da çevrimliyse "C Majör · 1. çevrim").
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
