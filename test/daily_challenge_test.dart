import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/daily_challenge.dart';
import 'package:hear_the_sound/core/merge_progress.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/state/progress_controller.dart';

class _MemoryRepo implements ProgressRepository {
  _MemoryRepo(this.progress);
  PlayerProgress progress;
  @override
  PlayerProgress load() => progress;
  @override
  Future<void> save(PlayerProgress p) async => progress = p;
}

void main() {
  group('dailyChallengeSkillIndices', () {
    test('aynı gün tohumu + beceri sayısı → aynı sıra (deterministik)', () {
      final a = dailyChallengeSkillIndices(6, 20260719);
      final b = dailyChallengeSkillIndices(6, 20260719);
      expect(a, b);
    });

    test('uzunluk segments; tüm indeksler aralıkta', () {
      final plan = dailyChallengeSkillIndices(6, 20260719, segments: 3);
      expect(plan.length, 3);
      for (final i in plan) {
        expect(i, inInclusiveRange(0, 5));
      }
    });

    test('beceri segment sayısından az ise indeks deterministik tekrar eder', () {
      final plan = dailyChallengeSkillIndices(2, 12345, segments: 3);
      expect(plan.length, 3);
      for (final i in plan) {
        expect(i, inInclusiveRange(0, 1));
      }
    });

    test('beceri yoksa boş plan', () {
      expect(dailyChallengeSkillIndices(0, 20260719), isEmpty);
      expect(dailyChallengeSkillIndices(5, 20260719, segments: 0), isEmpty);
    });
  });

  group('daySeedFor', () {
    test('aynı gün aynı tohum, farklı gün farklı tohum', () {
      expect(daySeedFor(DateTime(2026, 7, 19)), daySeedFor(DateTime(2026, 7, 19, 23)));
      expect(
        daySeedFor(DateTime(2026, 7, 19)),
        isNot(daySeedFor(DateTime(2026, 7, 20))),
      );
    });
  });

  group('lastChallengeDay — kalıcılık ve birleştirme', () {
    test('serileştirme gidiş-dönüşü korunur', () {
      const p = PlayerProgress(lastChallengeDay: '2026-07-19');
      final round = PlayerProgress.fromJson(p.toJson());
      expect(round.lastChallengeDay, '2026-07-19');
    });

    test('eski kayıt (alan yok) null ile açılır', () {
      final round = PlayerProgress.fromMap(const {'xp': 5});
      expect(round.lastChallengeDay, isNull);
    });

    test('mergeProgress daha yeni günü alır (simetrik)', () {
      const a = PlayerProgress(lastChallengeDay: '2026-07-19');
      const b = PlayerProgress(lastChallengeDay: '2026-07-18');
      expect(mergeProgress(a, b).lastChallengeDay, '2026-07-19');
      expect(mergeProgress(b, a).lastChallengeDay, '2026-07-19');
      const empty = PlayerProgress();
      expect(mergeProgress(a, empty).lastChallengeDay, '2026-07-19');
      expect(mergeProgress(empty, a).lastChallengeDay, '2026-07-19');
    });
  });

  group('completeDailyChallenge', () {
    test('bugünü işaretler; isChallengeDoneOn(bugün) true', () {
      final repo = _MemoryRepo(const PlayerProgress());
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(repo),
          progressClockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        ],
      );
      addTearDown(container.dispose);

      container.read(progressProvider.notifier).completeDailyChallenge();

      final p = container.read(progressProvider);
      expect(p.lastChallengeDay, '2026-07-19');
      expect(p.isChallengeDoneOn('2026-07-19'), isTrue);
      expect(p.isChallengeDoneOn('2026-07-20'), isFalse);
      expect(repo.progress.lastChallengeDay, '2026-07-19'); // kalıcı yazıldı
    });
  });
}
