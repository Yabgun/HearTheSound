import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../core/player_progress.dart';
import '../../core/rank.dart';
import '../../core/spaced_repetition.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_theme.dart';
import '../calibration/calibration_page.dart';
import '../mascot/eko_mascot.dart';
import '../review/review_session_page.dart';
import 'curriculum.dart';

// -----------------------------------------------------------------------------
// BUGÜN — ana ekran. "Depo" değil, tek net eylem.
//
// Kaldığın yerden "Devam Et" + bugünün planı (yeni ders + tekrarlar) + özet.
// Tüm müfredat ayrı "Yol Haritası" sekmesinde; burada karar yükü yok.
// -----------------------------------------------------------------------------

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final rank = rankForXp(progress.xp);
    final due = progress.dueReviewSkills(dayKeyFor(DateTime.now()));
    final next = nextLesson(progress);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          // Selam + Eko + streak
          Row(
            children: [
              const EkoMascot(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(en: 'Hey! 👋', tr: 'Selam! 👋'),
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      t(
                        en: 'Eko was waiting for you',
                        tr: 'Eko seni bekliyordu',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _streakChip(theme, progress.streak),
            ],
          ),
          const SizedBox(height: 20),

          if (!progress.isCalibrated) ...[
            _calibrationBanner(context, theme),
            const SizedBox(height: 16),
          ],

          _continueHero(context, theme, next),
          const SizedBox(height: 16),

          _planCard(context, theme, progress, next, due),
          const SizedBox(height: 16),

          _statRow(theme, progress, rank),
        ],
      ),
    );
  }

  Widget _continueHero(
    BuildContext context,
    ThemeData theme,
    ({Track track, TrackItem item})? next,
  ) {
    const onHero = Colors.white;
    final onSoft = Colors.white.withValues(alpha: 0.88);

    if (next == null) {
      // Her şey tamam — kutlama hero'su.
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.teal, AppColors.grape],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EkoMascot(size: 54, celebrate: true),
            const SizedBox(height: 12),
            Text(
              t(
                en: 'You finished every lesson! 🎉',
                tr: 'Tüm dersleri bitirdin! 🎉',
              ),
              style: theme.textTheme.headlineSmall?.copyWith(color: onHero),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                en: 'Keep it fresh with reviews — keep your ear sharp.',
                tr: 'Tekrarlarla taze tut, kulağını keskin bırakma.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: onSoft),
            ),
          ],
        ),
      );
    }

    final track = next.track;
    final item = next.item;
    final grad = [track.color, Color.lerp(track.color, AppColors.coral, 0.5)!];

    // Gölge DIŞ katmanda (kırpılmaz); gradyan + ripple İÇ Material'da yuvarlak
    // kırpılır. Tek yuvarlatılmış yüzey → alt köşelerde eski Material+Ink çift
    // yüzeyinin yol açtığı beyaz "dik köşe" taşması oluşmaz.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: track.color.withValues(alpha: 0.4),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => item.open())),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            en: 'PICK UP WHERE YOU LEFT',
                            tr: 'KALDIĞIN YERDEN',
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: onSoft,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: onHero,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSoft,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            t(en: 'Continue →', tr: 'Devam Et →'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: track.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(track.icon, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    ThemeData theme,
    PlayerProgress progress,
    ({Track track, TrackItem item})? next,
    List<String> due,
  ) {
    final pct = (progress.dailyXp / kDailyXpGoal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(en: "TODAY'S PLAN", tr: 'BUGÜNÜN PLANI'),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (next != null)
            _planRow(
              context,
              theme,
              icon: Icons.play_circle_fill_rounded,
              color: next.track.color,
              title: t(
                en: 'New lesson: ${next.item.title}',
                tr: 'Yeni ders: ${next.item.title}',
              ),
              subtitle: next.track.name,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => next.item.open())),
            ),
          if (due.isNotEmpty)
            _planRow(
              context,
              theme,
              icon: Icons.replay_circle_filled_rounded,
              color: AppColors.teal,
              title: t(
                en: '${due.length} reviews ready',
                tr: '${due.length} tekrar hazır',
              ),
              subtitle: t(
                en: 'Refresh the skills due right now',
                tr: 'Tam zamanı gelen becerileri tazele',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewSessionPage(skillIds: due),
                ),
              ),
            ),
          if (next == null && due.isEmpty)
            _planRow(
              context,
              theme,
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              title: t(en: 'Done for today!', tr: 'Bugünlük tamam!'),
              subtitle: t(
                en: 'Keep exploring in Practice if you like',
                tr: 'Dilersen Pratik’ten keşfe devam et',
              ),
            ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              color: AppColors.grape,
              backgroundColor: AppColors.wash,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t(en: 'Daily goal', tr: 'Günlük hedef'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${progress.dailyXp} / $kDailyXpGoal XP',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planRow(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(ThemeData theme, PlayerProgress progress, Rank rank) {
    Widget cell(String n, String l, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n, style: theme.textTheme.titleLarge?.copyWith(color: c)),
            const SizedBox(height: 2),
            Text(
              l,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        cell('${progress.xp}', 'XP', AppColors.grape),
        const SizedBox(width: 10),
        cell(rank.name, t(en: 'Rank', tr: 'Rütbe'), AppColors.coral),
        const SizedBox(width: 10),
        cell(
          '${progress.streak}',
          t(en: 'Day streak', tr: 'Gün seri'),
          AppColors.amber,
        ),
      ],
    );
  }

  Widget _streakChip(ThemeData theme, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF6E2AE)),
      ),
      child: Text(
        '🔥 $streak',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFC9871A),
        ),
      ),
    );
  }

  Widget _calibrationBanner(BuildContext context, ThemeData theme) {
    return Material(
      color: AppColors.grape.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CalibrationPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.grape,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        en: "Let's meet your voice first",
                        tr: 'Önce sesini tanıyalım',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(
                        en: 'A ~1 min check so lessons fit your comfy octave.',
                        tr: 'Dersleri rahat oktavında hazırlamak için ~1 dk ölçüm.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
