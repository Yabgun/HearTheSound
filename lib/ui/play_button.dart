import 'package:flutter/material.dart';

import '../core/content_locale.dart';

// -----------------------------------------------------------------------------
// PLAY BUTTON — büyük dairesel "çal" düğmesi (tüm egzersiz ekranlarının ortak sesi)
//
// Nota/akor/aralık/işlev/ilerleme/tonalite tanıma ve kur ekranlarında birebir
// aynı düğme tekrar ediyordu; tek kaynağa indirildi. Renk temadan gelir
// (colorScheme.primary), böylece tema değişince her ekran birlikte döner.
//
// [playing] verilirse (çalan ekranlar) ikon eşitleyici dalgasına döner ve çalma
// bitene kadar dokunma kapanır; verilmezse sade "çal" davranışı.
// -----------------------------------------------------------------------------

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.onTap,
    this.playing = false,
    this.size = 128,
    this.iconSize = 54,
  });

  final VoidCallback onTap;

  /// Şu an bir ses çalıyor mu? true iken ikon dalgaya döner, dokunma kapanır.
  final bool playing;

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Erişilebilirlik: ekran okuyucular için buton kimliği + durum etiketi.
    return Semantics(
      button: true,
      enabled: !playing,
      label: playing
          ? t(en: 'Playing', tr: 'Çalıyor')
          : t(en: 'Play the sound', tr: 'Sesi çal'),
      child: GestureDetector(
        onTap: playing ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
            size: iconSize,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
