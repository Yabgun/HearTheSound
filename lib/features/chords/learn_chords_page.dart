import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../concept/concept_sheet.dart';
import 'chord_lesson.dart';

// -----------------------------------------------------------------------------
// AKORLARI TANI (öğren aşaması)
//
// Her akoru VE onu oluşturan notaları tek tek dinlet — kullanıcı hem akorun
// bütününü hem de arpejde çıkaracağı sesleri öğrensin.
// -----------------------------------------------------------------------------

class LearnChordsPage extends StatelessWidget {
  const LearnChordsPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
  });

  final ChordLesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Meet the Chords', tr: 'Akorları Tanı')),
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
                  en: 'Listen to each chord and the notes inside it, one by one. Tap the notes to learn their sounds.',
                  tr: 'Her akoru ve onu oluşturan notaları tek tek dinle. Notalara dokunarak seslerini öğren.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (lesson.concept != null) ...[
                const SizedBox(height: 14),
                ConceptCardButton(concept: lesson.concept!),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: lesson.pool.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _chordCard(theme, lesson.pool[i]),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onReady,
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

  Widget _chordCard(ThemeData theme, Chord chord) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                chord.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => player.playChord(chord.notes),
                icon: const Icon(Icons.piano_rounded, size: 18),
                label: Text(t(en: 'Chord', tr: 'Akor')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t(en: 'notes:', tr: 'notaları:'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final n in chord.notes)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _noteButton(theme, n),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteButton(ThemeData theme, Note note) {
    return InkWell(
      onTap: () => player.play(note),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              note.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.volume_up_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
