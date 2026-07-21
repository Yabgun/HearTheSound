import 'dart:convert';

import 'player_profile.dart';
import 'schema_migration.dart';
import 'spaced_repetition.dart';
import 'vocal_range.dart';

/// Günlük XP hedefi (alışkanlık motoru) — kullanıcının her gün ulaşması istenen XP.
const int kDailyXpGoal = 30;

/// En yüksek ustalık/taç seviyesi. Tamamlanmış bir ders, her geçişte bir üst
/// seviyeye taşınarak (daha çok soru · ipuçsuz · XP çarpanı) bu tavana dek
/// yeniden oynanabilir — "crown" tekrar-oynanabilirliği.
const int kMaxSkillLevel = 5;

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
  final Map<String, int>
  skillLevel; // beceri kimliği -> ustalık/taç seviyesi (0..kMaxSkillLevel)
  final List<String> completedLessons; // geçilmiş ders kimlikleri (kilit açar)
  final VocalRange?
  vocalRange; // ölçülmüş ses aralığı; null = kalibre edilmemiş
  final Map<String, ReviewState>
  reviews; // beceri kimliği -> aralıklı tekrar durumu

  /// Karıştırma sayaçları: 'tip:beklenen>seçilen' -> kaç kez.
  /// (Ör. 'quality:major7>dominant7' -> 3). Profildeki "en çok karıştırdıkların"
  /// içgörüsünü besler; anahtarlar dil-bağımsızdır (i18n'e dayanıklı).
  final Map<String, int> confusionCounts;

  /// Günün meydan okumasının son tamamlandığı gün ('yyyy-mm-dd'); null = hiç.
  /// Bugün ekranındaki "Günün Meydan Okuması" rozetini besler.
  final String? lastChallengeDay;

  /// Kullanıcının kendi belirlediği kimlik (ad, avatar, üyelik tarihi).
  /// Şema v2'de eklendi; eski kayıtlarda boş gelir.
  final PlayerProfile profile;

  /// Bu verinin taşıdığı şema sürümü (bkz. `schema_migration.dart`).
  ///
  /// Uygulama içinde üretilen ilerleme her zaman güncel sürümdedir; yalnızca
  /// DISARIDAN okunan (yerel kayıt / bulut) veri farklı olabilir. Hedeften
  /// büyük bir değer, verinin bu uygulamadan YENİ olduğunu söyler —
  /// bkz. [isFromFutureSchema].
  final int schemaVersion;

  const PlayerProgress({
    this.xp = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastActiveDay,
    this.dailyXp = 0,
    this.skillXp = const {},
    this.skillLevel = const {},
    this.completedLessons = const [],
    this.vocalRange,
    this.reviews = const {},
    this.confusionCounts = const {},
    this.lastChallengeDay,
    this.profile = PlayerProfile.empty,
    this.schemaVersion = kProgressSchemaVersion,
  });

  static const empty = PlayerProgress();

  /// Veri bu uygulamanın anladığından YENİ bir şemadan mı geldi?
  ///
  /// Tipik senaryo: kullanıcının bir cihazı güncel, diğeri değil. Eski cihaz
  /// yeni alanları anlamaz ve okurken düşürür — bu yüzden o veriyi buluta
  /// GERİ YAZMAMALIDIR (bkz. `CloudSync._upsert`), yoksa güncel cihazın
  /// ilerlemesini sessizce budar.
  bool get isFromFutureSchema => schemaVersion > kProgressSchemaVersion;

  bool isLessonCompleted(String id) => completedLessons.contains(id);
  bool get dailyGoalMet => dailyXp >= kDailyXpGoal;

  /// Günün meydan okuması [dayKey] ('yyyy-mm-dd') gününde tamamlandı mı?
  bool isChallengeDoneOn(String dayKey) => lastChallengeDay == dayKey;

  /// Bir becerinin ustalık/taç seviyesi (0 = temel; kilitli değilse hep ≥0).
  int skillLevelOf(String id) => skillLevel[id] ?? 0;

  /// Kullanıcı ses aralığını kalibre etmiş mi? (Söyleme oktavları buna uyarlanır.)
  bool get isCalibrated => vocalRange != null;

  /// [todayKey] ('yyyy-mm-dd') itibarıyla vadesi gelmiş tekrar becerileri.
  /// En çok UNUTULAN (lapses yüksek) beceriler öne gelir — zor olan önce çalışılır.
  List<String> dueReviewSkills(String todayKey) {
    final due = reviews.entries.where((e) => e.value.isDueOn(todayKey)).toList()
      ..sort((a, b) {
        final byLapses = b.value.lapses.compareTo(a.value.lapses);
        // Eşitlikte anahtar sırası: deterministik kalsın (test edilebilirlik).
        return byLapses != 0 ? byLapses : a.key.compareTo(b.key);
      });
    return [for (final e in due) e.key];
  }

  /// [vocalRange] için özel: null geçilebilmesi gerektiğinden (temizleme)
  /// [copyWith] yerine sentinel kullanır — verilmezse mevcut değer korunur.
  PlayerProgress copyWith({
    int? xp,
    int? streak,
    int? longestStreak,
    String? lastActiveDay,
    int? dailyXp,
    Map<String, int>? skillXp,
    Map<String, int>? skillLevel,
    List<String>? completedLessons,
    Object? vocalRange = _unset,
    Map<String, ReviewState>? reviews,
    Map<String, int>? confusionCounts,
    String? lastChallengeDay,
    PlayerProfile? profile,
    int? schemaVersion,
  }) {
    return PlayerProgress(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      dailyXp: dailyXp ?? this.dailyXp,
      skillXp: skillXp ?? this.skillXp,
      skillLevel: skillLevel ?? this.skillLevel,
      completedLessons: completedLessons ?? this.completedLessons,
      vocalRange: identical(vocalRange, _unset)
          ? this.vocalRange
          : vocalRange as VocalRange?,
      reviews: reviews ?? this.reviews,
      confusionCounts: confusionCounts ?? this.confusionCounts,
      lastChallengeDay: lastChallengeDay ?? this.lastChallengeDay,
      profile: profile ?? this.profile,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    // Damga en başta: veritabanı satırına bakınca ilk görülen alan olsun.
    'schemaVersion': schemaVersion,
    'xp': xp,
    'streak': streak,
    'longestStreak': longestStreak,
    'lastActiveDay': lastActiveDay,
    'dailyXp': dailyXp,
    'skillXp': skillXp,
    'skillLevel': skillLevel,
    'completedLessons': completedLessons,
    'vocalRange': vocalRange?.toMap(),
    'reviews': reviews.map((k, v) => MapEntry(k, v.toMap())),
    'confusionCounts': confusionCounts,
    'lastChallengeDay': lastChallengeDay,
    'profile': profile.toMap(),
  };

  /// Kayıttan ilerleme okur.
  ///
  /// **TEK BOĞAZ NOKTASI:** hem yerel kayıt (`PrefsProgressRepository.load`)
  /// hem bulut indirmesi (`CloudSync.pullAndMerge`) buradan geçer — dolayısıyla
  /// şema göçü her iki yolda da tek yerde, garanti çalışır.
  factory PlayerProgress.fromMap(Map<String, dynamic> map) {
    final m = migrateProgressMap(map);
    return PlayerProgress(
      xp: (m['xp'] as num?)?.toInt() ?? 0,
      streak: (m['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (m['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDay: m['lastActiveDay'] as String?,
      dailyXp: (m['dailyXp'] as num?)?.toInt() ?? 0,
      skillXp:
          (m['skillXp'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toInt()),
          ) ??
          const {},
      skillLevel:
          (m['skillLevel'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toInt()),
          ) ??
          const {},
      completedLessons:
          (m['completedLessons'] as List?)?.map((e) => e as String).toList() ??
          const [],
      vocalRange: m['vocalRange'] == null
          ? null
          : VocalRange.fromMap((m['vocalRange'] as Map).cast<String, dynamic>()),
      reviews:
          (m['reviews'] as Map?)?.map(
            (key, value) => MapEntry(
              key as String,
              ReviewState.fromMap((value as Map).cast<String, dynamic>()),
            ),
          ) ??
          const {},
      confusionCounts:
          (m['confusionCounts'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toInt()),
          ) ??
          const {},
      lastChallengeDay: m['lastChallengeDay'] as String?,
      profile: PlayerProfile.fromMap(
        (m['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      schemaVersion: readSchemaVersion(m),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PlayerProgress.fromJson(String source) =>
      PlayerProgress.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
