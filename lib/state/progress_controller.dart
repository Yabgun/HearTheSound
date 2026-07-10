import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/player_progress.dart';
import '../data/progress_repository.dart';

/// Repository sağlayıcısı — `main` içinde gerçek (prefs destekli) örnekle
/// override edilir. Böylece uygulama açılışta hazır veriyle başlar.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  throw UnimplementedError('progressRepositoryProvider main içinde override edilmeli');
});

/// İlerleme durumunu yöneten denetleyici: yükler, günceller, kaydeder.
class ProgressController extends Notifier<PlayerProgress> {
  ProgressRepository get _repo => ref.read(progressRepositoryProvider);

  @override
  PlayerProgress build() => _repo.load();

  /// Bir ders/oturum tamamlandığında çağrılır: XP ekler, günlük streak'i
  /// günceller, beceri ustalığını artırır ve kalıcı olarak kaydeder.
  void completeLesson({
    required String skillId,
    required int xpEarned,
    required int masteryGain,
    bool completed = false,
  }) {
    final now = DateTime.now();
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

    state = state.copyWith(
      xp: state.xp + xpEarned,
      streak: streak,
      longestStreak: math.max(state.longestStreak, streak),
      lastActiveDay: today,
      skillXp: newSkillXp,
      completedLessons: newCompleted,
    );
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
}

/// İlerleme sağlayıcısı — arayüz bunu izleyerek XP/streak/ustalığı gösterir.
final progressProvider =
    NotifierProvider<ProgressController, PlayerProgress>(ProgressController.new);
