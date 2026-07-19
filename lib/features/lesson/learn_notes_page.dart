import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../concept/concept_sheet.dart';
import 'lesson.dart';

// -----------------------------------------------------------------------------
// ÖĞREN AŞAMASI — "Notaları Tanı"
//
// Test'ten ÖNCE gelir (pedagoji ilkesi: hiç duymadığın notayı tanıyamazsın).
// Her notaya dokununca sesi + adı birlikte verilir; "Sırayla dinle" rehberli
// bir tur çalar. Hazır hissedince teste geçilir.
// -----------------------------------------------------------------------------

class LearnNotesPage extends StatefulWidget {
  const LearnNotesPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
  });

  final Lesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  @override
  State<LearnNotesPage> createState() => _LearnNotesPageState();
}

class _LearnNotesPageState extends State<LearnNotesPage> {
  int? _playingMidi; // o an çalan notayı vurgula
  bool _touring = false;

  Future<void> _play(Note n) async {
    setState(() => _playingMidi = n.midi);
    await widget.player.play(n);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted && _playingMidi == n.midi) {
      setState(() => _playingMidi = null);
    }
  }

  Future<void> _tour() async {
    if (_touring) return;
    setState(() => _touring = true);
    for (final n in widget.lesson.pool) {
      if (!mounted) break;
      setState(() => _playingMidi = n.midi);
      await widget.player.play(n);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    }
    if (mounted) {
      setState(() {
        _playingMidi = null;
        _touring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Meet the Notes', tr: 'Notaları Tanı')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
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
                  en: 'Tap each note; match its sound to its name. When you feel ready, move on to the test.',
                  tr: 'Her notaya dokun; sesini ve adını eşleştir. Hazır hissedince teste geç.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.lesson.concept != null) ...[
                const SizedBox(height: 14),
                ConceptCardButton(concept: widget.lesson.concept!),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.lesson.pool.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _noteCard(widget.lesson.pool[i]),
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
                  t(
                    en: "I'm Ready · Start the Test",
                    tr: 'Hazırım · Teste Geç',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteCard(Note n) {
    final theme = Theme.of(context);
    final playing = _playingMidi == n.midi;
    return Material(
      color: playing
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Text(
                n.name,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: playing
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                n.label, // ör. C4
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
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
