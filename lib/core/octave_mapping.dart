import 'chord.dart';
import 'note.dart';
import 'vocal_range.dart';

// -----------------------------------------------------------------------------
// Oktav eşleme — içeriği kullanıcının ses aralığına taşıma
//
// İçerik notaları kanonik oktavda "yazılı" gelir (ör. C4-E4-G4). Bir kullanıcının
// söylemesi için bunları onun rahat aralığına indiririz/çıkarırız. İki kural:
//
//   1. TÜM egzersiz TEK bir offset ile, BLOK halinde kayar (nota nota değil) —
//      yoksa akorun/aralığın şekli (majör üçlü vb.) bozulur.
//   2. Offset her zaman TAM oktav katıdır (±12'nin katı) — böylece nota sınıfı
//      ve adı korunur (C, C kalır; sadece oktav değişir).
//
// "Hepsi birlikte kayar" kararı gereği aynı offset o dersin Duy/Söyle/Tanı
// adımlarının hepsinde kullanılır → duyulan, söylenen ve tanınan hep aynı oktav.
// -----------------------------------------------------------------------------

/// Bir notanın kullanıcının aralığına göre düştüğü bölge.
enum ReachZone {
  /// Rahat aralık içinde — işaret yok.
  comfort,

  /// Rahat aralığın dışı ama esneme aralığında — "biraz üstünde/altında, dene".
  stretch,

  /// Esneme aralığının da dışı — kullanıcı için gerçekten zor.
  beyond,
}

/// Bir MIDI notasının [range] için hangi bölgede olduğunu döndürür.
ReachZone reachZoneFor(int midi, VocalRange range) {
  if (range.inComfort(midi)) return ReachZone.comfort;
  if (range.inStretch(midi)) return ReachZone.stretch;
  return ReachZone.beyond;
}

/// [targets] (kanonik MIDI değerleri) kümesini [range]'in rahat aralığına en iyi
/// oturtan oktav offset'ini (±12'nin katı) döndürür.
///
/// [range] null (kalibre edilmemiş) ise 0 döner → içerik bugünkü kanonik
/// oktavında kalır, hiçbir şey bozulmaz.
///
/// Seçim mantığı: birkaç aday oktav kaydırmasını deneyip her biri için
/// "rahat aralık dışına toplam taşma"yı (yarım-ses) ölçer, en azını seçer.
/// Eşitlikte tavanı daha alçak kalan yerleşimi tercih eder — kullanıcılar
/// genelde tiz notalarda zorlandığından içeriği olabildiğince aşağıda tutar.
int octaveOffsetFor(Iterable<int> targets, VocalRange? range) {
  if (range == null) return 0;
  final list = targets.toList();
  if (list.isEmpty) return 0;

  final low = list.reduce((a, b) => a < b ? a : b);
  final high = list.reduce((a, b) => a > b ? a : b);

  // Aday k aralığı: en alçak notayı comfortLow'a, en tiz notayı comfortHigh'a
  // getiren kaymalar arası (birer oktav pay ekleyerek).
  final kMin = ((range.comfortLow - high) / 12).floor() - 1;
  final kMax = ((range.comfortHigh - low) / 12).ceil() + 1;

  int? bestOffset;
  int bestCost = 1 << 30;
  int bestCeiling = 1 << 30;

  for (var k = kMin; k <= kMax; k++) {
    final offset = k * 12;
    var cost = 0;
    var ceiling = -(1 << 30);
    for (final t in list) {
      final m = t + offset;
      if (m < range.comfortLow) {
        cost += range.comfortLow - m;
      } else if (m > range.comfortHigh) {
        cost += m - range.comfortHigh;
      }
      if (m > ceiling) ceiling = m;
    }
    // Daha az taşma kazanır; eşitse tavanı alçak olan (tiz notadan kaçınmak için).
    if (cost < bestCost || (cost == bestCost && ceiling < bestCeiling)) {
      bestCost = cost;
      bestCeiling = ceiling;
      bestOffset = offset;
    }
  }

  return bestOffset ?? 0;
}

/// [notes] listesini [range]'e göre blok halinde transpoze eder (aynı offset
/// hepsine uygulanır). Kalibre edilmemişse notalar olduğu gibi döner.
List<Note> transposeForVoice(List<Note> notes, VocalRange? range) {
  final offset = octaveOffsetFor(notes.map((n) => n.midi), range);
  if (offset == 0) return List<Note>.from(notes);
  return notes.map((n) => Note(n.midi + offset)).toList();
}

/// Tek bir notayı [range]'e göre transpoze eder (o notayı tek elemanlı bir
/// egzersiz gibi düşünerek).
Note transposeNoteForVoice(Note note, VocalRange? range) {
  final offset = octaveOffsetFor([note.midi], range);
  return offset == 0 ? note : Note(note.midi + offset);
}

/// Bir akor listesini blok halinde [range]'e transpoze eder. Offset TÜM
/// akorların TÜM notalarından birlikte hesaplanır (bir ders tek offset paylaşır)
/// → hem her akorun şekli hem akorların birbirine göre konumu korunur.
List<Chord> transposeChordsForVoice(List<Chord> chords, VocalRange? range) {
  final offset = octaveOffsetFor(
    chords.expand((c) => c.notes).map((n) => n.midi),
    range,
  );
  if (offset == 0) return List<Chord>.from(chords);
  return chords
      .map(
        (c) => Chord(
          Note(c.root.midi + offset),
          c.quality,
          inversion: c.inversion,
        ),
      )
      .toList();
}
