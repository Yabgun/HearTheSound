import 'dart:math' as math;

// -----------------------------------------------------------------------------
// ARALIKLI TEKRAR — SM-2 algoritması
//
// Her beceri (ders) için bir [ReviewState] tutulur: bir sonraki tekrarın ne
// zaman geleceğini, ne kadar kolay hatırlandığını (ease) ve seri/lapse'i.
// Klasik SuperMemo-2: doğruluk → kalite (0-5) → yeni aralık. Unutmadan önce
// getirmenin amacı: kolay hatırlananları seyrek, zorları sık tekrar etmek.
//
// Tarih hesapları saf tutulur: fonksiyona "şimdi" dışarıdan verilir (test
// edilebilirlik). Gün anahtarı 'yyyy-mm-dd' (ISO) — string karşılaştırması
// kronolojik sıralamayla aynı.
// -----------------------------------------------------------------------------

/// Gün anahtarı (yerel tarih, saat atılır). Streak/tekrar mantığı bunu kullanır.
String dayKeyFor(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Bir tanıma oturumu doğruluğunu (0..1) SM-2 kalitesine (0..5) çevirir.
int qualityFromAccuracy(double accuracy) {
  if (accuracy >= 0.95) return 5;
  if (accuracy >= 0.85) return 4;
  if (accuracy >= 0.70) return 3; // "geçer" eşiği
  if (accuracy >= 0.50) return 2;
  if (accuracy >= 0.30) return 1;
  return 0;
}

/// Bir becerinin tekrar durumu (kalıcı). Değişmez.
class ReviewState {
  final double ease; // kolaylık faktörü (min 1.3)
  final int intervalDays; // son verilen aralık
  final int reps; // ardışık başarılı tekrar
  final int lapses; // toplam unutma (q<3)
  final String dueDay; // 'yyyy-mm-dd' — vadesi
  final String lastReviewedDay;

  const ReviewState({
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.lapses,
    required this.dueDay,
    required this.lastReviewedDay,
  });

  /// Verilen gün anahtarında (veya öncesinde) vadesi gelmiş mi?
  bool isDueOn(String todayKey) => dueDay.compareTo(todayKey) <= 0;

  Map<String, dynamic> toMap() => {
    'ease': ease,
    'intervalDays': intervalDays,
    'reps': reps,
    'lapses': lapses,
    'dueDay': dueDay,
    'lastReviewedDay': lastReviewedDay,
  };

  factory ReviewState.fromMap(Map<String, dynamic> map) => ReviewState(
    ease: (map['ease'] as num?)?.toDouble() ?? 2.5,
    intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 1,
    reps: (map['reps'] as num?)?.toInt() ?? 0,
    lapses: (map['lapses'] as num?)?.toInt() ?? 0,
    dueDay: map['dueDay'] as String? ?? '',
    lastReviewedDay: map['lastReviewedDay'] as String? ?? '',
  );

  @override
  String toString() =>
      'ReviewState(due=$dueDay, interval=${intervalDays}g, ease=${ease.toStringAsFixed(2)}, reps=$reps)';
}

/// SM-2 başlangıç kolaylık faktörü.
const double _initialEase = 2.5;
const double _minEase = 1.3;

/// Bir tekrar/ders sonucunu uygular ve yeni [ReviewState]'i döndürür.
///
/// [prev] null ise beceri ilk kez zamanlanıyordur. [accuracy] oturum doğruluğu
/// (0..1). [now] "şimdi" (saf tutmak için dışarıdan verilir).
ReviewState applyReview({
  ReviewState? prev,
  required double accuracy,
  required DateTime now,
}) {
  final q = qualityFromAccuracy(accuracy);
  final today = DateTime(now.year, now.month, now.day);

  var ease = prev?.ease ?? _initialEase;
  var reps = prev?.reps ?? 0;
  var lapses = prev?.lapses ?? 0;
  final int interval;

  if (q < 3) {
    // Başarısız hatırlama → sıfırla, yarın tekrar getir.
    reps = 0;
    lapses += 1;
    interval = 1;
  } else {
    // Aralık, GÜNCELLEME ÖNCESİ ease ile hesaplanır (klasik SM-2).
    if (reps == 0) {
      interval = 1;
    } else if (reps == 1) {
      interval = 6;
    } else {
      interval = math.max(1, ((prev?.intervalDays ?? 1) * ease).round());
    }
    reps += 1;
  }

  // Ease güncellemesi (bir sonraki sefer için).
  ease = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (ease < _minEase) ease = _minEase;

  final due = today.add(Duration(days: interval));
  return ReviewState(
    ease: ease,
    intervalDays: interval,
    reps: reps,
    lapses: lapses,
    dueDay: dayKeyFor(due),
    lastReviewedDay: dayKeyFor(today),
  );
}
