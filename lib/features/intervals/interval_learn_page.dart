import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/note.dart';
import '../concept/concept_sheet.dart';
import 'interval_lesson.dart';

// -----------------------------------------------------------------------------
// ARALIKLARI TANI (öğren aşaması)
//
// Her aralığı sabit bir kökten (C4) melodik dinlet (kök → üst). Test'ten önce
// gel — mesafeyi ve adını eşleştir.
// -----------------------------------------------------------------------------

class IntervalLearnPage extends StatefulWidget {
  const IntervalLearnPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
    this.harmonic = false,
  });

  final IntervalLesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  /// true → iki nota AYNI ANDA çalınır (harmonik dersler).
  final bool harmonic;

  @override
  State<IntervalLearnPage> createState() => _IntervalLearnPageState();
}

class _IntervalLearnPageState extends State<IntervalLearnPage> {
  static final Note _root = Note.fromName('C', 4);

  int? _playing; // o an çalan aralığın yarım sesi
  bool _touring = false;

  Future<void> _playInterval(MusicInterval interval) async {
    setState(() => _playing = interval.semitones);
    if (widget.harmonic) {
      // Harmonik: kök + üst AYNI ANDA tınlar (akor motoruyla).
      await widget.player.playChord(interval.from(_root));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } else {
      await widget.player.play(_root);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      await widget.player.play(interval.topFrom(_root));
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    if (mounted && _playing == interval.semitones) {
      setState(() => _playing = null);
    }
  }

  Future<void> _tour() async {
    if (_touring) return;
    setState(() => _touring = true);
    for (final interval in widget.lesson.pool) {
      if (!mounted) break;
      await _playInterval(interval);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => _touring = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concept = widget.lesson.concept;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Meet the Intervals', tr: 'Aralıkları Tanı')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t(en: 'Listen first, then learn', tr: 'Önce dinle, öğren'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  en:
                      'Tap each interval; hear the root note, then the top '
                      'note. Feel the size of the "leap" between them.',
                  tr:
                      'Her aralığa dokun; kök notayı ve ardından üst notayı '
                      'duy. Aradaki "atlamanın" büyüklüğünü hisset.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (concept != null) ...[
                const SizedBox(height: 14),
                ConceptCardButton(concept: concept),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.lesson.pool.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _intervalCard(widget.lesson.pool[i]),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _touring ? null : _tour,
                icon: const Icon(Icons.playlist_play_rounded),
                label: Text(t(en: 'Listen in order', tr: 'Sırayla dinle')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: widget.onReady,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  t(en: "I'm Ready · Continue", tr: 'Hazırım · Devam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intervalCard(MusicInterval interval) {
    final theme = Theme.of(context);
    final playing = _playing == interval.semitones;
    final notes = interval.from(_root);
    return Material(
      color: playing
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _playInterval(interval),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interval.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: playing
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(
                        en:
                            '${notes[0].label} → ${notes[1].label}  ·  '
                            '${interval.semitones} semitone'
                            '${interval.semitones == 1 ? '' : 's'}',
                        tr:
                            '${notes[0].label} → ${notes[1].label}  ·  '
                            '${interval.semitones} yarım ses',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                color: playing
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
