import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/major_key.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import 'progression_lesson.dart';

// -----------------------------------------------------------------------------
// İLERLEMEYİ KUR — Roman zincir → işlev hareketi
//
// Kullanıcı progression adını yalnızca ezberlemesin; akor zincirinin cümle içinde
// ne yaptığını da okusun: evden uzaklaşma, gerilim kurma, eve çözülme ya da açık
// döngü bırakma. Bu rehberli adım puanlı test değildir; final ölçüm tanımadadır.
// -----------------------------------------------------------------------------

class ProgressionBuildPage extends StatefulWidget {
  const ProgressionBuildPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.majorKey = MajorKey.c,
  });

  final List<Progression> pool;
  final NotePlayer player;
  final VoidCallback onComplete;
  final MajorKey majorKey;

  @override
  State<ProgressionBuildPage> createState() => _ProgressionBuildPageState();
}

class _ProgressionBuildPageState extends State<ProgressionBuildPage> {
  final Random _rng = Random();

  late final List<Progression> _rounds = _pickRounds();
  late List<Progression> _options;

  int _index = 0;
  Progression? _selected;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _pickQuestion();
  }

  List<Progression> _pickRounds() {
    final shuffled = List<Progression>.from(widget.pool)..shuffle(_rng);
    return shuffled.take(min(5, widget.pool.length)).toList();
  }

  Progression get _target => _rounds[_index];

  void _pickQuestion() {
    _options = List<Progression>.of(widget.pool)..shuffle(_rng);
    _selected = null;
  }

  Future<void> _playTarget() async {
    if (_playing) return;
    setState(() => _playing = true);
    for (final chord in _target.chords) {
      if (!mounted) break;
      await widget.player.playChord(chord.notes);
      await Future<void>.delayed(const Duration(milliseconds: 720));
    }
    if (mounted) setState(() => _playing = false);
  }

  void _answer(Progression choice) {
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
      _pickQuestion();
    });
  }

  void _skip() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = _selected != null;
    final correct = answered && _selected == _target;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en:
                '${widget.majorKey.label} · Build · '
                '${_index + 1}/${_rounds.length}',
            tr:
                '${widget.majorKey.label} · Kur · '
                '${_index + 1}/${_rounds.length}',
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                _target.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en:
                      'What kind of motion does this chain create in the '
                      'music?',
                  tr: 'Bu zincir müzikte nasıl bir hareket kuruyor?',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _ChordChainCard(progression: _target),
              const SizedBox(height: 18),
              Center(
                child: PlayButton(onTap: _playTarget, playing: _playing),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en: 'tap to hear the chord sequence',
                  tr: 'akor dizisini dinlemek için dokun',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              ..._options.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _optionButton(theme, p),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? t(en: 'Correct! ✓', tr: 'Doğru! ✓')
                                : t(
                                    en: 'The motion went like this:',
                                    tr: 'Bu hareket şöyleydi:',
                                  ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_target.story}\n${_target.cadenceHint}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
                                  ? t(en: 'Start the Test', tr: 'Teste Geç')
                                  : t(en: 'Next', tr: 'Sonraki'),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionButton(ThemeData theme, Progression progression) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_selected != null) {
      if (progression == _target) {
        bg = AppColors.success;
        fg = Colors.white;
      } else if (progression == _selected) {
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
        onTap: _selected == null ? () => _answer(progression) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            progression.story,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChordChainCard extends StatelessWidget {
  const _ChordChainCard({required this.progression});

  final Progression progression;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            progression.chordChain,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progression.functionPath,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
