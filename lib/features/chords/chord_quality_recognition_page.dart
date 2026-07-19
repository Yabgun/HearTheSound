import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';

// -----------------------------------------------------------------------------
// NİTELİK TANIMA — "Bu ne niteliği?"
//
// Akoru çalar; kullanıcı KÖKTEN BAĞIMSIZ olarak niteliğini (majör/minör/eksik/
// artık) seçer. "Hangi akor?" (spesifik) ekranından farkı: burada amaç akorun
// RENGİNİ duymak. Şıklar = havuzdaki farklı nitelikler.
// -----------------------------------------------------------------------------

class ChordQualityRecognitionPage extends StatefulWidget {
  const ChordQualityRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    required this.onComplete,
  });

  final List<Chord> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;

  @override
  State<ChordQualityRecognitionPage> createState() =>
      _ChordQualityRecognitionPageState();
}

class _ChordQualityRecognitionPageState
    extends State<ChordQualityRecognitionPage> {
  final Random _rng = Random();

  /// Havuzdaki farklı nitelikler = şıklar (sabit, oturum boyu).
  late final List<ChordQuality> _options = _distinctQualities();

  late Chord _target;
  ChordQuality? _selected;
  bool _answered = false;
  final List<String> _mistakes = [];
  int _index = 0;
  int _correct = 0;

  List<ChordQuality> _distinctQualities() {
    final set = <ChordQuality>{for (final c in widget.pool) c.quality};
    // Tanıdık sırayla göster (maj, min, dim, aug).
    return [
      for (final q in ChordQuality.values)
        if (set.contains(q)) q,
    ];
  }

  @override
  void initState() {
    super.initState();
    _pick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  void _pick() {
    _target = widget.pool[_rng.nextInt(widget.pool.length)];
    _selected = null;
    _answered = false;
  }

  Future<void> _playTarget() => widget.player.playChord(_target.notes);

  void _answer(ChordQuality q) {
    if (_answered) return;
    setState(() {
      _selected = q;
      _answered = true;
      if (q == _target.quality) {
        _correct++;
      } else {
        _mistakes.add('quality:${_target.quality.name}>${q.name}');
      }
    });
  }

  Future<void> _next() async {
    setState(() {
      _index++;
      _pick();
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _playTarget();
  }

  void _finish() => widget.onComplete(
    LessonResult(_correct, widget.questionCount, mistakes: _mistakes),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _answered && _selected == _target.quality;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Color ${_index + 1} / ${widget.questionCount}',
            tr: 'Renk ${_index + 1} / ${widget.questionCount}',
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '★ $_correct',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                t(en: 'Which quality?', tr: 'Bu ne niteliği?'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              PlayButton(onTap: _playTarget),
              const SizedBox(height: 12),
              Text(
                t(en: 'tap to listen', tr: 'dinlemek için dokun'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(flex: 2),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: _options.map((q) => _optionButton(theme, q)).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 84,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? t(
                                    en: 'Correct! ✓  ${_target.quality.label}',
                                    tr: 'Doğru! ✓  ${_target.quality.label}',
                                  )
                                : t(
                                    en: 'It was ${_target.quality.label} (${_target.label})',
                                    tr: 'Bu ${_target.quality.label} idi (${_target.label})',
                                  ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: isLast ? _finish : _next,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                            ),
                            child: Text(
                              isLast
                                  ? t(en: 'Finish', tr: 'Bitir')
                                  : t(en: 'Next', tr: 'Sonraki'),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionButton(ThemeData theme, ChordQuality q) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (q == _target.quality) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (q == _selected) {
        bg = AppColors.danger;
        fg = Colors.white;
      } else {
        bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
        fg = theme.colorScheme.onSurfaceVariant;
      }
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _answered ? null : () => _answer(q),
        child: Center(
          child: Text(
            q.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
