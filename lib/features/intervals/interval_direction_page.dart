import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';

// -----------------------------------------------------------------------------
// ARALIĞIN YÖNÜ — çıkıcı / inici duyumu
//
// Aynı mesafe melodide yukarı da gidebilir, aşağı da. Bu adım aralığı sadece
// "kökten yukarı" ezberletmez; kullanıcı mesafeyi yönünden ayırmayı öğrenir.
// -----------------------------------------------------------------------------

enum IntervalDirection { ascending, descending }

extension IntervalDirectionLabel on IntervalDirection {
  String get label => switch (this) {
    IntervalDirection.ascending => t(en: 'Ascending', tr: 'Çıkıcı'),
    IntervalDirection.descending => t(en: 'Descending', tr: 'İnici'),
  };

  IconData get icon => switch (this) {
    IntervalDirection.ascending => Icons.arrow_upward_rounded,
    IntervalDirection.descending => Icons.arrow_downward_rounded,
  };
}

class IntervalDirectionPage extends StatefulWidget {
  const IntervalDirectionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
  });

  final List<MusicInterval> pool;
  final NotePlayer player;
  final VoidCallback onComplete;

  @override
  State<IntervalDirectionPage> createState() => _IntervalDirectionPageState();
}

class _IntervalDirectionPageState extends State<IntervalDirectionPage> {
  static final Note _root = Note.fromName('C', 4);
  final Random _rng = Random();

  late final List<MusicInterval> _rounds = _pick();
  late IntervalDirection _direction;

  int _index = 0;
  IntervalDirection? _selected;
  bool _playing = false;

  List<MusicInterval> _pick() {
    final shuffled = List<MusicInterval>.from(widget.pool)..shuffle();
    final count = widget.pool.length <= 5 ? widget.pool.length : 5;
    return shuffled.take(count).toList();
  }

  MusicInterval get _interval => _rounds[_index];
  Note get _top => _interval.topFrom(_root);

  @override
  void initState() {
    super.initState();
    _direction = _randomDirection();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  IntervalDirection _randomDirection() => _rng.nextBool()
      ? IntervalDirection.ascending
      : IntervalDirection.descending;

  Future<void> _playTarget() async {
    if (_playing) return;
    setState(() => _playing = true);
    final first = _direction == IntervalDirection.ascending ? _root : _top;
    final second = _direction == IntervalDirection.ascending ? _top : _root;
    await widget.player.play(first);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(second);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _playing = false);
  }

  void _answer(IntervalDirection choice) {
    if (_selected != null) return;
    setState(() => _selected = choice);
  }

  void _next() {
    if (_index + 1 >= _rounds.length) {
      widget.onComplete();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _direction = _randomDirection();
    });
    _playTarget();
  }

  void _skip() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final answered = selected != null;
    final correct = answered && selected == _direction;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Interval Direction · ${_index + 1}/${_rounds.length}',
            tr: 'Aralığın Yönü · ${_index + 1}/${_rounds.length}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(t(en: 'Skip', tr: 'Geç')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              const Spacer(),
              Text(
                _interval.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en: 'Did the same distance go up, or come down?',
                  tr: 'Aynı mesafe yukarı mı gitti, aşağı mı indi?',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              PlayButton(onTap: _playTarget, playing: _playing),
              const SizedBox(height: 12),
              Text(
                t(en: 'tap to listen', tr: 'dinlemek için dokun'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _directionButton(theme, IntervalDirection.ascending),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _directionButton(
                      theme,
                      IntervalDirection.descending,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 86,
                child: answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? t(
                                    en: 'Correct! ✓  ${_direction.label}',
                                    tr: 'Doğru! ✓  ${_direction.label}',
                                  )
                                : t(
                                    en: 'That was ${_direction.label}',
                                    tr: 'Bu ${_direction.label} idi',
                                  ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                            ),
                            child: Text(
                              _index + 1 >= _rounds.length
                                  ? t(en: 'Continue', tr: 'Devam')
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

  Widget _directionButton(ThemeData theme, IntervalDirection direction) {
    final selected = _selected == direction;
    final isCorrect = _selected != null && direction == _direction;
    final isWrongSelected = selected && !isCorrect;

    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (isCorrect) {
      bg = AppColors.success;
      fg = Colors.white;
    } else if (isWrongSelected) {
      bg = AppColors.danger;
      fg = Colors.white;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _selected == null ? () => _answer(direction) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(direction.icon, color: fg, size: 30),
              const SizedBox(height: 6),
              Text(
                direction.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
