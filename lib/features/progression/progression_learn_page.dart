import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../concept/concept_sheet.dart';
import 'progression_lesson.dart';

// -----------------------------------------------------------------------------
// İLERLEMELERİ TANI (öğren aşaması)
//
// Her ilerlemeye dokun; akorları sırayla dinle. Roman rakamlı adı ve akor
// zinciri (ör. C – F – G – C) gösterilir.
// -----------------------------------------------------------------------------

class ProgressionLearnPage extends StatefulWidget {
  const ProgressionLearnPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
  });

  final ProgressionLesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  @override
  State<ProgressionLearnPage> createState() => _ProgressionLearnPageState();
}

class _ProgressionLearnPageState extends State<ProgressionLearnPage> {
  String? _playingName;

  Future<void> _play(Progression p) async {
    setState(() => _playingName = p.name);
    for (final chord in p.chords) {
      if (!mounted) break;
      await widget.player.playChord(chord.notes);
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    if (mounted && _playingName == p.name) {
      setState(() => _playingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concept = widget.lesson.concept;
    return Scaffold(
      appBar: AppBar(title: Text('İlerlemeleri Tanı · ${widget.lesson.key.label}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Önce dinle, öğren', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${widget.lesson.key.label}de her ilerlemeye dokun; akorlar sırayla çalar. Dizinin genel '
                'hareketini (ev → gerilim → dönüş) hisset.',
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
                  itemBuilder: (_, i) => _progressionCard(widget.lesson.pool[i]),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onReady,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Hazırım · Teste Geç'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressionCard(Progression p) {
    final theme = Theme.of(context);
    final playing = _playingName == p.name;
    return Material(
      color: playing
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: playing
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.chordChain,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.story,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: playing
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.cadenceHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                playing ? Icons.graphic_eq_rounded : Icons.playlist_play_rounded,
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
