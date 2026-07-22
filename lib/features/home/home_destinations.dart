import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chord.dart';
import '../../core/confusion.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/rank.dart';
import '../../core/spaced_repetition.dart';
import '../function/function_lesson.dart';
import '../../state/progress_controller.dart';
import '../calibration/calibration_page.dart';
import '../explorer/range_playground_page.dart';
import '../mascot/player_eko.dart';
import '../profile/profile_identity.dart';
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
      appBar: AppBar(
        title: Text(t(en: 'Practice Zone', tr: 'Pratik Alanı')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              t(
                en: 'What are we training your ear on today?',
                tr: 'Bugün kulağına ne çalıştırıyoruz?',
              ),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                en: 'Short reviews and free exploration keep your learning path alive.',
                tr: 'Kısa tekrarlar ve özgür keşif, öğrenme yolunu canlı tutar.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _PracticeCard(
              icon: Icons.replay_rounded,
              color: AppColors.teal,
              title: due.isEmpty
                  ? t(en: 'Reviews up to date ✓', tr: 'Tekrarların güncel ✓')
                  : t(
                      en: '${due.length} reviews waiting for you',
                      tr: '${due.length} tekrar seni bekliyor',
                    ),
              subtitle: due.isEmpty
                  ? t(
                      en: 'Nothing to refresh right now — feel free to start a new lesson.',
                      tr: 'Şimdilik tazelenecek bir şey yok — yeni bir derse geçebilirsin.',
                    )
                  : t(
                      en: 'Quickly refresh the skills SM-2 says are due.',
                      tr: 'SM-2 ile tam zamanı gelen becerileri kısaca tazele.',
                    ),
              buttonLabel: t(en: 'Start review', tr: 'Tekrara başla'),
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
              title: t(
                en: 'Vocal Range Playground',
                tr: 'Ses Aralığı Oyun Alanı',
              ),
              subtitle: t(
                en: 'No scores, no pressure. Listen to your voice and find your comfort zone.',
                tr: 'Puan yok, baskı yok. Sesini dinle ve rahat alanını keşfet.',
              ),
              buttonLabel: t(en: 'Explore', tr: 'Keşfet'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RangePlaygroundPage(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _PracticeCard(
              icon: Icons.tune_rounded,
              color: AppColors.coral,
              title: progress.isCalibrated
                  ? t(
                      en: 'Refresh your vocal range',
                      tr: 'Ses aralığını yenile',
                    )
                  : t(
                      en: 'Calibrate your vocal range',
                      tr: 'Ses aralığını kalibre et',
                    ),
              subtitle: t(
                en: 'Singing exercises adapt to your comfortable octave.',
                tr: 'Söyleme egzersizleri senin rahat oktavına uyum sağlar.',
              ),
              buttonLabel: t(en: 'Open', tr: 'Aç'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalibrationPage(),
                ),
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
        title: Text(t(en: 'Your Profile', tr: 'Profilin')),
        actions: [
          IconButton(
            tooltip: t(en: 'Settings', tr: 'Ayarlar'),
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
            // Kimlik: avatar + ad + hesap + üyelik tarihi (§19).
            const ProfileIdentityCard(),
            const SizedBox(height: 20),
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
                        Text(
                          t(en: 'YOUR RANK', tr: 'RÜTBEN'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rank.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                            en: '${progress.xp} total XP',
                            tr: '${progress.xp} toplam XP',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PlayerEko(size: 64, celebrate: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(
                  label: t(en: 'Streak', tr: 'Seri'),
                  value: t(
                    en: '${progress.streak} days',
                    tr: '${progress.streak} gün',
                  ),
                  icon: Icons.local_fire_department_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: t(en: 'Lessons', tr: 'Ders'),
                  value: '${progress.completedLessons.length}',
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
            // Karıştırma içgörüsü: hangi çiftler ekstra çalışma istiyor?
            if (progress.confusionCounts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                t(
                  en: 'Your most mixed-up pairs',
                  tr: 'En çok karıştırdıkların',
                ),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                t(
                  en: 'Give these pairs a deliberate ear in your reviews.',
                  tr: 'Tekrarlarda bu çiftlere bilinçli kulak ver.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in topConfusions(
                progress.confusionCounts,
                limit: 3,
              ))
                _ConfusionRow(entry: entry),
            ],
            const SizedBox(height: 24),
            Text(
              t(en: 'Your Journey', tr: 'Yolculuğun'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                en: 'HearTheSound is here to help you become a musician who names what they hear and sings it back.',
                tr: 'HearTheSound, duyduğunu isimlendiren ve sesiyle yeniden üreten bir müzisyen olman için burada.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Veri taşınabilirliği (Play zorunluluğu) — §19.
            const ExportDataTile(),
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
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ],
      ),
    );
  }
}

/// Tek bir karıştırma çifti satırı: "duyulan ↔ seçilen · tip · N kez".
/// Ham anahtar belirteçlerini okunur Türkçe etikete çevirir; tanınmayan
/// belirteçlerde ham hali gösterir (veri asla satırı kırmasın).
class _ConfusionRow extends StatelessWidget {
  const _ConfusionRow({required this.entry});

  final ConfusionEntry entry;

  /// Belirteç → görünen ad. (Anahtarlar dil-bağımsız; görünüm burada çözülür.)
  String _pretty(String type, String token) {
    switch (type) {
      case 'quality':
        try {
          return ChordQuality.values.byName(token).label;
        } catch (_) {
          return token;
        }
      case 'chord':
        // 'C.major' biçimi → 'C Majör' benzeri.
        final parts = token.split('.');
        if (parts.length == 2) {
          try {
            return '${parts[0]} ${ChordQuality.values.byName(parts[1]).label}';
          } catch (_) {
            return token;
          }
        }
        return token;
      case 'interval':
        final semis = int.tryParse(token);
        return semis == null ? token : (kIntervals[semis]?.name ?? token);
      case 'degree':
        return t(en: 'Degree $token', tr: '$token. derece');
      case 'inv':
        return token == '0'
            ? t(en: 'Root position', tr: 'Kapalı')
            : t(en: 'inversion $token', tr: '$token. çevrim');
      case 'function':
        try {
          return HarmonicFunction.values.byName(token).label;
        } catch (_) {
          return token;
        }
      default:
        return token; // note (C, F#...) ve prog (I – IV – V – I) zaten okunur
    }
  }

  String _typeLabel(String type) => switch (type) {
    'note' => t(en: 'note', tr: 'nota'),
    'chord' => t(en: 'chord', tr: 'akor'),
    'quality' => t(en: 'chord color', tr: 'akor rengi'),
    'inv' => t(en: 'inversion', tr: 'çevrim'),
    'interval' => t(en: 'interval', tr: 'aralık'),
    'degree' => t(en: 'degree', tr: 'derece'),
    'function' => t(en: 'function', tr: 'işlev'),
    'prog' => t(en: 'progression', tr: 'ilerleme'),
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_pretty(entry.type, entry.expected)} ↔ '
                  '${_pretty(entry.type, entry.chosen)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _typeLabel(entry.type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.count}×',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.amber,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
