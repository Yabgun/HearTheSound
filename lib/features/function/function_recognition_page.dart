import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/major_key.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'function_lesson.dart';

// -----------------------------------------------------------------------------
// İŞLEV TANIMA — "Bu akorun işlevi ne?"
//
// Önce TONİK (ev) çalınır, sonra hedef akor. Kullanıcı işlevini seçer
// (Tonik / Subdominant / Dominant). Bağlam olmadan işlev duyulamaz — o yüzden
// referans tonik şart.
// -----------------------------------------------------------------------------

class FunctionRecognitionPage extends StatefulWidget {
  const FunctionRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    required this.onComplete,
    this.majorKey = MajorKey.c,
  });

  final List<DegreeChord> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;
  final MajorKey majorKey;

  @override
  State<FunctionRecognitionPage> createState() =>
      _FunctionRecognitionPageState();
}

class _FunctionRecognitionPageState extends State<FunctionRecognitionPage> {
  final Random _rng = Random();

  late final List<HarmonicFunction> _options = _distinctFunctions();

  late DegreeChord _target;
  HarmonicFunction? _selected;
  bool _answered = false;
  final List<String> _mistakes = [];
  int _index = 0;
  int _correct = 0;

  List<HarmonicFunction> _distinctFunctions() {
    final set = <HarmonicFunction>{for (final d in widget.pool) d.function};
    return [
      for (final f in HarmonicFunction.values)
        if (set.contains(f)) f,
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

  /// Önce tonik (ev), sonra hedef akor.
  Future<void> _playTarget() async {
    await widget.player.playChord(tonicForDegrees(widget.pool).notes);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    await widget.player.playChord(_target.chord.notes);
  }

  void _answer(HarmonicFunction f) {
    if (_answered) return;
    setState(() {
      _selected = f;
      _answered = true;
      if (f == _target.function) {
        _correct++;
      } else {
        _mistakes.add('function:${_target.function.name}>${f.name}');
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
    final correct = _answered && _selected == _target.function;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en:
                '${widget.majorKey.label} · Function '
                '${_index + 1}/${widget.questionCount}',
            tr:
                '${widget.majorKey.label} · İşlev '
                '${_index + 1}/${widget.questionCount}',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            Text(
              t(
                en:
                    'First home (the tonic), then the chord. '
                    'What is its function?',
                tr: 'Önce ev (tonik), sonra akor. İşlevi ne?',
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
              t(
                en: 'tonic → chord · tap to listen',
                tr: 'tonik → akor · dinlemek için dokun',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.6,
              children: _options.map((f) => _optionButton(theme, f)).toList(),
            ),
            const SizedBox(height: 20),
            if (_answered)
              Column(
                children: [
                  Text(
                    correct
                        ? t(
                            en: 'Correct! ✓  ${_target.function.label}',
                            tr: 'Doğru! ✓  ${_target.function.label}',
                          )
                        : t(
                            en:
                                'That was ${_target.function.label} '
                                '(${_target.roman} · ${_target.chord.label})',
                            tr:
                                'Bu ${_target.function.label} idi '
                                '(${_target.roman} · ${_target.chord.label})',
                          ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: correct ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _target.roleHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(ThemeData theme, HarmonicFunction f) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (f == _target.function) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (f == _selected) {
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
        onTap: _answered ? null : () => _answer(f),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              f.label,
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
