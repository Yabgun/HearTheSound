import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/player_progress.dart';
import '../../core/rank.dart';
import '../../state/progress_controller.dart';
import '../calibration/calibration_page.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_flow_page.dart';
import '../settings/settings_page.dart';

// -----------------------------------------------------------------------------
// ANA EKRAN — yolculuğun "yuvası"
//
// Günlük hedef, streak, XP ve rütbe; ardından kilitli/açık/tamamlandı ders
// patikası. Bir dersten dönünce (progressProvider izlendiği için) her şey yansır.
// -----------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final rank = rankForXp(progress.xp);
    final next = nextRankAfter(progress.xp);

    double rankPct = 1;
    String nextLabel = 'En yüksek rütbedesin 🏆';
    if (next != null) {
      final span = next.minXp - rank.minXp;
      rankPct = span == 0 ? 1 : (progress.xp - rank.minXp) / span;
      nextLabel = '${next.minXp - progress.xp} XP → ${next.name}';
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Text(
                  'HearTheSound',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _streakChip(theme, progress.streak),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Ayarlar',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!progress.isCalibrated) ...[
              _calibrationBanner(context, theme),
              const SizedBox(height: 16),
            ],
            _dailyGoalCard(theme, progress.dailyXp),
            const SizedBox(height: 16),
            _rankCard(theme, rank, progress.xp, rankPct, nextLabel),
            const SizedBox(height: 28),
            Text(
              'Dersler',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < lessons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _lessonCard(
                  context,
                  theme,
                  lessons[i],
                  unlocked:
                      i == 0 || progress.isLessonCompleted(lessons[i - 1].id),
                  completed: progress.isLessonCompleted(lessons[i].id),
                  mastery: progress.skillXp[lessons[i].id] ?? 0,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Akorlar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < chordLessons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _chordPathCard(
                  context,
                  theme,
                  chordLessons[i],
                  unlocked: i == 0 ||
                      progress.isLessonCompleted(chordLessons[i - 1].id),
                  completed: progress.isLessonCompleted(chordLessons[i].id),
                  mastery: progress.skillXp[chordLessons[i].id] ?? 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Kalibre edilmemiş kullanıcı için: söylemeden önce ses aralığını ölçmeye
  /// davet eden nazik kart. Kalibrasyon tamamlanınca (isCalibrated) gizlenir.
  Widget _calibrationBanner(BuildContext context, ThemeData theme) {
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CalibrationPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.graphic_eq_rounded,
                  color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Önce sesini tanıyalım',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dersleri tam senin rahat oktavında hazırlamak için '
                      '~1 dakikalık ses aralığı ölçümü.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyGoalCard(ThemeData theme, int dailyXp) {
    final met = dailyXp >= kDailyXpGoal;
    final pct = (dailyXp / kDailyXpGoal).clamp(0.0, 1.0);
    const green = Color(0xFF56C271);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.today_rounded,
            color: met ? green : theme.colorScheme.primary,
            size: 34,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUGÜNKÜ HEDEF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  met ? 'Tamamlandı! 🎉' : '$dailyXp / $kDailyXpGoal XP',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: met ? green : null,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      met ? green : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankCard(
    ThemeData theme,
    Rank rank,
    int xp,
    double rankPct,
    String nextLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RÜTBEN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rank.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$xp XP',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rankPct.clamp(0, 1),
              minHeight: 8,
              backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakChip(ThemeData theme, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '🔥 $streak',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _chordPathCard(
    BuildContext context,
    ThemeData theme,
    ChordLesson lesson, {
    required bool unlocked,
    required bool completed,
    required int mastery,
  }) {
    const green = Color(0xFF56C271);
    final bg = unlocked
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final IconData icon;
    final Color iconColor;
    final String subtitle;
    if (completed) {
      icon = Icons.check_circle_rounded;
      iconColor = green;
      subtitle = 'tamamlandı · ustalık $mastery';
    } else if (unlocked) {
      icon = Icons.piano_rounded;
      iconColor = theme.colorScheme.primary;
      subtitle = 'başlamak için dokun';
    } else {
      icon = Icons.lock_rounded;
      iconColor = theme.colorScheme.outline;
      subtitle = 'önceki akoru geç';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unlocked
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChordLessonFlowPage(lesson: lesson),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: unlocked ? null : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (unlocked)
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lessonCard(
    BuildContext context,
    ThemeData theme,
    Lesson lesson, {
    required bool unlocked,
    required bool completed,
    required int mastery,
  }) {
    const green = Color(0xFF56C271);
    final bg = unlocked
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final IconData leadingIcon;
    final Color leadingColor;
    final String subtitle;
    if (completed) {
      leadingIcon = Icons.check_circle_rounded;
      leadingColor = green;
      subtitle = 'tamamlandı · ustalık $mastery';
    } else if (unlocked) {
      leadingIcon = Icons.music_note_rounded;
      leadingColor = theme.colorScheme.primary;
      subtitle = 'başlamak için dokun';
    } else {
      leadingIcon = Icons.lock_rounded;
      leadingColor = theme.colorScheme.outline;
      subtitle = 'önceki dersi geç';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unlocked
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonFlowPage(lesson: lesson),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(leadingIcon, color: leadingColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: unlocked ? null : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (unlocked)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
