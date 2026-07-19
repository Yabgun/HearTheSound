import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';

// -----------------------------------------------------------------------------
// ÇEVRİM TANIMA — "Bu kaçıncı çevrim?"
//
// Akoru çalar; kullanıcı çevrimini (kapalı / 1. / 2.) seçer. Amaç akorun kendisi
// değil, EN PES notanın (bas) nerede olduğunu duymak. Şıklar = havuzdaki farklı
// çevrimler.
// -----------------------------------------------------------------------------

class ChordInversionRecognitionPage extends StatefulWidget {
  const ChordInversionRecognitionPage({
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
  State<ChordInversionRecognitionPage> createState() =>
      _ChordInversionRecognitionPageState();
}

class _ChordInversionRecognitionPageState
    extends State<ChordInversionRecognitionPage> {
  final Random _rng = Random();

  /// Havuzdaki farklı çevrimler (artan) = şıklar.
  late final List<int> _options = _distinctInversions();

  late Chord _target;
  int? _selected;
  bool _answered = false;
  final List<String> _mistakes = [];
  int _index = 0;
  int _correct = 0;

  List<int> _distinctInversions() {
    final set = <int>{for (final c in widget.pool) c.inversion};
    final list = set.toList()..sort();
    return list;
  }

  static String _label(int inv) => switch (inv) {
    1 => t(en: '1st Inversion', tr: '1. Çevrim'),
    2 => t(en: '2nd Inversion', tr: '2. Çevrim'),
    3 => t(en: '3rd Inversion', tr: '3. Çevrim'),
    _ => t(en: 'Root Position', tr: 'Kapalı'),
  };

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

  void _answer(int inv) {
    if (_answered) return;
    setState(() {
      _selected = inv;
      _answered = true;
      if (inv == _target.inversion) {
        _correct++;
      } else {
        _mistakes.add('inv:${_target.inversion}>$inv');
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
    final correct = _answered && _selected == _target.inversion;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Inversion ${_index + 1} / ${widget.questionCount}',
            tr: 'Çevrim ${_index + 1} / ${widget.questionCount}',
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
                t(en: 'Which inversion?', tr: 'Bu kaçıncı çevrim?'),
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
                children: _options
                    .map((inv) => _optionButton(theme, inv))
                    .toList(),
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
                                    en: 'Correct! ✓  ${_label(_target.inversion)}',
                                    tr: 'Doğru! ✓  ${_label(_target.inversion)}',
                                  )
                                : t(
                                    en: 'It was ${_label(_target.inversion)} (${_target.label})',
                                    tr: 'Bu ${_label(_target.inversion)} idi (${_target.label})',
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

  Widget _optionButton(ThemeData theme, int inv) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (inv == _target.inversion) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (inv == _selected) {
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
        onTap: _answered ? null : () => _answer(inv),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _label(inv),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
