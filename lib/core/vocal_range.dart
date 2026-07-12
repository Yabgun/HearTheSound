import 'note.dart';

/// Kullanıcının ölçülmüş ses aralığı (kalibrasyon sonucu).
///
/// İki iç içe aralık tutar:
/// - **Rahat** `[comfortLow, comfortHigh]`: zorlanmadan söyleyebildiği aralık.
///   Dersler varsayılan olarak burada yaşar.
/// - **Esneme** `[stretchLow, stretchHigh]`: zorlanarak ama zarar vermeden
///   ulaşabildiği uç. Rahat aralığa sığmayan içerik buraya taşabilir (kullanıcıya
///   "biraz üstünde, dene" diye işaretlenir) ve keşif modunun sınırıdır.
///
/// Değişmezdir (immutable). Değerler MIDI numarasıdır (60 = C4).
/// Değişmez kural: `stretchLow <= comfortLow <= comfortHigh <= stretchHigh`.
class VocalRange {
  final int comfortLow;
  final int comfortHigh;
  final int stretchLow;
  final int stretchHigh;

  /// Kalibrasyonun yapıldığı an — "yeniden kalibre et" hatırlatması ve gösterim
  /// için. Ses güne/ısınmaya göre değiştiğinden kullanıcı istediği an tazeleyebilir.
  final DateTime? calibratedAt;

  const VocalRange({
    required this.comfortLow,
    required this.comfortHigh,
    required this.stretchLow,
    required this.stretchHigh,
    this.calibratedAt,
  });

  /// Sınırları güvenli sıraya sokarak üretir (bozuk/uçuk okumalara karşı).
  /// Esneme, rahat aralığı her zaman kapsar.
  factory VocalRange.clamped({
    required int comfortLow,
    required int comfortHigh,
    required int stretchLow,
    required int stretchHigh,
    DateTime? calibratedAt,
  }) {
    final cLow = comfortLow <= comfortHigh ? comfortLow : comfortHigh;
    final cHigh = comfortLow <= comfortHigh ? comfortHigh : comfortLow;
    return VocalRange(
      comfortLow: cLow,
      comfortHigh: cHigh,
      stretchLow: stretchLow < cLow ? stretchLow : cLow,
      stretchHigh: stretchHigh > cHigh ? stretchHigh : cHigh,
      calibratedAt: calibratedAt,
    );
  }

  Note get comfortLowNote => Note(comfortLow);
  Note get comfortHighNote => Note(comfortHigh);

  /// Rahat aralığın orta noktası (yarım-ses, kesirli olabilir) — içeriği
  /// buraya ortalarız.
  double get comfortCenter => (comfortLow + comfortHigh) / 2.0;

  /// Rahat aralığın genişliği (yarım-ses).
  int get comfortSpan => comfortHigh - comfortLow;

  bool inComfort(int midi) => midi >= comfortLow && midi <= comfortHigh;
  bool inStretch(int midi) => midi >= stretchLow && midi <= stretchHigh;

  VocalRange copyWith({
    int? comfortLow,
    int? comfortHigh,
    int? stretchLow,
    int? stretchHigh,
    DateTime? calibratedAt,
  }) {
    return VocalRange(
      comfortLow: comfortLow ?? this.comfortLow,
      comfortHigh: comfortHigh ?? this.comfortHigh,
      stretchLow: stretchLow ?? this.stretchLow,
      stretchHigh: stretchHigh ?? this.stretchHigh,
      calibratedAt: calibratedAt ?? this.calibratedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'comfortLow': comfortLow,
        'comfortHigh': comfortHigh,
        'stretchLow': stretchLow,
        'stretchHigh': stretchHigh,
        'calibratedAt': calibratedAt?.toIso8601String(),
      };

  factory VocalRange.fromMap(Map<String, dynamic> map) {
    final ts = map['calibratedAt'] as String?;
    return VocalRange(
      comfortLow: (map['comfortLow'] as num).toInt(),
      comfortHigh: (map['comfortHigh'] as num).toInt(),
      stretchLow: (map['stretchLow'] as num).toInt(),
      stretchHigh: (map['stretchHigh'] as num).toInt(),
      calibratedAt: ts == null ? null : DateTime.tryParse(ts),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VocalRange &&
      other.comfortLow == comfortLow &&
      other.comfortHigh == comfortHigh &&
      other.stretchLow == stretchLow &&
      other.stretchHigh == stretchHigh;

  @override
  int get hashCode =>
      Object.hash(comfortLow, comfortHigh, stretchLow, stretchHigh);

  @override
  String toString() =>
      'VocalRange(rahat ${comfortLowNote.label}–${comfortHighNote.label}, '
      'esneme ${Note(stretchLow).label}–${Note(stretchHigh).label})';
}
