import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../mascot/eko_mascot.dart';
import 'lesson.dart';

// -----------------------------------------------------------------------------
// TAMAMLAMA EKRANI — ders sonu kutlaması
//
// Somut ödül + kapanış: Eko zıplayarak girer, konfeti düşer, doğruluk/XP/seri
// gösterilir. "İlerledim" hissi tutundurmanın temel dopaminidir.
// -----------------------------------------------------------------------------

class LessonCompletePage extends StatefulWidget {
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
  State<LessonCompletePage> createState() => _LessonCompletePageState();
}

class _LessonCompletePageState extends State<LessonCompletePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final List<_Particle> _particles = _makeParticles();

  /// Ders geçildi mi? (kutlama vs. "tekrar dene" ayrımı — akış sayfalarıyla
  /// AYNI baraj `kPassAccuracy`.)
  bool get _passed => widget.result.accuracy >= kPassAccuracy;

  @override
  void initState() {
    super.initState();
    if (_passed) {
      _confetti.forward(); // kutlama YALNIZCA geçilince
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact(); // geçemedi: nazik dokunuş, kutlama yok
    }
  }

  List<_Particle> _makeParticles() {
    final rng = Random(7);
    const colors = [
      AppColors.grape,
      AppColors.coral,
      AppColors.teal,
      AppColors.amber,
      AppColors.pink,
      AppColors.sky,
    ];
    return List.generate(46, (i) {
      return _Particle(
        x: rng.nextDouble(),
        color: colors[i % colors.length],
        size: 6 + rng.nextDouble() * 7,
        delay: rng.nextDouble() * 0.25,
        sway: 0.5 + rng.nextDouble(),
        rotSpeed: (rng.nextDouble() - 0.5) * 6,
        fall: 0.85 + rng.nextDouble() * 0.4,
      );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (widget.result.accuracy * 100).round();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  // Eko zıplayarak girer
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            // Geçince canlı mor→mercan; geçemeyince yumuşak amber
                            // (teşvik edici, kutlama değil).
                            colors: _passed
                                ? const [AppColors.grape, AppColors.coral]
                                : [
                                    AppColors.amber.withValues(alpha: 0.85),
                                    AppColors.coral.withValues(alpha: 0.6),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_passed ? AppColors.grape : AppColors.amber)
                                      .withValues(alpha: 0.3),
                              blurRadius: 28,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: EkoMascot(size: 96, celebrate: _passed),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EntranceFade(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _passed
                              ? t(
                                  en: 'Lesson Complete!',
                                  tr: 'Ders Tamamlandı!',
                                )
                              : t(en: 'Almost there!', tr: 'Az kaldı!'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _passed
                              ? t(en: '$pct% accuracy', tr: '%$pct doğruluk')
                              : t(
                                  en:
                                      '$pct% — you need '
                                      '${(kPassAccuracy * 100).round()}% to pass. '
                                      'Give it another go!',
                                  tr:
                                      '%$pct — geçmek için '
                                      '%${(kPassAccuracy * 100).round()} '
                                      'gerekiyor. Bir daha dene!',
                                ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _statCard(
                          theme,
                          Icons.check_circle_rounded,
                          t(en: 'Correct', tr: 'Doğru'),
                          '${widget.result.correct} / ${widget.result.total}',
                        ),
                        const SizedBox(height: 10),
                        _statCard(
                          theme,
                          Icons.bolt_rounded,
                          t(en: 'XP earned', tr: 'Kazanılan XP'),
                          '+${widget.xpEarned}',
                        ),
                        const SizedBox(height: 10),
                        _statCard(
                          theme,
                          Icons.local_fire_department_rounded,
                          t(en: 'Daily streak', tr: 'Günlük seri'),
                          '${widget.streak}',
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Geçince birincil = Devam; geçemeyince birincil = Tekrar dene
                  // (teşvik edici — kullanıcı geçtiğini sanmasın).
                  FilledButton(
                    onPressed: _passed ? widget.onDone : widget.onReplay,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _passed
                          ? t(en: 'Continue', tr: 'Devam')
                          : t(en: 'Try again', tr: 'Tekrar dene'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _passed ? widget.onReplay : widget.onDone,
                    child: Text(
                      _passed
                          ? t(en: 'Play Again', tr: 'Tekrar Oyna')
                          : t(en: 'Back', tr: 'Geri'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(_particles, _confetti.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// İçeriği hafifçe yukarı kaydırarak beliren giriş animasyonu.
class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.color,
    required this.size,
    required this.delay,
    required this.sway,
    required this.rotSpeed,
    required this.fall,
  });
  final double x;
  final Color color;
  final double size;
  final double delay;
  final double sway;
  final double rotSpeed;
  final double fall;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress);
  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -0.05 * size.height + t * p.fall * size.height * 1.15;
      final x = (p.x + sin(t * 6.28318 * p.sway) * 0.06) * size.width;
      final opacity = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.rotSpeed * 6.28318);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
