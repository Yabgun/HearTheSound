import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../state/settings_controller.dart';
import '../calibration/calibration_page.dart';
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

enum _Step { welcome, placementOffer }

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
    if (mounted) setState(() => _step = _Step.placementOffer);
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
      _Step.placementOffer => _buildPlacementOffer(context),
    };
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
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
                onPressed: () => setState(() => _step = _Step.placementOffer),
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

  Widget _buildPlacementOffer(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.school_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                t(en: 'Where should we start?', tr: 'Nereden başlayalım?'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  en:
                      'If you already know some music or notes, a short test '
                      'can start you at the right lesson. Totally new? No '
                      "worries — we'll build up nicely from scratch.",
                  tr:
                      'Daha önce müzik/nota bilgin varsa, kısa bir testle seni doğru '
                      'dersten başlatabilirim. Yepyeniysen dert değil — sıfırdan '
                      'güzelce ilerleriz.',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goPlacement,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    t(en: 'Take the quick test', tr: 'Kısa test yap'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _finish,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    t(en: 'Start from scratch', tr: 'Sıfırdan başla'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
