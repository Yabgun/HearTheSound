import 'dart:convert';

import 'spaced_repetition.dart';
import 'vocal_range.dart';

/// Günlük XP hedefi (alışkanlık motoru) — kullanıcının her gün ulaşması istenen XP.
const int kDailyXpGoal = 30;

/// [PlayerProgress.copyWith] için "verilmedi" işaretçisi. `null` geçerli bir
/// değer olduğundan (vocalRange'i temizlemek) null ile ayırt edilmesi gerekir.
const Object _unset = Object();

/// Kullanıcının kalıcı ilerlemesi — XP, günlük streak, günlük hedef, beceri
/// ustalığı ve tamamlanan dersler.
///
/// Tek bir JSON nesnesi olarak saklanır (serileştirmeyi repository yapar).
/// Değişmez (immutable); güncellemeler [copyWith] ile yeni bir kopya üretir.
class PlayerProgress {
  final int xp;
  final int streak; // güncel günlük seri
  final int longestStreak;
  final String? lastActiveDay; // 'yyyy-mm-dd' — streak & günlük hedef için
  final int dailyXp; // bugün kazanılan XP (gün değişince sıfırlanır)
  final Map<String, int> skillXp; // beceri kimliği -> ustalık puanı
  final List<String> completedLessons; // geçilmiş ders kimlikleri (kilit açar)
  final VocalRange? vocalRange; // ölçülmüş ses aralığı; null = kalibre edilmemiş
  final Map<String, ReviewState> reviews; // beceri kimliği -> aralıklı tekrar durumu

  const PlayerProgress({
    this.xp = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastActiveDay,
    this.dailyXp = 0,
    this.skillXp = const {},
    this.completedLessons = const [],
    this.vocalRange,
    this.reviews = const {},
  });

  static const empty = PlayerProgress();

  bool isLessonCompleted(String id) => completedLessons.contains(id);
  bool get dailyGoalMet => dailyXp >= kDailyXpGoal;

  /// Kullanıcı ses aralığını kalibre etmiş mi? (Söyleme oktavları buna uyarlanır.)
  bool get isCalibrated => vocalRange != null;

  /// [todayKey] ('yyyy-mm-dd') itibarıyla vadesi gelmiş tekrar becerileri.
  List<String> dueReviewSkills(String todayKey) => reviews.entries
      .where((e) => e.value.isDueOn(todayKey))
      .map((e) => e.key)
      .toList();

  /// [vocalRange] için özel: null geçilebilmesi gerektiğinden (temizleme)
  /// [copyWith] yerine sentinel kullanır — verilmezse mevcut değer korunur.
  PlayerProgress copyWith({
    int? xp,
    int? streak,
    int? longestStreak,
    String? lastActiveDay,
    int? dailyXp,
    Map<String, int>? skillXp,
    List<String>? completedLessons,
    Object? vocalRange = _unset,
    Map<String, ReviewState>? reviews,
  }) {
    return PlayerProgress(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      dailyXp: dailyXp ?? this.dailyXp,
      skillXp: skillXp ?? this.skillXp,
      completedLessons: completedLessons ?? this.completedLessons,
      vocalRange: identical(vocalRange, _unset)
          ? this.vocalRange
          : vocalRange as VocalRange?,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, dynamic> toMap() => {
        'xp': xp,
        'streak': streak,
        'longestStreak': longestStreak,
        'lastActiveDay': lastActiveDay,
        'dailyXp': dailyXp,
        'skillXp': skillXp,
        'completedLessons': completedLessons,
        'vocalRange': vocalRange?.toMap(),
        'reviews': reviews.map((k, v) => MapEntry(k, v.toMap())),
      };

  factory PlayerProgress.fromMap(Map<String, dynamic> map) {
    return PlayerProgress(
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDay: map['lastActiveDay'] as String?,
      dailyXp: (map['dailyXp'] as num?)?.toInt() ?? 0,
      skillXp: (map['skillXp'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toInt()),
          ) ??
          const {},
      completedLessons: (map['completedLessons'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      vocalRange: map['vocalRange'] == null
          ? null
          : VocalRange.fromMap((map['vocalRange'] as Map).cast<String, dynamic>()),
      reviews: (map['reviews'] as Map?)?.map(
            (key, value) => MapEntry(
              key as String,
              ReviewState.fromMap((value as Map).cast<String, dynamic>()),
            ),
          ) ??
          const {},
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PlayerProgress.fromJson(String source) =>
      PlayerProgress.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
