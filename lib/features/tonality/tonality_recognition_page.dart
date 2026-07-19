import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'tonality_lesson.dart';

// -----------------------------------------------------------------------------
// DERECE TANIMA — "Tonikten sonra duyduğun ses kaçıncı derece?"
//
// İlk sürüm sabit Do majörde çalışır. Sonraki aşamada aynı modeli farklı
// tonalitelere genişleteceğiz; kullanıcı görevi ezber değil ilişki olarak duyacak.
// -----------------------------------------------------------------------------

class TonalityRecognitionPage extends StatefulWidget {
  const TonalityRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    required this.onComplete,
  });

  final List<ScaleDegree> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;

  @override
  State<TonalityRecognitionPage> createState() =>
      _TonalityRecognitionPageState();
}

class _TonalityRecognitionPageState extends State<TonalityRecognitionPage> {
  static const int _maxOptions = 4;
  static final Note _tonic = Note.fromName('C', 4);

  final Random _rng = Random();

  late ScaleDegree _target;
  late List<ScaleDegree> _options;
  ScaleDegree? _selected;
  bool _answered = false;
  final List<String> _mistakes = [];
  int _index = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _pick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  void _pick() {
    _target = widget.pool[_rng.nextInt(widget.pool.length)];
    final opts = <ScaleDegree>{_target};
    final limit = min(_maxOptions, widget.pool.length);
    while (opts.length < limit) {
      opts.add(widget.pool[_rng.nextInt(widget.pool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
    _answered = false;
  }

  Future<void> _playTarget() async {
    await widget.player.play(_tonic);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(_target.noteFrom(_tonic));
  }

  void _answer(ScaleDegree choice) {
    if (_answered) return;
    setState(() {
      _selected = choice;
      _answered = true;
      if (choice == _target) {
        _correct++;
      } else {
        _mistakes.add('degree:${_target.number}>${choice.number}');
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
    final correct = _answered && _selected == _target;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Degree ${_index + 1} / ${widget.questionCount}',
            tr: 'Derece ${_index + 1} / ${widget.questionCount}',
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
                t(
                  en: 'Tonic → target. Which degree is this?',
                  tr: 'Tonik → hedef. Bu kaçıncı derece?',
                ),
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
                children: _options.map((d) => _optionButton(theme, d)).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 96,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? t(
                                    en: 'Correct! ✓  ${_target.label}',
                                    tr: 'Doğru! ✓  ${_target.label}',
                                  )
                                : t(
                                    en:
                                        'That was ${_target.label} '
                                        '(${_target.name})',
                                    tr:
                                        'Bu ${_target.label} idi '
                                        '(${_target.name})',
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

  Widget _optionButton(ThemeData theme, ScaleDegree degree) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (degree == _target) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (degree == _selected) {
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
        onTap: _answered ? null : () => _answer(degree),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              degree.label,
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
