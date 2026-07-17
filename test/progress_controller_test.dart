import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/state/progress_controller.dart';

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository(this.progress);

  PlayerProgress progress;
  PlayerProgress? saved;

  @override
  PlayerProgress load() => progress;

  @override
  Future<void> save(PlayerProgress progress) async {
    this.progress = progress;
    saved = progress;
  }
}

ProviderContainer _container({
  required _MemoryProgressRepository repo,
  required DateTime now,
}) {
  final container = ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      progressClockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('gün değişince günlük XP sıfırlanır, dün oynandıysa streak korunur', () {
    final repo = _MemoryProgressRepository(
      const PlayerProgress(
        xp: 120,
        streak: 3,
        longestStreak: 5,
        lastActiveDay: '2026-07-12',
        dailyXp: 40,
      ),
    );
    final container = _container(repo: repo, now: DateTime(2026, 7, 13));

    final progress = container.read(progressProvider);

    expect(progress.dailyXp, 0);
    expect(progress.streak, 3);
    expect(progress.lastActiveDay, '2026-07-12');
    expect(repo.saved?.dailyXp, 0);
  });

  test('streak, dün değil daha eski bir günde kalmışsa ana ekranda sıfırlanır', () {
    final repo = _MemoryProgressRepository(
      const PlayerProgress(
        xp: 120,
        streak: 3,
        longestStreak: 5,
        lastActiveDay: '2026-07-10',
        dailyXp: 40,
      ),
    );
    final container = _container(repo: repo, now: DateTime(2026, 7, 13));

    final progress = container.read(progressProvider);

    expect(progress.dailyXp, 0);
    expect(progress.streak, 0);
    expect(progress.longestStreak, 5);
  });

  test('yeni günde ilk ders bitince streak dünden devam eder', () {
    final repo = _MemoryProgressRepository(
      const PlayerProgress(
        xp: 120,
        streak: 3,
        longestStreak: 5,
        lastActiveDay: '2026-07-12',
        dailyXp: 40,
      ),
    );
    final container = _container(repo: repo, now: DateTime(2026, 7, 13));

    container.read(progressProvider.notifier).completeLesson(
          skillId: 'first_notes',
          xpEarned: 10,
          masteryGain: 1,
          accuracy: 1,
          completed: true,
        );
    final progress = container.read(progressProvider);

    expect(progress.dailyXp, 10);
    expect(progress.streak, 4);
    expect(progress.lastActiveDay, '2026-07-13');
  });
}
