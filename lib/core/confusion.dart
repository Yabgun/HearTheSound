// -----------------------------------------------------------------------------
// KARIŞTIRMA İÇGÖRÜSÜ — "en çok neyi neyle karıştırıyorum?"
//
// Tanıma ekranları her yanlış cevapta dil-bağımsız bir anahtar üretir:
//   'tip:beklenen>seçilen'   ör. 'note:C>E', 'quality:major7>dominant7'
// Bu dosya o anahtarları AYRIŞTIRIR ve sayaca göre sıralar (saf mantık, UI'sız).
// Görselleştirme/yerelleştirme UI katmanının işidir.
// -----------------------------------------------------------------------------

/// Ayrıştırılmış tek bir karıştırma kaydı.
class ConfusionEntry {
  final String
  type; // note | chord | quality | inv | interval | degree | function | prog
  final String expected; // duyulan (doğru) öğenin ham belirteci
  final String chosen; // kullanıcının seçtiği öğenin ham belirteci
  final int count; // kaç kez

  const ConfusionEntry({
    required this.type,
    required this.expected,
    required this.chosen,
    required this.count,
  });
}

/// Sayaç haritasını en sık karıştırılandan aza doğru [limit] girdiye indirger.
/// Bozuk anahtarlar (beklenmeyen biçim) sessizce atlanır.
List<ConfusionEntry> topConfusions(Map<String, int> counts, {int limit = 3}) {
  final entries = <ConfusionEntry>[];
  counts.forEach((key, count) {
    final colon = key.indexOf(':');
    final arrow = key.indexOf('>');
    if (colon <= 0 || arrow <= colon + 1 || arrow >= key.length - 1) return;
    entries.add(
      ConfusionEntry(
        type: key.substring(0, colon),
        expected: key.substring(colon + 1, arrow),
        chosen: key.substring(arrow + 1),
        count: count,
      ),
    );
  });
  entries.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    // Eşitlikte alfabetik: sıralama deterministik kalsın.
    return '${a.type}:${a.expected}>${a.chosen}'.compareTo(
      '${b.type}:${b.expected}>${b.chosen}',
    );
  });
  return entries.take(limit).toList();
}
