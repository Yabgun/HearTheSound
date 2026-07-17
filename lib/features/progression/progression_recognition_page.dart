import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/major_key.dart';
import '../lesson/lesson.dart';
import 'progression_lesson.dart';

// -----------------------------------------------------------------------------
// İLERLEME TANIMA — "Hangi ilerleme?"
//
// Akor dizisini sırayla çalar; kullanıcı hangi kalıp olduğunu seçer. Şıklar =
// havuzdaki ilerlemeler (Roman rakamlı adlarıyla).
// -----------------------------------------------------------------------------

class ProgressionRecognitionPage extends StatefulWidget {
  const ProgressionRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    required this.onComplete,
    this.majorKey = MajorKey.c,
  });

  final List<Progression> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;
  final MajorKey majorKey;

  @override
  State<ProgressionRecognitionPage> createState() =>
      _ProgressionRecognitionPageState();
}

class _ProgressionRecognitionPageState
    extends State<ProgressionRecognitionPage> {
  final Random _rng = Random();

  late Progression _target;
  late List<Progression> _options;
  Progression? _selected;
  bool _answered = false;
  bool _playing = false;
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
    _options = List<Progression>.of(widget.pool)..shuffle(_rng);
    _selected = null;
    _answered = false;
  }

  Future<void> _playTarget() async {
    if (_playing) return;
    setState(() => _playing = true);
    for (final chord in _target.chords) {
      if (!mounted) break;
      await widget.player.playChord(chord.notes);
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    if (mounted) setState(() => _playing = false);
  }

  void _answer(Progression p) {
    if (_answered) return;
    setState(() {
      _selected = p;
      _answered = true;
      if (p == _target) _correct++;
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
    final correct = _answered && _selected == _target;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.majorKey.label} · İlerleme ${_index + 1}/${widget.questionCount}'),
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
                'Hangi ilerleme?',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PlayButton(onTap: _playTarget, playing: _playing),
              const SizedBox(height: 12),
              Text(
                'diziyi dinlemek için dokun',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(flex: 2),
              ..._options.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _optionButton(theme, p),
                  )),
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct ? 'Doğru! ✓  ${_target.name}' : 'Bu ${_target.name} idi',
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

  Widget _optionButton(ThemeData theme, Progression p) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (p == _target) {
        bg = const Color(0xFF2E7D4F);
        fg = Colors.white;
      } else if (p == _selected) {
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
        onTap: _answered ? null : () => _answer(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: Text(
              p.name,
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
  const _PlayButton({required this.onTap, required this.playing});

  final VoidCallback onTap;
  final bool playing;

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
        child: Icon(
          playing ? Icons.graphic_eq_rounded : Icons.playlist_play_rounded,
          size: 56,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
