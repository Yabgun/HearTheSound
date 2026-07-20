import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_icons.dart';
import '../../ui/app_theme.dart';
import '../calibration/calibration_page.dart';
import '../home/curriculum.dart';
import '../mascot/eko_mascot.dart';
import '../placement/placement_test_page.dart';

// -----------------------------------------------------------------------------
// ONBOARDING — ilk açılış akışı
//
// Sıra: Hoş geldin → Ses aralığı kalibrasyonu → (opsiyonel) yerleştirme testi.
// Bitince 'onboarded' bayrağı set edilir; kök geçiş (main) otomatik ana ekrana
// döner. Her adım atlanabilir (kalibrasyonun kendi "atla"sı, yerleştirmede
// "sıfırdan başla").
// -----------------------------------------------------------------------------

enum _Step { welcome, levelChooser }

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  _Step _step = _Step.welcome;

  Future<void> _goCalibration() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CalibrationPage()));
    if (mounted) setState(() => _step = _Step.levelChooser);
  }

  Future<void> _goPlacement() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PlacementTestPage()),
    );
    if (mounted && completed != null) _finish();
  }

  /// Onboarding'i tamamla — kök geçiş bunu görünce ana ekrana geçer.
  void _finish() => ref.read(settingsProvider.notifier).setOnboarded(true);

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.welcome => _buildWelcome(context),
      _Step.levelChooser => _buildLevelChooser(context),
    };
  }

  /// Dil seçimi — ilk açılışta (kalibrasyondan ÖNCE) EN↔TR. İngilizce bilmeyen
  /// kullanıcı Türkçe devam edebilsin; setLocale tüm ağacı yeni dille çizer.
  Widget _langToggle() {
    final code = ref.watch(settingsProvider).localeCode;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'en', label: Text('EN')),
        ButtonSegment(value: 'tr', label: Text('TR')),
      ],
      selected: {code},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(settingsProvider.notifier).setLocale(s.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: _langToggle()),
              const Spacer(flex: 2),
              const EkoMascot(size: 118),
              const SizedBox(height: 24),
              Text(
                'HearTheSound',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  en: "Hear it · get it · sing it back.\nLet's grow your musical ear step by step.",
                  tr: 'Duy · anla · sesinle söyle.\nMüzik kulağını adım adım geliştirelim.',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              // Çekirdek döngüyü görselleştir: Duy → Anla → Söyle.
              _loopRow(theme),
              const Spacer(),
              Text(
                t(
                  en: "Let's meet your voice first so I can tailor the lessons to you.",
                  tr: 'Önce sesini tanıyalım ki dersleri tam sana göre hazırlayayım.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goCalibration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(t(en: "Let's start", tr: 'Başlayalım')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _step = _Step.levelChooser),
                child: Text(
                  t(
                    en: "I'll calibrate later",
                    tr: 'Kalibrasyonu sonra yaparım',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Çekirdek döngü rozeti: Duy → Anla → Söyle (onboarding karşılamasında).
  Widget _loopRow(ThemeData theme) {
    Widget chip(IconData icon, String label, Color color) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    Widget arrow() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(Icons.headphones_rounded, t(en: 'Hear', tr: 'Duy'), AppColors.coral),
        arrow(),
        chip(
          Icons.lightbulb_rounded,
          t(en: 'Get it', tr: 'Anla'),
          AppColors.grape,
        ),
        arrow(),
        chip(Icons.mic_rounded, t(en: 'Sing', tr: 'Söyle'), AppColors.teal),
      ],
    );
  }

  /// Seçilen seviye: müfredatın ilk [precompleteTracks] track'ini "tamam"
  /// işaretle (o track'ler açık başlar → zincir bir sonrakini açar), sonra bitir.
  void _chooseLevel(int precompleteTracks) {
    ref
        .read(progressProvider.notifier)
        .applyPlacement(lessonIdsInFirstTracks(precompleteTracks));
    _finish();
  }

  Widget _buildLevelChooser(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Where should we start?', tr: 'Nereden başlayalım?')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              t(
                en:
                    "Pick your level and I'll open the right lessons. You can "
                    'always replay earlier ones for a crown.',
                tr:
                    'Seviyeni seç, doğru dersleri açayım. Öncekileri taç için '
                    'istediğin zaman tekrar oynayabilirsin.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // Seviye → kaç track "tamam" sayılır (bkz. lessonIdsInFirstTracks):
            // 0 Notalar · 1 Aralıklar · 3 Tonalite · 4 Akor İşlevi.
            _levelCard(
              theme,
              icon: AppIcons.levelBeginner,
              title: t(en: "I'm starting from scratch", tr: 'Yeni başlıyorum'),
              subtitle: t(en: 'Begin with Notes', tr: 'Notalardan başla'),
              color: AppColors.catNotes,
              onTap: () => _chooseLevel(0),
            ),
            _levelCard(
              theme,
              icon: AppIcons.levelNotes,
              title: t(en: 'I can name notes', tr: 'Notaları tanıyorum'),
              subtitle: t(en: 'Start at Intervals', tr: 'Aralıklardan başla'),
              color: AppColors.catIntervals,
              onTap: () => _chooseLevel(1),
            ),
            _levelCard(
              theme,
              icon: AppIcons.levelChords,
              title: t(
                en: 'I know intervals & chords',
                tr: 'Aralık ve akorları biliyorum',
              ),
              subtitle: t(
                en: 'Start at Scales & Tonality',
                tr: 'Diziler & Tonalite\'den başla',
              ),
              color: AppColors.catChords,
              onTap: () => _chooseLevel(3),
            ),
            _levelCard(
              theme,
              icon: AppIcons.levelTheory,
              title: t(
                en: "I'm comfortable with theory",
                tr: 'Teoriye hâkimim',
              ),
              subtitle: t(
                en: 'Start at Chord Function',
                tr: 'Akor İşlevi\'nden başla',
              ),
              color: AppColors.catFunction,
              onTap: () => _chooseLevel(4),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goPlacement,
              child: Text(
                t(
                  en: 'Not sure? Take a quick test',
                  tr: 'Emin değil misin? Kısa test yap',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 26, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
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
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
