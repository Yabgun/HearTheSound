import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/player_profile.dart';
import '../core/player_progress.dart';
import '../core/spaced_repetition.dart';
import '../core/vocal_range.dart';
import '../data/progress_repository.dart';

/// Repository sağlayıcısı — `main` içinde gerçek (prefs destekli) örnekle
/// override edilir. Böylece uygulama açılışta hazır veriyle başlar.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  throw UnimplementedError(
    'progressRepositoryProvider main içinde override edilmeli',
  );
});

/// Zamanı tek noktadan okur. Testlerde gün devrini güvenle canlandırabilmek için
/// override edilir; uygulamada gerçek saat kullanılır.
final progressClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// İlerleme durumunu yöneten denetleyici: yükler, günceller, kaydeder.
class ProgressController extends Notifier<PlayerProgress> {
  ProgressRepository get _repo => ref.read(progressRepositoryProvider);

  @override
  PlayerProgress build() {
    final loaded = _repo.load();
    final now = ref.read(progressClockProvider)();
    var normalized = _normalizeForToday(loaded, now);

    // "Üyelik tarihi": ilk açılışta bir kez damgalanır. Buradan damgalıyoruz
    // çünkü uygulamanın gerçekten ilk çalıştığı an burasıdır; birleştirmede
    // en ERKEN tarih kazandığı için başka cihazın daha eski damgası korunur.
    if (normalized.profile.joinedAt == null) {
      normalized = normalized.copyWith(
        profile: normalized.profile.copyWith(joinedAt: now),
      );
    }

    if (!identical(loaded, normalized)) {
      unawaited(_repo.save(normalized));
    }
    return normalized;
  }

  /// Görünen adı belirler. Boş/boşluk-only değer adı KALDIRIR.
  ///
  /// (Avatarla ayrı metotlar: tek bir `updateProfile({displayName, avatarId})`
  /// olsaydı `null` hem "dokunma" hem "sil" anlamına gelir, yalnızca avatarı
  /// değiştiren çağrı kullanıcının adını sessizce silerdi.)
  void setDisplayName(String? name) {
    final trimmed = name?.trim();
    state = state.copyWith(
      profile: PlayerProfile(
        displayName: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        avatarId: state.profile.avatarId,
        joinedAt: state.profile.joinedAt,
      ),
    );
    _repo.save(state);
  }

  /// Avatar (Eko renk varyantı) kimliğini belirler.
  void setAvatar(String avatarId) {
    state = state.copyWith(
      profile: state.profile.copyWith(avatarId: avatarId),
    );
    _repo.save(state);
  }

  /// Bir ders/oturum tamamlandığında çağrılır: XP ekler, günlük streak'i
  /// günceller, beceri ustalığını artırır, aralıklı tekrarı zamanlar ve kalıcı
  /// olarak kaydeder. [accuracy] (0..1) hem geçme hem tekrar kalitesi için.
  /// [mistakes] tanıma yanlışlarının karıştırma anahtarları ('note:C>E' gibi);
  /// sayaçlara eklenir ve profildeki içgörüyü besler.
  void completeLesson({
    required String skillId,
    required int xpEarned,
    required int masteryGain,
    required double accuracy,
    bool completed = false,
    List<String> mistakes = const [],
    int? reachedLevel,
  }) {
    final now = ref.read(progressClockProvider)();
    final today = _dayKey(now);
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

    var streak = state.streak;
    final last = state.lastActiveDay;
    if (last == today) {
      // Bugün zaten oynanmış — streak değişmez.
    } else if (last == yesterday) {
      streak += 1; // dün de oynamış -> seri devam
    } else {
      streak = 1; // ilk kez ya da seri kırılmış
    }

    final newSkillXp = Map<String, int>.from(state.skillXp);
    newSkillXp[skillId] = (newSkillXp[skillId] ?? 0) + masteryGain;

    // Ustalık/taç seviyesi: yalnızca beceri GEÇİLDİYSE (completed) ve daha yüksek
    // bir seviye ulaşıldıysa yüksel; tavanla sınırlı, asla geri düşmez.
    final newSkillLevel = Map<String, int>.from(state.skillLevel);
    if (completed && reachedLevel != null) {
      final target = reachedLevel > kMaxSkillLevel
          ? kMaxSkillLevel
          : reachedLevel;
      if (target > (newSkillLevel[skillId] ?? 0)) {
        newSkillLevel[skillId] = target;
      }
    }

    final newCompleted = List<String>.from(state.completedLessons);
    if (completed && !newCompleted.contains(skillId)) {
      newCompleted.add(skillId);
    }

    // Günlük XP: aynı günse ekle, yeni günse sıfırdan başlat.
    final newDailyXp = (last == today) ? state.dailyXp + xpEarned : xpEarned;

    // Aralıklı tekrar: beceri geçildiyse (veya zaten tekrar rotasyonundaysa)
    // SM-2 ile bir sonraki tekrarı zamanla.
    final newReviews = Map<String, ReviewState>.from(state.reviews);
    if (completed || newReviews.containsKey(skillId)) {
      newReviews[skillId] = applyReview(
        prev: newReviews[skillId],
        accuracy: accuracy,
        now: now,
      );
    }

    // Karıştırma sayaçları: her yanlış cevabın anahtarını biriktir.
    var newConfusions = state.confusionCounts;
    if (mistakes.isNotEmpty) {
      newConfusions = Map<String, int>.from(state.confusionCounts);
      for (final key in mistakes) {
        newConfusions[key] = (newConfusions[key] ?? 0) + 1;
      }
    }

    state = state.copyWith(
      xp: state.xp + xpEarned,
      streak: streak,
      longestStreak: math.max(state.longestStreak, streak),
      lastActiveDay: today,
      dailyXp: newDailyXp,
      skillXp: newSkillXp,
      skillLevel: newSkillLevel,
      completedLessons: newCompleted,
      reviews: newReviews,
      confusionCounts: newConfusions,
    );
    _repo.save(state);
  }

