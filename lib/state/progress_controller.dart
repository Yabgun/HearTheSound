import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/player_progress.dart';
import '../core/spaced_repetition.dart';
import '../core/vocal_range.dart';
import '../data/progress_repository.dart';

/// Repository sağlayıcısı — `main` içinde gerçek (prefs destekli) örnekle
/// override edilir. Böylece uygulama açılışta hazır veriyle başlar.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  throw UnimplementedError('progressRepositoryProvider main içinde override edilmeli');
});

/// Zamanı tek noktadan okur. Testlerde gün devrini güvenle canlandırabilmek için
/// override edilir; uygulamada gerçek saat kullanılır.
final progressClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// İlerleme durumunu yöneten denetleyici: yükler, günceller, kaydeder.
class ProgressController extends Notifier<PlayerProgress> {
  ProgressRepository get _repo => ref.read(progressRepositoryProvider);

  @override
  PlayerProgress build() {
    final loaded = _repo.load();
    final normalized = _normalizeForToday(loaded, ref.read(progressClockProvider)());
    if (!identical(loaded, normalized)) {
      unawaited(_repo.save(normalized));
    }
    return normalized;
  }

  /// Bir ders/oturum tamamlandığında çağrılır: XP ekler, günlük streak'i
  /// günceller, beceri ustalığını artırır, aralıklı tekrarı zamanlar ve kalıcı
  /// olarak kaydeder. [accuracy] (0..1) hem geçme hem tekrar kalitesi için.
  void completeLesson({
    required String skillId,
    required int xpEarned,
    required int masteryGain,
    required double accuracy,
    bool completed = false,
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

    state = state.copyWith(
      xp: state.xp + xpEarned,
      streak: streak,
      longestStreak: math.max(state.longestStreak, streak),
      lastActiveDay: today,
      dailyXp: newDailyXp,
      skillXp: newSkillXp,
      completedLessons: newCompleted,
      reviews: newReviews,
    );
    _repo.save(state);
  }

  /// Bir tekrar oturumu sonucu: XP + streak + günlük hedefi günceller ve o
  /// becerinin tekrar zamanını SM-2 ile ileri alır (kilit/ustalık değişmez).
  void recordReviewResult({
    required String skillId,
    required int xpEarned,
    required double accuracy,
  }) {
    completeLesson(
      skillId: skillId,
      xpEarned: xpEarned,
      masteryGain: 0,
      accuracy: accuracy,
      completed: false,
    );
  }

  /// Yerleştirme sonucu: bilindiği tespit edilen dersleri 'tamamlandı' işaretler
  /// (kilit açar). XP/streak vermez — pratik değil, yerleştirmedir.
  void applyPlacement(Iterable<String> knownSkillIds) {
    final set = <String>{...state.completedLessons, ...knownSkillIds};
    state = state.copyWith(completedLessons: set.toList());
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
    final normalizedStreak =
        progress.lastActiveDay == yesterday ? progress.streak : 0;

    if (progress.dailyXp == 0 && progress.streak == normalizedStreak) {
      return progress;
    }

    return progress.copyWith(
      dailyXp: 0,
      streak: normalizedStreak,
    );
  }
}

/// İlerleme sağlayıcısı — arayüz bunu izleyerek XP/streak/ustalığı gösterir.
final progressProvider =
    NotifierProvider<ProgressController, PlayerProgress>(ProgressController.new);
