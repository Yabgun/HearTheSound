import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';

// -----------------------------------------------------------------------------
// ARALIK TANIMA — "Bu hangi aralık?"
//
// Rastgele bir kökten melodik (kök → üst) bir aralık çalar; kullanıcı adını
// seçer. Kök rastgele değişir ki aralık kökten bağımsız, "boyutundan" tanınsın.
// -----------------------------------------------------------------------------

class IntervalRecognitionPage extends StatefulWidget {
  const IntervalRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    required this.onComplete,
    this.harmonic = false,
  });

  final List<MusicInterval> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result) onComplete;

  /// true → sorular iki notayı AYNI ANDA çalar (harmonik dersler).
  final bool harmonic;

  @override
  State<IntervalRecognitionPage> createState() =>
      _IntervalRecognitionPageState();
}

class _IntervalRecognitionPageState extends State<IntervalRecognitionPage> {
  static const int _maxOptions = 4;
  final Random _rng = Random();

  late MusicInterval _target;
  late List<MusicInterval> _options;
  late int _rootMidi;
  MusicInterval? _selected;
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
    // Kök C3..C4 arası rastgele — dinlenebilir bir bantta tut.
    _rootMidi = Note.fromName('C', 3).midi + _rng.nextInt(13);

    final opts = <MusicInterval>{_target};
    final limit = min(_maxOptions, widget.pool.length);
    while (opts.length < limit) {
      opts.add(widget.pool[_rng.nextInt(widget.pool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
    _answered = false;
  }

  Future<void> _playTarget() async {
    final root = Note(_rootMidi);
    if (widget.harmonic) {
      // Harmonik soru: kök + üst aynı anda.
      await widget.player.playChord(_target.from(root));
      return;
    }
    await widget.player.play(root);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(_target.topFrom(root));
  }

  void _answer(MusicInterval choice) {
    if (_answered) return;
    setState(() {
      _selected = choice;
      _answered = true;
      if (choice == _target) {
        _correct++;
      } else {
        _mistakes.add('interval:${_target.semitones}>${choice.semitones}');
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
            en: 'Interval ${_index + 1} / ${widget.questionCount}',
            tr: 'Aralık ${_index + 1} / ${widget.questionCount}',
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
                t(en: 'Which interval is this?', tr: 'Bu hangi aralık?'),
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
                    .map((iv) => _optionButton(theme, iv))
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
                                    en: 'Correct! ✓  ${_target.name}',
                                    tr: 'Doğru! ✓  ${_target.name}',
                                  )
                                : t(
                                    en: 'That was ${_target.name}',
                                    tr: 'Bu ${_target.name} idi',
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

  Widget _optionButton(ThemeData theme, MusicInterval interval) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_answered) {
      if (interval == _target) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (interval == _selected) {
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
        onTap: _answered ? null : () => _answer(interval),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              interval.name,
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
