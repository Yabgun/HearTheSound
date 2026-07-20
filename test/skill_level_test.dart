import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/merge_progress.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/state/progress_controller.dart';

// §1B Taç/Ustalık seviyeleri — skillLevel kalıcılığı, birleştirme ve
// completeLesson üzerinden seviye yükseltme kuralları.

class _MemoryRepo implements ProgressRepository {
  _MemoryRepo(this.progress);
  PlayerProgress progress;
  @override
  PlayerProgress load() => progress;
  @override
  Future<void> save(PlayerProgress p) async => progress = p;
}

ProviderContainer _container(PlayerProgress initial) {
  final c = ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(_MemoryRepo(initial)),
      progressClockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('skillLevel — kalıcılık & birleştirme', () {
    test('serileştirme gidiş-dönüşü korunur', () {
      const p = PlayerProgress(skillLevel: {'first_notes': 3});
      expect(
        PlayerProgress.fromJson(p.toJson()).skillLevelOf('first_notes'),
        3,
      );
    });

    test('eski kayıt (alan yok) → seviye 0', () {
      expect(PlayerProgress.fromMap(const {'xp': 1}).skillLevelOf('x'), 0);
    });

    test('mergeProgress anahtar başına max (taç geri düşmez), simetrik', () {
      const a = PlayerProgress(skillLevel: {'s': 3, 'only_a': 2});
      const b = PlayerProgress(skillLevel: {'s': 1, 'only_b': 4});
      final m = mergeProgress(a, b);
      expect(m.skillLevelOf('s'), 3);
      expect(m.skillLevelOf('only_a'), 2);
      expect(m.skillLevelOf('only_b'), 4);
      expect(mergeProgress(b, a).skillLevelOf('s'), 3);
    });
  });

  group('completeLesson — taç yükseltme', () {
    test('geçilince (completed) reachedLevel seviyeyi yükseltir', () {
      final c = _container(const PlayerProgress());
      c
          .read(progressProvider.notifier)
          .completeLesson(
            skillId: 'first_notes',
            xpEarned: 80,
            masteryGain: 8,
            accuracy: 1.0,
            completed: true,
            reachedLevel: 1,
          );
      expect(c.read(progressProvider).skillLevelOf('first_notes'), 1);
    });

    test('geçilmezse (completed:false) seviye değişmez', () {
      final c = _container(const PlayerProgress(skillLevel: {'first_notes': 2}));
      c
          .read(progressProvider.notifier)
          .completeLesson(
            skillId: 'first_notes',
            xpEarned: 10,
            masteryGain: 1,
            accuracy: 0.4,
            completed: false,
            reachedLevel: 3,
          );
      expect(c.read(progressProvider).skillLevelOf('first_notes'), 2);
    });

    test('seviye asla geri düşmez; tavanı (kMaxSkillLevel) aşmaz', () {
      final c = _container(const PlayerProgress(skillLevel: {'s': 3}));
      final n = c.read(progressProvider.notifier);
      // daha düşük hedef geri düşürmez
      n.completeLesson(
        skillId: 's',
        xpEarned: 10,
        masteryGain: 1,
        accuracy: 1,
        completed: true,
        reachedLevel: 2,
      );
      expect(c.read(progressProvider).skillLevelOf('s'), 3);
      // tavanı aşmaz
      n.completeLesson(
        skillId: 's',
        xpEarned: 10,
        masteryGain: 1,
        accuracy: 1,
        completed: true,
        reachedLevel: 99,
      );
      expect(c.read(progressProvider).skillLevelOf('s'), kMaxSkillLevel);
    });
  });
}
