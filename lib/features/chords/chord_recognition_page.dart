import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../lesson/lesson.dart';

// -----------------------------------------------------------------------------
// AKOR TANIMA — "Bu hangi akor?"
//
// Ders havuzundaki bir akoru çalar; kullanıcı hangi akor olduğunu seçer.
// Şıklar = dersin akorları (ad ile). (Majör/minör değil, spesifik akor.)
// -----------------------------------------------------------------------------

/// Soru tipi: akorun adını mı yoksa oluşturan notaları mı soralım?
enum _QMode { name, notes }

class ChordRecognitionPage extends StatefulWidget {
  const ChordRecognitionPage({
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
  State<ChordRecognitionPage> createState() => _ChordRecognitionPageState();
}

class _ChordRecognitionPageState extends State<ChordRecognitionPage> {
  final Random _rng = Random();
  late Chord _target;
  late List<Chord> _options;
  Chord? _selected;
  bool _answered = false;
  int _index = 0;
  int _correct = 0;
  late _QMode _mode;

  @override
  void initState() {
    super.initState();
    _pick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  void _pick() {
    _target = widget.pool[_rng.nextInt(widget.pool.length)];
    _options = List<Chord>.of(widget.pool)..shuffle(_rng);
    _mode = _rng.nextBool() ? _QMode.name : _QMode.notes;
    _selected = null;
    _answered = false;
  }

  Future<void> _playTarget() => widget.player.playChord(_target.notes);

  void _answer(Chord c) {
    if (_answered) return;
    setState(() {
      _selected = c;
      _answered = true;
      if (c == _target) _correct++;
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

  void _finish() => widget.onComplete(LessonResult(_correct, widget.questionCount));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _answered && _selected == _target;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;
    final cols = widget.pool.length <= 2 ? widget.pool.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('Akor ${_index + 1} / ${widget.questionCount}'),
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
                _mode == _QMode.name
                    ? 'Bu hangi akor?'
                    : 'Bu sesi hangi notalar oluşturuyor?',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PlayButton(onTap: _playTarget),
              const SizedBox(height: 12),
              Text(
                'dinlemek için dokun',
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
                childAspectRatio: 2.4,
                children: _options.map((c) => _optionButton(theme, c)).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 84,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? 'Doğru! ✓  ${_target.label}'
                                : 'Bu ${_target.label} idi',
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

  Widget _optionButton(ThemeData theme, Chord c) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (c == _target) {
        bg = const Color(0xFF2E7D4F);
        fg = Colors.white;
      } else if (c == _selected) {
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
        onTap: _answered ? null : () => _answer(c),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _mode == _QMode.name
                  ? c.label
                  : c.notes.map((n) => n.name).join(' · '),
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
