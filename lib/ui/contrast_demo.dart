import 'package:flutter/material.dart';

import '../audio/phrase_player.dart';
import '../core/content_locale.dart';
import '../core/musical_phrase.dart';
import 'phrase_dots.dart';

// -----------------------------------------------------------------------------
// DUY VE FARK ET — zıtlık ikilisi
//
// NEDEN VAR: Bir müzikal kavramı paragrafla anlatmak işe yaramıyor (denendi).
// Ama AYNI cümlenin tek farkla iki halini arka arkaya duymak kavramı saniyeler
// içinde geçiriyor: fark kulakta kendini gösterir, kelimeye gerek kalmaz.
//
// KURAL: iki seçenek arasındaki fark TEK olmalı (bkz. musical_phrase.dart).
// İki şey birden değişirse kullanıcı hangisini dinleyeceğini bilemez.
// -----------------------------------------------------------------------------

class ContrastOption {
  const ContrastOption({
    required this.title,
    required this.caption,
    required this.phrase,
    required this.endsAtHome,
  });

  final String title;

  /// Kullanıcının NEYE dikkat edeceğini söyleyen tek satır.
  final String caption;

  final MusicalPhrase phrase;

  /// Bitişin karakteri — nokta şeridinin son rengini belirler.
  final bool endsAtHome;
}

class ContrastDemo extends StatefulWidget {
  const ContrastDemo({
    super.key,
    required this.phrasePlayer,
    required this.options,
    this.onAllHeard,
  });

  final PhrasePlayer phrasePlayer;
  final List<ContrastOption> options;

  /// Tüm seçenekler en az bir kez dinlendiğinde bir kez çağrılır — akış
  /// sayfası "devam" düğmesini ancak o zaman açar (dinlemeden geçilmesin).
  final VoidCallback? onAllHeard;

  @override
  State<ContrastDemo> createState() => _ContrastDemoState();
}

class _ContrastDemoState extends State<ContrastDemo> {
  int? _playingIndex;
  int? _eventIndex;
  final Set<int> _heard = {};

  Future<void> _play(int index) async {
    setState(() {
      _playingIndex = index;
      _eventIndex = null;
    });

    await widget.phrasePlayer.play(
      widget.options[index].phrase,
      onEvent: (i) {
        if (mounted) setState(() => _eventIndex = i);
      },
    );

    // Bu arada başka bir seçeneğe basıldıysa bu çalma iptal edilmiştir.
    if (!mounted || _playingIndex != index) return;
    setState(() {
      _playingIndex = null;
      _eventIndex = null;
      _heard.add(index);
    });
    if (_heard.length == widget.options.length) widget.onAllHeard?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _optionCard(i),
        ],
      ],
    );
  }

  Widget _optionCard(int index) {
    final theme = Theme.of(context);
    final option = widget.options[index];
    final playing = _playingIndex == index;
    final accent = phraseEndColor(context, endsAtHome: option.endsAtHome);

    return Semantics(
      button: true,
      label: '${option.title}. ${option.caption}',
      child: Material(
        color: playing
            ? accent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: playing ? null : () => _play(index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.caption,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        playing
                            ? Icons.graphic_eq_rounded
                            : (_heard.contains(index)
                                  ? Icons.replay_rounded
                                  : Icons.volume_up_rounded),
                        color: playing ? accent : theme.colorScheme.primary,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PhraseDots(
                    count: option.phrase.events.length,
                    activeIndex: playing ? _eventIndex : null,
                    endAccent: accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Demo başlığı için ortak metin — her track aynı davetle açılsın.
String contrastDemoHint() => t(
  en: 'Listen to both. Only the LAST note is different.',
  tr: 'İkisini de dinle. Yalnızca SON nota farklı.',
);
