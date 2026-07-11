import 'note.dart';

/// Üçlü akor niteliği.
enum ChordQuality { major, minor, diminished, augmented }

extension ChordQualityInfo on ChordQuality {
  /// Kök notadan itibaren yarım-ses aralıkları (üçlü akor).
  List<int> get intervals => switch (this) {
        ChordQuality.major => const [0, 4, 7],
        ChordQuality.minor => const [0, 3, 7],
        ChordQuality.diminished => const [0, 3, 6],
        ChordQuality.augmented => const [0, 4, 8],
      };

  /// Türkçe nitelik adı.
  String get label => switch (this) {
        ChordQuality.major => 'Majör',
        ChordQuality.minor => 'Minör',
        ChordQuality.diminished => 'Eksik',
        ChordQuality.augmented => 'Artık',
      };
}

/// Bir akor = kök nota + nitelik. Notaları kökten yarım-ses aralıklarıyla üretilir.
class Chord {
  final Note root;
  final ChordQuality quality;
  const Chord(this.root, this.quality);

  /// Akoru oluşturan notalar (kökten tize doğru).
  List<Note> get notes =>
      quality.intervals.map((i) => Note(root.midi + i)).toList();

  /// Tam etiket (ör. "C Majör").
  String get label => '${root.name} ${quality.label}';

  @override
  bool operator ==(Object other) =>
      other is Chord && other.root == root && other.quality == quality;

  @override
  int get hashCode => Object.hash(root, quality);
}
