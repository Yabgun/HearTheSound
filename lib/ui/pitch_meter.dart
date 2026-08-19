import 'package:flutter/material.dart';

import '../core/content_locale.dart';
import '../core/note.dart';
import 'app_theme.dart';

// -----------------------------------------------------------------------------
// PITCH METER — canlı perde göstergesi (söyleme ekranlarının ortak "akort" ibresi)
//
// Hedef nota ortada; ibre, ölçülen sesin hedefe göre sapmasını CENT cinsinden
// gösterir (±150 cent görünür pencere; ±50 cent "tam" bölgesi). Böylece "tut,
// bekle" yerine kullanıcı sesinin TAM OLARAK nerede olduğunu ve hangi yöne
// kayması gerektiğini anlık görür — söyleme döngüsünü rehberli bir enstrümana
// çevirir.
//
// Saf görsel bileşendir: mikrofon/akış bilmez, sadece (hedef, okuma) alır.
// -----------------------------------------------------------------------------

class PitchMeter extends StatelessWidget {
  const PitchMeter({
    super.key,
    required this.target,
    required this.reading,
    required this.active,
  });

  /// Hedef nota (tam oktavıyla).
  final Note target;

  /// Son mikrofon okuması; null = henüz ses yok.
  final NoteReading? reading;

  /// Mikrofon şu an dinliyor mu? (kapalıyken ibre soluk durur)
  final bool active;

  /// Görünür pencere: hedeften bu kadar cent uzaklık ibreyi kenara dayar.
  static const double _windowCents = 150;

  /// "Tam" sayılan bölge (söyleme eşleşme toleransıyla uyumlu: ±50 cent).
  static const double _okCents = 50;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Toplam sapma: nota farkı (100 cent/yarım ses) + nota içi cent sapması.
    double? offset;
    if (reading != null) {
      offset = (reading!.note.midi - target.midi) * 100.0 + reading!.cents;
    }
    final clamped = offset?.clamp(-_windowCents, _windowCents);
    final inTune = offset != null && offset.abs() <= _okCents;

    // Yön ipucu: pencere dışına taşan sapmada ok göster (▲ tiz / ▼ pes söyle).
    String? hint;
    if (active && offset != null && offset.abs() > _windowCents) {
      hint = offset < 0
          ? t(en: '▲ higher', tr: '▲ daha tiz')
          : t(en: '▼ lower', tr: '▼ daha pes');
    }

    final needleColor = !active
        ? theme.colorScheme.outline
        : inTune
        ? context.colors.success
        : AppColors.amber;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              // İbre konumu: -pencere → sol kenar, 0 → orta, +pencere → sağ kenar.
              final x = clamped == null
                  ? w / 2
                  : w / 2 + (clamped / _windowCents) * (w / 2 - 8);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ray
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.colors.wash,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  // "Tam" bölgesi (±50 cent)
                  Positioned(
                    left: w / 2 - (_okCents / _windowCents) * (w / 2 - 8),
                    right: w / 2 - (_okCents / _windowCents) * (w / 2 - 8),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: context.colors.success.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  // Hedef çizgisi (orta)
                  Positioned(
                    left: w / 2 - 1.25,
                    child: Container(
                      width: 2.5,
                      height: 26,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // İbre
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    left: x - 9,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: (active && reading != null) ? 1 : 0.35,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: needleColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: needleColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        // Alt satır: pes ← hedef → tiz + anlık sapma değeri
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t(en: '♭ low', tr: '♭ pes'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              hint ??
                  (offset == null
                      ? target.label
                      : '${offset >= 0 ? '+' : ''}${offset.round()} cent'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: inTune
                    ? context.colors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              t(en: 'high ♯', tr: 'tiz ♯'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
