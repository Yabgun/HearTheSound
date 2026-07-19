import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/merge_progress.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/core/spaced_repetition.dart';
import 'package:hear_the_sound/core/vocal_range.dart';

// Bulut senkronunun kalbi: iki cihazın ilerlemesi KAYIPSIZ birleşmeli.
void main() {
  ReviewState review({required String day, int reps = 1, int lapses = 0}) =>
      ReviewState(
        ease: 2.5,
        intervalDays: 6,
        reps: reps,
        lapses: lapses,
        dueDay: '2026-08-01',
        lastReviewedDay: day,
      );

  test('xp/longestStreak max alınır; dersler birleşir', () {
    const a = PlayerProgress(
      xp: 500,
      longestStreak: 7,
      completedLessons: ['first_notes', 'l2_cde'],
    );
    const b = PlayerProgress(
      xp: 320,
      longestStreak: 12,
      completedLessons: ['first_notes', 'ch1'],
    );

    final m = mergeProgress(a, b);
    expect(m.xp, 500);
    expect(m.longestStreak, 12);
    expect(m.completedLessons.toSet(), {'first_notes', 'l2_cde', 'ch1'});
  });

  test('streak/dailyXp daha yeni günden gelir', () {
    const older = PlayerProgress(
      streak: 9,
      dailyXp: 40,
      lastActiveDay: '2026-07-10',
    );
    const newer = PlayerProgress(
      streak: 2,
      dailyXp: 15,
      lastActiveDay: '2026-07-18',
    );

    final m = mergeProgress(older, newer);
    expect(m.streak, 2, reason: 'yeni günün serisi geçerli');
    expect(m.dailyXp, 15);
    expect(m.lastActiveDay, '2026-07-18');
  });

  test('skillXp ve confusionCounts anahtar başına max', () {
    const a = PlayerProgress(
      skillXp: {'ch1': 30, 'iv1': 5},
      confusionCounts: {'note:C>E': 4},
    );
    const b = PlayerProgress(
      skillXp: {'ch1': 22, 'fn1': 9},
      confusionCounts: {'note:C>E': 2, 'quality:major7>dominant7': 3},
    );

    final m = mergeProgress(a, b);
    expect(m.skillXp, {'ch1': 30, 'iv1': 5, 'fn1': 9});
    expect(m.confusionCounts, {'note:C>E': 4, 'quality:major7>dominant7': 3});
  });

  test('reviews beceri başına daha yeni tekrar durumunu alır', () {
    final a = PlayerProgress(
      reviews: {
        'ch1': review(day: '2026-07-15', reps: 3),
        'iv1': review(day: '2026-07-01'),
      },
    );
    final b = PlayerProgress(
      reviews: {
        'ch1': review(day: '2026-07-10', reps: 9),
        'fn1': review(day: '2026-07-12'),
      },
    );

    final m = mergeProgress(a, b);
    expect(m.reviews['ch1']!.lastReviewedDay, '2026-07-15');
    expect(m.reviews['ch1']!.reps, 3, reason: 'yeni gün kazanır, reps değil');
    expect(m.reviews.keys.toSet(), {'ch1', 'iv1', 'fn1'});
  });

  test('vocalRange daha yeni kalibrasyonu alır', () {
    final a = PlayerProgress(
      vocalRange: VocalRange(
        comfortLow: 48,
        comfortHigh: 60,
        stretchLow: 45,
        stretchHigh: 64,
        calibratedAt: DateTime(2026, 7, 1),
      ),
    );
    final b = PlayerProgress(
      vocalRange: VocalRange(
        comfortLow: 50,
        comfortHigh: 62,
        stretchLow: 47,
        stretchHigh: 65,
        calibratedAt: DateTime(2026, 7, 16),
      ),
    );

    final m = mergeProgress(a, b);
    expect(m.vocalRange!.comfortLow, 50);
  });

  test('simetrik: merge(a,b) == merge(b,a) (alan alan)', () {
    final a = PlayerProgress(
      xp: 100,
      streak: 3,
      lastActiveDay: '2026-07-17',
      dailyXp: 20,
      skillXp: const {'ch1': 10},
      completedLessons: const ['first_notes'],
      reviews: {'ch1': review(day: '2026-07-17')},
      confusionCounts: const {'note:C>E': 1},
    );
    final b = PlayerProgress(
      xp: 240,
      streak: 6,
      lastActiveDay: '2026-07-18',
      dailyXp: 35,
      skillXp: const {'iv1': 4},
      completedLessons: const ['first_notes', 'iv1'],
      reviews: {'iv1': review(day: '2026-07-18')},
      confusionCounts: const {'interval:4>3': 2},
    );

    final ab = mergeProgress(a, b);
    final ba = mergeProgress(b, a);
    expect(
      ab.toMap()..remove('completedLessons'),
      ba.toMap()..remove('completedLessons'),
    );
    expect(
      ab.completedLessons.toSet(),
      ba.completedLessons.toSet(),
      reason: 'ders kümesi aynı (sıra farklı olabilir)',
    );
  });

  test('boş uzak veri yereli değiştirmez', () {
    const local = PlayerProgress(
      xp: 999,
      completedLessons: ['first_notes'],
      skillXp: {'ch1': 5},
    );
    final m = mergeProgress(local, PlayerProgress.empty);
    expect(m.xp, 999);
    expect(m.completedLessons, ['first_notes']);
  });
}
