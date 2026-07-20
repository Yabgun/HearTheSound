import 'dart:math';

// -----------------------------------------------------------------------------
// GÜNÜN MEYDAN OKUMASI — deterministik günlük plan (saf mantık, UI'sız)
//
// "Günün Meydan Okuması" her gün TÜM açık becerilerden kısa, karışık bir set
// sunar. Set aynı gün SABİT kalmalı (kullanıcı gün içinde tekrar açsa aynı
// beceriler gelir) ve ilerlemeden BAĞIMSIZ olmalı (skillXp gün içinde değişince
// plan kaymasın) → bu yüzden yalnızca tarihten türetilen bir [daySeed] ile
// deterministik seçilir. (Zayıflık ağırlığı burada YOK; o Sonsuz Pratik'in işi.)
//
// Saf ve deterministik: Random(daySeed) tohumlu → aynı gün aynı sıra, test edilebilir.
// -----------------------------------------------------------------------------

/// Günün meydan okuması için deterministik beceri indeksleri (sıralı).
///
/// [skillCount] mevcut (açık) beceri sayısı, [daySeed] tarihten türetilir
/// (ör. yıl*10000 + ay*100 + gün). Uzunluk [segments]'tir. Beceri sayısı
/// segment sayısından az ise indeksler deterministik olarak tekrar eder;
/// mümkün olduğunca tekrar etmez (önce karıştırılmış diziyi tüketir).
List<int> dailyChallengeSkillIndices(
  int skillCount,
  int daySeed, {
  int segments = 3,
}) {
  if (skillCount <= 0 || segments <= 0) return const [];
  final rng = Random(daySeed);
  final shuffled = List<int>.generate(skillCount, (i) => i)..shuffle(rng);
  return [for (var i = 0; i < segments; i++) shuffled[i % shuffled.length]];
}

/// Bir tarihi deterministik gün tohumuna çevirir (yalnızca gün çözünürlüğü).
/// UI'dan çağrılır (saf mantık DateTime.now() bilmez).
int daySeedFor(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
