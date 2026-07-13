import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../concept/concept_sheet.dart';
import 'function_lesson.dart';

// -----------------------------------------------------------------------------
// İŞLEVLERİ TANI (öğren aşaması)
//
// Her dereceyi tonik bağlamında dinlet (önce ev, sonra akor). Roman rakamı,
// akor adı ve işlevi birlikte gösterilir.
// -----------------------------------------------------------------------------

class FunctionLearnPage extends StatefulWidget {
  const FunctionLearnPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
  });

  final FunctionLesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  @override
  State<FunctionLearnPage> createState() => _FunctionLearnPageState();
}

class _FunctionLearnPageState extends State<FunctionLearnPage> {
  String? _playingRoman;

  Future<void> _play(DegreeChord d) async {
    setState(() => _playingRoman = d.roman);
    await widget.player.playChord(tonicReference.notes);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    await widget.player.playChord(d.chord.notes);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (mounted && _playingRoman == d.roman) {
      setState(() => _playingRoman = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concept = widget.lesson.concept;
    return Scaffold(
      appBar: AppBar(title: const Text('İşlevleri Tanı')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Önce dinle, öğren', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Her dereceye dokun: önce tonik (ev), sonra akor çalar. Akorun '
                'seni nereye çektiğini hisset.',
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
                  itemBuilder: (_, i) => _degreeCard(widget.lesson.pool[i]),
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

  Widget _degreeCard(DegreeChord d) {
    final theme = Theme.of(context);
    final playing = _playingRoman == d.roman;
    return Material(
      color: playing
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  d.roman,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: playing
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.chord.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      d.function.label,
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
