import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/chord.dart';
import '../../core/note.dart';
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
      appBar: AppBar(title: const Text('Akorları Tanı')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Önce dinle, öğren', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Her akoru ve onu oluşturan notaları tek tek dinle. Notalara dokunarak seslerini öğren.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
                child: const Text('Hazırım · Devam'),
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
                label: const Text('Akor'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'notaları:',
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
            Icon(Icons.volume_up_rounded,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
