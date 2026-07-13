import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
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
  });

  final List<DegreeChord> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;

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
    await widget.player.playChord(tonicReference.notes);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    await widget.player.playChord(_target.chord.notes);
  }

  void _answer(HarmonicFunction f) {
    if (_answered) return;
    setState(() {
      _selected = f;
      _answered = true;
      if (f == _target.function) _correct++;
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

  void _finish() =>
      widget.onComplete(LessonResult(_correct, widget.questionCount));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _answered && _selected == _target.function;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('İşlev ${_index + 1} / ${widget.questionCount}'),
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
          child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 4),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Önce ev (tonik), sonra akor. İşlevi ne?',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PlayButton(onTap: _playTarget),
              const SizedBox(height: 12),
              Text(
                'tonik → akor · dinlemek için dokun',
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
                children: _options.map((f) => _optionButton(theme, f)).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 84,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? 'Doğru! ✓  ${_target.function.label}'
                                : 'Bu ${_target.function.label} idi (${_target.roman} · ${_target.chord.label})',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? const Color(0xFF56C271)
                                  : const Color(0xFFD25872),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: isLast ? _finish : _next,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 14),
                            ),
                            child: Text(isLast ? 'Bitir' : 'Sonraki'),
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

  Widget _optionButton(ThemeData theme, HarmonicFunction f) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (f == _target.function) {
        bg = const Color(0xFF2E7D4F);
        fg = Colors.white;
      } else if (f == _selected) {
        bg = const Color(0xFF9E3B4E);
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

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        height: 128,
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
        child: Icon(Icons.volume_up_rounded,
            size: 54, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
