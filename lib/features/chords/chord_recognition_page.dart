import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
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
  final List<String> _mistakes = [];
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
      if (c == _target) {
        _correct++;
      } else {
        _mistakes.add(
          'chord:${_target.root.name}.${_target.quality.name}>${c.root.name}.${c.quality.name}',
        );
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
    final cols = widget.pool.length <= 2 ? widget.pool.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Chord ${_index + 1} / ${widget.questionCount}',
            tr: 'Akor ${_index + 1} / ${widget.questionCount}',
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
                _mode == _QMode.name
                    ? t(en: 'Which chord?', tr: 'Bu hangi akor?')
                    : t(
                        en: 'Which notes make this sound?',
                        tr: 'Bu sesi hangi notalar oluşturuyor?',
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
                                ? t(
                                    en: 'Correct! ✓  ${_target.label}',
                                    tr: 'Doğru! ✓  ${_target.label}',
                                  )
                                : t(
                                    en: 'It was ${_target.label}',
                                    tr: 'Bu ${_target.label} idi',
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

  Widget _optionButton(ThemeData theme, Chord c) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (c == _target) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (c == _selected) {
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
