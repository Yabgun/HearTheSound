import 'dart:math';

import '../../core/musical_phrase.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// EZGİ ÜRETİMİ — Eko oyununun malzemesi (saf, testli)
//
// Ders "hangi notaları çalayım" demez; ŞEKLİNİ söyler (kaç nota, hangi
// dereceler, sıçrama var mı, tonikte bitsin mi). Ezgi her seferinde yeniden
// üretilir → kullanıcı ezberleyemez, gerçekten dinlemek zorunda kalır.
//
// Zorluk tek tek büyür: nota sayısı → derece havuzu → sıçrama → ev değişimi.
// -----------------------------------------------------------------------------

/// Bir ezginin üretim parametreleri (dersten ve dilden bağımsız).
///
/// ÇEŞİTLİLİK NOTU: İlk sürümde `startOnTonic` varsayılan olarak açıktı ve
/// sıçrama iki durumluydu (var/yok). Sonuç felaketti: "tonikten başla + yalnızca
/// komşuya adım" kuralı 2 notalık derste TEK bir ezgi üretiyordu — kullanıcı
/// her soruda aynı sesi duyuyordu. Artık başlangıç serbest ([startOnTonic]
/// varsayılan false; ev kulağa ezgiden ÖNCE çalınan tonik ipucuyla kurulur) ve
/// sıçrama [maxLeap] ile kademeli açılır.
class MelodyShape {
  /// Ezgideki nota sayısı.
  final int noteCount;

  /// Kullanılabilir dereceler (1..8; majör dizi).
  final List<int> degrees;

  /// Havuz içinde en fazla kaç BASAMAK sıçranabilir. 1 = yalnızca komşu ses;
  /// büyüdükçe ezgi daha geniş ve daha zor olur.
  final int maxLeap;

  /// Ezgi tonikten mi başlasın? Varsayılan false — çeşitlilik için.
  final bool startOnTonic;

  /// Ezgi tonikte mi bitsin? Bu bayrak açıkken kullanıcı, hiçbir şey
  /// anlatılmadan, ezgilerin hep aynı sese döndüğünü FARK EDER — "tonik"
  /// kavramı böyle doğar (önce yaşat, sonra adını koy).
  final bool endOnTonic;

  /// Aynı nota peş peşe gelebilir mi? Söyleme modunda iki özdeş sesi ayırmak
  /// zor olduğu için varsayılan kapalı.
  final bool allowRepeats;

  const MelodyShape({
    required this.noteCount,
    required this.degrees,
    this.maxLeap = 1,
    this.startOnTonic = false,
    this.endOnTonic = false,
    this.allowRepeats = false,
  });
}

/// Şekle uyan bir derece dizisi üretir.
///
/// Tonikte bitmesi gerekiyorsa her adımda "kalan adımlarla tonike ulaşılabilir
/// mi" kontrol edilir; böylece ezgi sonunda zorlama bir sıçrama yapmak zorunda
/// kalmaz (adım adım eve yürür).
List<int> generateDegrees({
  required MelodyShape shape,
  required Random rng,
}) {
  final available = shape.degrees.toSet().toList()..sort();
  if (available.isEmpty) {
    throw ArgumentError('MelodyShape.degrees must not be empty');
  }
  if (shape.noteCount < 1) {
    throw ArgumentError('MelodyShape.noteCount must be >= 1');
  }
  if (shape.maxLeap < 1) {
    throw ArgumentError('MelodyShape.maxLeap must be >= 1');
  }
  final tonicIndex = available.indexOf(1);
  if ((shape.startOnTonic || shape.endOnTonic) && tonicIndex < 0) {
    throw ArgumentError('startOnTonic/endOnTonic requires degree 1 in degrees');
  }

  var current = shape.startOnTonic ? tonicIndex : rng.nextInt(available.length);
  // Tonikte biten kısa ezgi tonikten başlarsa "1…1" gibi kısır bir ezgi çıkar.
  if (!shape.startOnTonic &&
      shape.endOnTonic &&
      current == tonicIndex &&
      available.length > 1) {
    current = (current + 1 + rng.nextInt(available.length - 1)) %
        available.length;
  }
  final indices = <int>[current];

  for (var step = 1; step < shape.noteCount; step++) {
    final remainingAfter = shape.noteCount - 1 - step;

    // Son nota ve tonikte bitmeli → ev.
    if (shape.endOnTonic && remainingAfter == 0) {
      current = tonicIndex;
      indices.add(current);
      continue;
    }

    // Sıçrama penceresi: mevcut sesin çevresinde en fazla maxLeap basamak.
    final low = (current - shape.maxLeap).clamp(0, available.length - 1);
    final high = (current + shape.maxLeap).clamp(0, available.length - 1);
    var candidates = <int>[
      for (var i = low; i <= high; i++)
        if (i != current || shape.allowRepeats) i,
    ];

    // Eve dönüş garantisi: buradan sonra kalan adımlarla tonike varılabilmeli.
    if (shape.endOnTonic) {
      candidates = [
        for (final c in candidates)
          if ((c - tonicIndex).abs() <= remainingAfter * shape.maxLeap) c,
      ];
    }

    // Sondan bir önceki notada mümkünse toniğe basma — yoksa ezgi "…1-1" diye
    // biter. Tek seçenek toniğse kabul edilir (tekrarlanan nota müzikte olağan).
    if (shape.endOnTonic && remainingAfter == 1 && candidates.length > 1) {
      final withoutTonic = [
        for (final c in candidates)
          if (c != tonicIndex) c,
      ];
      if (withoutTonic.isNotEmpty) candidates = withoutTonic;
    }

    if (candidates.isEmpty) {
      // Savunmacı: tonike doğru tek adım (dizi asla tıkanmasın).
      current = current.compareTo(tonicIndex) > 0 ? current - 1 : current + 1;
      current = current.clamp(0, available.length - 1);
    } else {
      current = candidates[rng.nextInt(candidates.length)];
    }
    indices.add(current);
  }

  return [for (final index in indices) available[index]];
}

/// Şekle uyan bir ezgi üretir ([tonic] = o sorunun "evi").
MusicalPhrase generateMelody({
  required Note tonic,
  required MelodyShape shape,
  required Random rng,
}) => melodicPhrase(
  tonic: tonic,
  semitoneOffsets: [
    for (final degree in generateDegrees(shape: shape, rng: rng))
      majorDegreeSemitones(degree),
  ],
);
