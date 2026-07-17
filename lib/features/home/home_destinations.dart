import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rank.dart';
import '../../core/spaced_repetition.dart';
import '../../state/progress_controller.dart';
import '../calibration/calibration_page.dart';
import '../explorer/range_playground_page.dart';
import '../mascot/eko_mascot.dart';
import '../review/review_session_page.dart';
import '../settings/settings_page.dart';
import '../../ui/app_theme.dart';

/// Ana yolun yanındaki iki sabit varış: günlük pratik ve oyuncu profili.
class PracticeHubPage extends ConsumerWidget {
  const PracticeHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final due = progress.dueReviewSkills(dayKeyFor(DateTime.now()));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pratik Alanı')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Bugün kulağına ne çalıştırıyoruz?',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Kısa tekrarlar ve özgür keşif, öğrenme yolunu canlı tutar.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _PracticeCard(
              icon: Icons.replay_rounded,
              color: AppColors.teal,
              title: due.isEmpty ? 'Tekrarların güncel ✓' : '${due.length} tekrar seni bekliyor',
              subtitle: due.isEmpty
                  ? 'Şimdilik tazelenecek bir şey yok — yeni bir derse geçebilirsin.'
                  : 'SM-2 ile tam zamanı gelen becerileri kısaca tazele.',
              buttonLabel: 'Tekrara başla',
              onPressed: due.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewSessionPage(skillIds: due),
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            _PracticeCard(
              icon: Icons.piano_rounded,
              color: AppColors.grape,
              title: 'Ses Aralığı Oyun Alanı',
              subtitle: 'Puan yok, baskı yok. Sesini dinle ve rahat alanını keşfet.',
              buttonLabel: 'Keşfet',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RangePlaygroundPage()),
              ),
            ),
            const SizedBox(height: 14),
            _PracticeCard(
              icon: Icons.tune_rounded,
              color: AppColors.coral,
              title: progress.isCalibrated ? 'Ses aralığını yenile' : 'Ses aralığını kalibre et',
              subtitle: 'Söyleme egzersizleri senin rahat oktavına uyum sağlar.',
              buttonLabel: 'Aç',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CalibrationPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileHubPage extends ConsumerWidget {
  const ProfileHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final rank = rankForXp(progress.xp);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilin'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.grape, AppColors.coral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.grape.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RÜTBEN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 6),
                        Text(rank.name,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${progress.xp} toplam XP',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                            )),
                      ],
                    ),
                  ),
                  const EkoMascot(size: 64, celebrate: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(label: 'Seri', value: '${progress.streak} gün', icon: Icons.local_fire_department_rounded),
                const SizedBox(width: 12),
                _StatCard(label: 'Ders', value: '${progress.completedLessons.length}', icon: Icons.check_circle_rounded),
              ],
            ),
            const SizedBox(height: 24),
            Text('Yolculuğun', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'HearTheSound, duyduğunu isimlendiren ve sesiyle yeniden üreten bir müzisyen olman için burada.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          if (onPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.coral),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.titleMedium),
            Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}