  /// Bir tekrar oturumu sonucu: XP + streak + günlük hedefi günceller ve o
  /// becerinin tekrar zamanını SM-2 ile ileri alır (kilit/ustalık değişmez).
  void recordReviewResult({
    required String skillId,
    required int xpEarned,
    required double accuracy,
    List<String> mistakes = const [],
  }) {
    completeLesson(
      skillId: skillId,
      xpEarned: xpEarned,
      masteryGain: 0,
      accuracy: accuracy,
      completed: false,
      mistakes: mistakes,
    );
  }

  /// Yerleştirme sonucu: bilindiği tespit edilen dersleri 'tamamlandı' işaretler
  /// (kilit açar). XP/streak vermez — pratik değil, yerleştirmedir.
  void applyPlacement(Iterable<String> knownSkillIds) {
    final set = <String>{...state.completedLessons, ...knownSkillIds};
    state = state.copyWith(completedLessons: set.toList());
    _repo.save(state);
  }

  /// Günün meydan okuması tamamlandı: bugünü işaretle (Bugün ekranındaki rozet).
  /// XP/ustalık/karıştırma zaten mini-turlar sırasında [completeLesson] ile işlendi.
  void completeDailyChallenge() {
    final today = _dayKey(ref.read(progressClockProvider)());
    if (state.lastChallengeDay == today) return;
    state = state.copyWith(lastChallengeDay: today);
    _repo.save(state);
  }

  /// Kalibrasyon sonucu ses aralığını kaydeder (söyleme oktavları buna uyarlanır).
  void setVocalRange(VocalRange range) {
    state = state.copyWith(vocalRange: range);
    _repo.save(state);
  }

  /// Ses aralığı kalibrasyonunu temizler (yeniden kalibre etmeden önce ya da test).
  void clearVocalRange() {
    state = state.copyWith(vocalRange: null);
    _repo.save(state);
  }

  /// Repo'dan yeniden yükler (bulut birleştirmesi yerele yazıldıktan sonra
  /// arayüzü tazelemek için — Ayarlar'daki giriş/eşitleme akışı çağırır).
  void reload() {
    state = _normalizeForToday(_repo.load(), ref.read(progressClockProvider)());
  }

  /// Geliştirme/test için ilerlemeyi sıfırlar.
  void reset() {
    state = PlayerProgress.empty;
    _repo.save(state);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  PlayerProgress _normalizeForToday(PlayerProgress progress, DateTime now) {
    final today = _dayKey(now);
    if (progress.lastActiveDay == today) return progress;

    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
    final normalizedStreak = progress.lastActiveDay == yesterday
        ? progress.streak
        : 0;

    if (progress.dailyXp == 0 && progress.streak == normalizedStreak) {
      return progress;
    }

    return progress.copyWith(dailyXp: 0, streak: normalizedStreak);
  }
}

/// İlerleme sağlayıcısı — arayüz bunu izleyerek XP/streak/ustalığı gösterir.
final progressProvider = NotifierProvider<ProgressController, PlayerProgress>(
  ProgressController.new,
);
