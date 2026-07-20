// -----------------------------------------------------------------------------
// SONSUZ PRATİK — ağırlıklı beceri seçimi (saf mantık, UI'sız)
//
// "Sonsuz Pratik" ekranı, kullanıcının öğrendiği TÜM becerilerden bitmeyen bir
// tanıma oturumu üretir. Hangi becerinin sıradaki mini-tura geleceğini bu dosya
// belirler: zayıf beceriler (düşük ustalık) ve kullanıcının o TİPTE çok
// karıştırdığı konular daha sık gelir. Böylece pratik, en çok işe yarayacağı
// yere odaklanır.
//
// Tamamen saf ve deterministiktir (Random/DateTime yok): rastgelelik UI'dan bir
// [roll] ∈ [0,1) olarak geçirilir → test edilebilir kalır.
// -----------------------------------------------------------------------------

/// Sonsuz pratikte yarışan tek bir beceri adayı (saf katman görünümü).
class DrillCandidate {
  /// İlerleme kaydındaki beceri kimliği (skillXp anahtarı = ders id'si).
  final String skillId;

  /// Karıştırma tipi belirteci: note/chord/quality/inv/interval/degree/function/prog.
  /// Karıştırma sayaçları bu önekle tutulur ('note:C>E' → 'note').
  final String type;

  const DrillCandidate({required this.skillId, required this.type});
}

/// [type] tipine ait tüm karıştırma sayaçlarının toplamı.
/// Anahtarlar 'tip:beklenen>seçilen' biçiminde olduğundan '$type:' önekiyle süzülür.
int typeConfusionTotal(Map<String, int> confusionCounts, String type) {
  final prefix = '$type:';
  var total = 0;
  confusionCounts.forEach((key, count) {
    if (key.startsWith(prefix)) total += count;
  });
  return total;
}

/// Bir adayın seçilme ağırlığı (her zaman > 0).
///
/// - **Taban 1:** her açık beceri en az bir şans alır (hiçbiri tamamen kaybolmaz).
/// - **Zayıflık:** ustalık ([skillXp]) düştükçe bonus 6 → 0'a doğru azalır
///   (yumuşak eğri: yeni/az çalışılmış beceriler öne çıkar, ustalaşılan geriler).
/// - **Karıştırma:** bu becerinin TİPİNDE biriken her karıştırma ağırlığı +1
///   artırır (kullanıcının en çok yanıldığı konu daha sık gelir).
double drillWeight(
  DrillCandidate c, {
  required Map<String, int> skillXp,
  required Map<String, int> confusionCounts,
}) {
  final xp = skillXp[c.skillId] ?? 0;
  final weakness = 6.0 / (1.0 + xp / 20.0);
  final confusion = typeConfusionTotal(confusionCounts, c.type).toDouble();
  return 1.0 + weakness + confusion;
}

/// Ağırlıklı rulet seçimi. [roll] ∈ [0,1) UI'dan (Random.nextDouble) geçirilir;
/// fonksiyon deterministiktir. Negatif ağırlıklar 0 sayılır. Liste boşsa -1,
/// toplam ağırlık 0 ise ilk indeks döner.
int pickWeightedIndex(List<double> weights, double roll) {
  if (weights.isEmpty) return -1;
  var total = 0.0;
  for (final w in weights) {
    if (w > 0) total += w;
  }
  if (total <= 0) return 0;
  final target = roll.clamp(0.0, 0.999999999) * total;
  var acc = 0.0;
  for (var i = 0; i < weights.length; i++) {
    if (weights[i] > 0) acc += weights[i];
    if (target < acc) return i;
  }
  return weights.length - 1;
}

/// Adayların ağırlıklarını hesaplar ve [roll] ile birini seçer → indeks.
/// Boş liste için -1 döner (çağıran koruma yapmalı).
int pickDrillIndex(
  List<DrillCandidate> candidates, {
  required Map<String, int> skillXp,
  required Map<String, int> confusionCounts,
  required double roll,
}) {
  if (candidates.isEmpty) return -1;
  final weights = [
    for (final c in candidates)
      drillWeight(c, skillXp: skillXp, confusionCounts: confusionCounts),
  ];
  return pickWeightedIndex(weights, roll);
}
