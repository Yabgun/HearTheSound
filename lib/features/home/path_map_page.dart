import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../core/player_progress.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_icons.dart';
import '../../ui/app_theme.dart';
import '../concept/concept_sheet.dart';
import 'curriculum.dart';

// -----------------------------------------------------------------------------
// YOL HARİTASI — tüm müfredat tek bakışta.
//
// Düz uzun liste değil; her track renk kodlu bir "dünya", dersler düğüm. Bitmiş
// dersler de görünür (kaybolmaz) → "içerik kayboldu" hissi olmaz. "Buradasın"
// hep bellidir.
// -----------------------------------------------------------------------------

class PathMapPage extends ConsumerWidget {
  const PathMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final next = nextLesson(progress);
    final prog = curriculumProgress(progress);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            t(en: 'Path', tr: 'Yol Haritası'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            t(
              en: '${prog.done} / ${prog.total} lessons done',
              tr: '${prog.done} / ${prog.total} ders tamamlandı',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          for (final track in curriculum)
            _trackSection(context, theme, track, progress, next?.item.id),
        ],
      ),
    );
  }

  Widget _trackSection(
    BuildContext context,
    ThemeData theme,
    Track track,
    PlayerProgress progress,
    String? currentId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: track.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              track.name.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            // Bağlantı çizgisi
            Positioned(
              left: 26,
              top: 6,
              bottom: 14,
              child: Container(width: 3, color: AppColors.wash),
            ),
            Column(
              children: [
                for (var i = 0; i < track.items.length; i++)
                  _node(
                    context,
                    theme,
                    track,
                    i,
                    progress,
                    isCurrent: track.items[i].id == currentId,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _node(
    BuildContext context,
    ThemeData theme,
    Track track,
    int i,
    PlayerProgress progress, {
    required bool isCurrent,
  }) {
    final item = track.items[i];
    final completed = progress.isLessonCompleted(item.id);
    final unlocked = itemUnlocked(track, i, progress);

    // Kabarcık
    Widget bubble;
    if (completed) {
      bubble = _bub(
        AppColors.success.withValues(alpha: 0.16),
        AppColors.success,
        const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
      );
    } else if (isCurrent) {
      bubble = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [track.color, Color.lerp(track.color, AppColors.pink, .4)!],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: track.color.withValues(alpha: 0.35),
              blurRadius: 0,
              spreadRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${i + 1}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (unlocked) {
      bubble = _bub(
        theme.colorScheme.surface,
        track.color,
        Text(
          '${i + 1}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: track.color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      bubble = _bub(
        theme.colorScheme.surface,
        theme.colorScheme.outlineVariant,
        Icon(Icons.lock_rounded, color: theme.colorScheme.outline, size: 18),
      );
    }

    // Ustalık/taç seviyesi: tamamlanan ders tekrar oynanınca zorlaşarak yükselir.
    final level = progress.skillLevelOf(item.id);
    final subtitle = completed
        ? (level >= kMaxSkillLevel
              ? t(en: 'mastered · replay', tr: 'ustalaşıldı · tekrar oyna')
              : t(
                  en: 'done · tap to level up',
                  tr: 'tamam · dokun, seviye atla',
                ))
        : isCurrent
        ? t(en: 'in progress', tr: 'devam ediyor')
        : unlocked
        ? t(en: 'tap to start', tr: 'başlamak için dokun')
        : t(en: 'locked', tr: 'kilitli');

    return InkWell(
      onTap: unlocked
          ? () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => item.open()))
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            bubble,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      color: unlocked
                          ? (isCurrent ? track.color : null)
                          : theme.colorScheme.onSurfaceVariant,
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
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: track.color,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  t(en: "YOU'RE HERE", tr: 'BURADASIN'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else if (completed && level >= 1)
              // Taç rozeti: kaç kez zorlaşarak ustalaşıldı (0..kMaxSkillLevel).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.crown,
                      size: 14,
                      color: AppColors.amberDeep,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$level',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.amberDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else if (unlocked && item.concept != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: t(
                  en: "What's this lesson about?",
                  tr: 'Bu ders ne anlatıyor?',
                ),
                onPressed: () => showConceptSheet(context, item.concept!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bub(Color bg, Color border, Widget child) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
