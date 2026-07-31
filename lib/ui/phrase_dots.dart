import 'package:flutter/material.dart';

import 'app_theme.dart';

// -----------------------------------------------------------------------------
// CÜMLE NOKTALARI — çalan müzikal cümlenin görsel karşılığı
//
// NEDEN: "Şu an neredeyiz?" sorusu hiç metin okumadan cevaplanmalı. Her olay bir
// nokta; çalan nokta büyür. Kullanıcı sesi gözüyle de takip eder.
//
// SON NOKTA ayrıca vurgulanır (çerçeve/renk) çünkü öğretilen şeyin tamamı orada:
// cümlenin nasıl BİTTİĞİ. Böylece "fark hep sonda" mesajı görselleşir.
// -----------------------------------------------------------------------------

class PhraseDots extends StatelessWidget {
  const PhraseDots({
    super.key,
    required this.count,
    this.activeIndex,
    this.endAccent,
    this.semanticsLabel,
  });

  /// Cümledeki olay sayısı.
  final int count;

  /// Şu an çalan olayın indisi; null = çalmıyor.
  final int? activeIndex;

  /// Son noktanın rengi — bitişin karakterini gösterir (evde/askıda).
  /// null verilirse son nokta yalnızca çerçeveyle ayrılır, renk ipucu vermez
  /// (soru ekranlarında cevabı ele vermemesi için).
  final Color? endAccent;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) _dot(theme, i),
        ],
      ),
    );
  }

  Widget _dot(ThemeData theme, int index) {
    final isLast = index == count - 1;
    final isActive = activeIndex == index;
    final accent = endAccent ?? theme.colorScheme.onSurfaceVariant;

    final base = isLast ? accent : theme.colorScheme.outline;
    final size = isActive ? 18.0 : (isLast ? 14.0 : 10.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? base : base.withValues(alpha: isLast ? 0.45 : 0.28),
        border: isLast
            ? Border.all(color: base.withValues(alpha: 0.9), width: 2)
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: base.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Bitiş karakterine göre renk — tek kaynak, tüm cümle ekranları paylaşır.
/// Evde biten yeşil (varış), askıda kalan amber (bekleyiş). Amber bilinçli:
/// askıda kalmak YANLIŞ değil, tamamlanmamıştır — kırmızı yanlış anlatırdı.
Color phraseEndColor({required bool endsAtHome}) =>
    endsAtHome ? AppColors.success : AppColors.amber;
