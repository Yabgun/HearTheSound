import 'dart:math';

// -----------------------------------------------------------------------------
// RİTİM ÇEKİRDEĞİ — kalıp üretimi ve karşılaştırma (saf, testli)
//
// Eko Oyunu'nun ritim versiyonu: kalıp çalınır, kullanıcı DOKUNARAK tekrarlar.
// Perde yok — ölçülen tek şey ZAMANLAMA. Track'in tamamı, Armoni Kulağı'nda
// pahalıya öğrenilen kök kurala uyar: cevap az önce çalan sesin İÇİNDEdir ve
// kullanıcının işi onu geri kurmaktır.
//
// İKİ TASARIM KARARI:
//
// 1) İLK VURUŞA GÖRE HİZALAMA. Hem kalıp hem kullanıcının denemesi kendi ilk
//    vuruşuna göre sıfırlanır. Böylece "ne zaman başladığın" değil ARALIKLARIN
//    ölçülür — kullanıcı hazır olduğunda başlar. Aksi hâlde geri sayım/metronom
//    gerekirdi; egzersize fazladan ses eklemek ise bu projede yasak (cihazda
//    denenip kaldırılan "ev sesi" ipucunun dersi).
//
// 2) EN KÜÇÜK BİRİM SEKİZLİK (subdivision ≤ 2). Onaltılık kalıplar 100 BPM'de
//    150 ms aralık demek; bu hem dokunma hassasiyetinin hem ses gecikmesinin
//    altında kalır → beceri değil cihaz ölçülürdü. Senkop zaten sekizliklerle
//    öğretilebiliyor.
// -----------------------------------------------------------------------------

/// Ritim derslerinin temposu: 100 BPM (bir vuruş = 600 ms).
///
/// Sabit ve orta: hızlandırmak beceriyi değil refleksi ölçer, yavaşlatmak
/// kalıbın "kalıp" gibi duyulmasını zorlaştırır.
const int kRhythmBeatMs = 600;

/// Bir ritim kalıbının üretim parametreleri (dersten ve dilden bağımsız).
class RhythmShape {
  /// Kalıbın uzunluğu (vuruş sayısı).
  final int beats;

  /// Vuruş başına en küçük birim: 1 = yalnızca vuruş üstü, 2 = sekizlikler.
  final int subdivision;

  /// Kalıpta kaç ses olacak.
  final int onsetCount;

  /// Sesler vuruş ARASINA düşebilir mi? (senkobun kaynağı)
  final bool allowOffbeat;

  const RhythmShape({
    required this.beats,
    required this.onsetCount,
    this.subdivision = 1,
    this.allowOffbeat = false,
  });

  /// Kalıbın toplam süresi (ms) — görsel zaman çizelgesinin genişliği.
  int get totalMs => beats * kRhythmBeatMs;

  /// En küçük birimin süresi (ms).
  int get slotMs => kRhythmBeatMs ~/ subdivision;

  /// Kalıbın oturduğu ızgaradaki toplam yuva sayısı.
  int get slotCount => beats * subdivision;
}

/// Şekle uyan bir kalıp üretir: ızgara yuvası indeksleri, artan sırada.
///
/// İlk ses HER ZAMAN 0. yuvadadır: hizalama ilk vuruşa göre yapıldığından
/// kalıbın "sessizlikle başlaması" ölçülemez bir fark olurdu (kullanıcı zaten
/// istediği an başlıyor).
List<int> generateRhythm({
  required RhythmShape shape,
  required Random rng,
}) {
  if (shape.beats < 1) {
    throw ArgumentError('RhythmShape.beats must be >= 1');
  }
  if (shape.subdivision < 1 || shape.subdivision > 2) {
    throw ArgumentError('RhythmShape.subdivision must be 1 or 2');
  }
  if (shape.onsetCount < 2) {
    // Tek sesli "kalıp" tekrarlanacak bir aralık taşımaz.
    throw ArgumentError('RhythmShape.onsetCount must be >= 2');
  }

  // Kullanılabilir yuvalar: senkop kapalıysa yalnızca vuruş üstleri.
  final available = [
    for (var slot = 1; slot < shape.slotCount; slot++)
      if (shape.allowOffbeat || slot % shape.subdivision == 0) slot,
  ];
  if (shape.onsetCount - 1 > available.length) {
    throw ArgumentError(
      'RhythmShape asks for ${shape.onsetCount} onsets but only '
      '${available.length + 1} slots are available',
    );
  }

  final chosen = <int>[0];
  final pool = List<int>.from(available)..shuffle(rng);
  chosen.addAll(pool.take(shape.onsetCount - 1));
  chosen.sort();
  return chosen;
}

/// Izgara yuvalarını milisaniyeye çevirir.
List<int> onsetTimesMs({
  required List<int> slots,
  required RhythmShape shape,
}) => [for (final slot in slots) slot * shape.slotMs];

/// Bir ritim denemesinin hedefle karşılaştırması.
class RhythmComparison {
  /// Her ses için tolerans içinde mi? Uzunluğu hedefin uzunluğu kadardır;
  /// kullanıcı eksik vurduysa kalanlar `false` sayılır.
  final List<bool> matches;

  /// Her ses için sapma (ms, + = geç, − = erken). Vurulmayan ses için null.
  /// Kullanıcıya "erken mi geç mi vurdum" geri bildirimini bu besler.
  final List<int?> offsetsMs;

  const RhythmComparison({required this.matches, required this.offsetsMs});

  int get correctCount => matches.where((m) => m).length;

  bool get isPerfect => matches.isNotEmpty && matches.every((m) => m);

  double get accuracy => matches.isEmpty ? 0 : correctCount / matches.length;
}

/// Kullanıcının vuruşlarını hedefle karşılaştırır.
///
/// Her iki dizi de KENDİ ilk vuruşuna göre sıfırlanır (bkz. dosya başlığı):
/// ölçülen şey aralıklar, başlama anı değil.
RhythmComparison compareRhythm({
  required List<int> targetMs,
  required List<int> tapMs,
  required int toleranceMs,
}) {
  if (targetMs.isEmpty) {
    return const RhythmComparison(matches: [], offsetsMs: []);
  }
  final targetBase = targetMs.first;
  final tapBase = tapMs.isEmpty ? 0 : tapMs.first;

  final matches = <bool>[];
  final offsets = <int?>[];
  for (var i = 0; i < targetMs.length; i++) {
    if (i >= tapMs.length) {
      matches.add(false);
      offsets.add(null);
      continue;
    }
    final offset = (tapMs[i] - tapBase) - (targetMs[i] - targetBase);
    offsets.add(offset);
    matches.add(offset.abs() <= toleranceMs);
  }
  return RhythmComparison(matches: matches, offsetsMs: offsets);
}
