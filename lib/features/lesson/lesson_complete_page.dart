import 'package:flutter/material.dart';

import 'lesson.dart';

// -----------------------------------------------------------------------------
// TAMAMLAMA EKRANI — ders sonu kutlaması
//
// Her seansın somut bir ödülü/kapanışı olsun diye: doğruluk, kazanılan XP ve
// günlük seri gösterilir. Bu "ilerledim" hissi tutundurmanın temel dopaminidir.
// -----------------------------------------------------------------------------

class LessonCompletePage extends StatelessWidget {
  const LessonCompletePage({
    super.key,
    required this.result,
    required this.xpEarned,
    required this.streak,
    required this.onDone,
    required this.onReplay,
  });

  final LessonResult result;
  final int xpEarned;
  final int streak;
  final VoidCallback onDone;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (result.accuracy * 100).round();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.emoji_events_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Ders Tamamlandı!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '%$pct doğruluk',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _statCard(theme, 'Doğru', '${result.correct} / ${result.total}'),
              const SizedBox(height: 10),
              _statCard(theme, 'Kazanılan XP', '+$xpEarned'),
              const SizedBox(height: 10),
              _statCard(theme, 'Günlük seri', '🔥 $streak'),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Devam'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onReplay,
                child: const Text('Tekrar Oyna'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
