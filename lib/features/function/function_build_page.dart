import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/major_key.dart';
import 'function_lesson.dart';

// -----------------------------------------------------------------------------
// DERECEYİ KUR — Roman rakamı → akor → işlev ailesi
//
// İşlev tanıma kulağa dayalıdır; ama kullanıcı önce teorik haritayı kurmadan
// "Tüm Dereceler" dersinde kaybolabilir. Bu rehberli adım, her dereceyi Do majör
// içindeki somut akoruyla ve işlev ailesiyle eşleştirir. Puanlı test değildir;
// final ölçüm hâlâ FunctionRecognitionPage'dedir.
// -----------------------------------------------------------------------------

class FunctionBuildPage extends StatefulWidget {
  const FunctionBuildPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.majorKey = MajorKey.c,
  });

  final List<DegreeChord> pool;
  final NotePlayer player;
  final VoidCallback onComplete;
  final MajorKey majorKey;

  @override
  State<FunctionBuildPage> createState() => _FunctionBuildPageState();
}

class _FunctionBuildPageState extends State<FunctionBuildPage> {
  static const int _maxOptions = 4;
  final Random _rng = Random();

  late final List<DegreeChord> _rounds = _pickRounds();
  late List<DegreeChord> _options;

  int _index = 0;
  DegreeChord? _selected;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _pickQuestion();
  }

  List<DegreeChord> _pickRounds() {
    final shuffled = List<DegreeChord>.from(widget.pool)..shuffle(_rng);
    final count = min(5, widget.pool.length);
    return shuffled.take(count).toList();
  }

  DegreeChord get _target => _rounds[_index];

  void _pickQuestion() {
    final opts = <DegreeChord>{_target};
    final limit = min(_maxOptions, widget.pool.length);
    while (opts.length < limit) {
      opts.add(widget.pool[_rng.nextInt(widget.pool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
  }

  Future<void> _playTarget() async {
    if (_playing) return;
    setState(() => _playing = true);
    await widget.player.playChord(tonicForDegrees(widget.pool).notes);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await widget.player.playChord(_target.chord.notes);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _playing = false);
  }

  void _answer(DegreeChord choice) {
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
    final cols = _options.length <= 2 ? _options.length : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dereceyi Kur · ${_index + 1}/${_rounds.length}'),
        actions: [TextButton(onPressed: _skip, child: const Text('Geç'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
              Text(
                '${widget.majorKey.label}de ${_target.roman}. derece hangi akor?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Önce teorik haritayı kur: derece → akor → işlev ailesi. '
                'İstersen tonik → hedef akor olarak dinle.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _DegreeBadge(degree: _target.roman),
              const SizedBox(height: 18),
              Center(child: _PlayButton(onTap: _playTarget, playing: _playing)),
              const SizedBox(height: 8),
              Text(
                'tonik → hedef akor',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 28),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.15,
                children: _options.map((d) => _optionButton(theme, d)).toList(),
              ),
              const SizedBox(height: 16),
              if (answered)
                Column(
                  children: [
                          Text(
                            correct
                                ? 'Doğru! ${_target.roman} = ${_target.chord.label}'
                                : '${_target.roman}, ${_target.chord.label} idi',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? const Color(0xFF56C271)
                                  : const Color(0xFFD25872),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_target.function.label}: ${_target.roleHint}',
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
                                  ? 'Teste Geç'
                                  : 'Sonraki',
                            ),
                          ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(ThemeData theme, DegreeChord degree) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_selected != null) {
      if (degree == _target) {
        bg = const Color(0xFF2E7D4F);
        fg = Colors.white;
      } else if (degree == _selected) {
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
        onTap: _selected == null ? () => _answer(degree) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                degree.chord.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                degree.function.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DegreeBadge extends StatelessWidget {
  const _DegreeBadge({required this.degree});

  final String degree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 118,
        height: 118,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primaryContainer,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Text(
          degree,
          style: theme.textTheme.displaySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
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
      onTap: playing ? null : onTap,
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
          color: theme.colorScheme.onPrimary,
          size: 36,
        ),
      ),
    );
  }
}
