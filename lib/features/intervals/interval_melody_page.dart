import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';

// -----------------------------------------------------------------------------
// MELODİ İÇİNDE ARALIK — "Bu atlama müzikte ne yaptı?"
//
// Kur/Yön adımları aralığı izole halde öğretir. Bu ekran aynı bilgiyi kısa bir
// motifin içine koyar: kullanıcı ilk iki nota arasındaki atlamayı duyar, sonra
// bu atlamanın hangi aralık olduğunu seçer. Amaç final testi değil; kulağı
// gerçek melodik bağlama yumuşakça taşımaktır.
// -----------------------------------------------------------------------------

enum _MelodyDirection { ascending, descending }

extension _MelodyDirectionLabel on _MelodyDirection {
  String get label => switch (this) {
    _MelodyDirection.ascending => t(en: 'ascending', tr: 'çıkıcı'),
    _MelodyDirection.descending => t(en: 'descending', tr: 'inici'),
  };

  IconData get icon => switch (this) {
    _MelodyDirection.ascending => Icons.trending_up_rounded,
    _MelodyDirection.descending => Icons.trending_down_rounded,
  };
}

class IntervalMelodyPage extends StatefulWidget {
  const IntervalMelodyPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
  });

  final List<MusicInterval> pool;
  final NotePlayer player;
  final VoidCallback onComplete;

  @override
  State<IntervalMelodyPage> createState() => _IntervalMelodyPageState();
}

class _IntervalMelodyPageState extends State<IntervalMelodyPage> {
  static const int _maxOptions = 4;
  final Random _rng = Random();

  late final List<MusicInterval> _rounds = _pickRounds();
  late List<MusicInterval> _options;
  late _MelodyDirection _direction;
  late List<Note> _motif;

  int _index = 0;
  MusicInterval? _selected;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _pickQuestion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playMotif());
  }

  List<MusicInterval> _pickRounds() {
    final shuffled = List<MusicInterval>.from(widget.pool)..shuffle(_rng);
    final count = min(5, widget.pool.length);
    return shuffled.take(count).toList();
  }

  MusicInterval get _target => _rounds[_index];

  void _pickQuestion() {
    _direction = _rng.nextBool()
        ? _MelodyDirection.ascending
        : _MelodyDirection.descending;
    _motif = _buildMotif(_target, _direction);

    final opts = <MusicInterval>{_target};
    final limit = min(_maxOptions, widget.pool.length);
    while (opts.length < limit) {
      opts.add(widget.pool[_rng.nextInt(widget.pool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
  }

  List<Note> _buildMotif(MusicInterval interval, _MelodyDirection direction) {
    // İlk iki nota hedef aralığı verir. Üçüncü nota küçük bir "devam" hissi
    // ekler; böylece kullanıcı aralığı kuru bir test değil, melodik cümle
    // içinde duyar.
    if (direction == _MelodyDirection.ascending) {
      final first = Note.fromName('C', 4);
      final second = interval.topFrom(first);
      final tailStep = interval.semitones <= 2 ? 1 : -2;
      return [first, second, Note(second.midi + tailStep)];
    }

    final first = Note.fromName('C', 5);
    final second = Note(first.midi - interval.semitones);
    final tailStep = interval.semitones <= 2 ? -1 : 2;
    return [first, second, Note(second.midi + tailStep)];
  }

  Future<void> _playMotif() async {
    if (_playing) return;
    setState(() => _playing = true);

    for (final note in _motif) {
      await widget.player.play(note);
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (mounted) setState(() => _playing = false);
  }

  void _answer(MusicInterval choice) {
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
    _playMotif();
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
        title: Text(
          t(
            en: 'In the Melody · ${_index + 1}/${_rounds.length}',
            tr: 'Melodi İçinde · ${_index + 1}/${_rounds.length}',
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
              Icon(_direction.icon, size: 42, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                t(
                  en: 'Which interval is the first leap in the melody?',
                  tr: 'Melodideki ilk atlama hangi aralık?',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en:
                      'Focus on the first two notes: the leap you hear is '
                      '${_direction.label}; the last note just completes the '
                      'melody.',
                  tr:
                      'İlk iki notaya odaklan: ${_direction.label} bir sıçrama '
                      'duyacaksın, son nota sadece melodiyi tamamlıyor.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              _MotifCard(notes: _motif),
              const SizedBox(height: 18),
              PlayButton(onTap: _playMotif, playing: _playing),
              const SizedBox(height: 10),
              Text(
                t(
                  en: 'tap to hear the motif',
                  tr: 'motifi dinlemek için dokun',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.65,
                children: _options
                    .map((iv) => _optionButton(theme, iv))
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 88,
                child: answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? t(
                                    en: 'Correct! ✓  ${_target.name}',
                                    tr: 'Doğru! ✓  ${_target.name}',
                                  )
                                : t(
                                    en: 'The first leap was ${_target.name}',
                                    tr: 'İlk atlama ${_target.name} idi',
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

  Widget _optionButton(ThemeData theme, MusicInterval interval) {
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;
    if (_selected != null) {
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
        onTap: _selected == null ? () => _answer(interval) : null,
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

class _MotifCard extends StatelessWidget {
  const _MotifCard({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            _NoteDot(label: i == 0 ? '1' : '${i + 1}'),
            if (i < notes.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: i == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: i == 0 ? 28 : 22,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoteDot extends StatelessWidget {
  const _NoteDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
