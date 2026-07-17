import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../concept/concept_sheet.dart';
import 'function_lesson.dart';

// -----------------------------------------------------------------------------
// İŞLEVLERİ TANI (öğren aşaması)
//
// Her dereceyi tonik bağlamında dinletir: önce ev, sonra hedef akor. Kullanıcı
// Roman rakamını ezberlemek yerine akorun davranış ailesini öğrenir.
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
    await widget.player.playChord(tonicForDegrees(widget.lesson.pool).notes);
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
      appBar: AppBar(title: Text('İşlevleri Tanı · ${widget.lesson.key.label}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Önce davranışı öğren', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${widget.lesson.key.label}de her karta dokun: önce tonik yani ev, sonra hedef akor çalar. '
                'Akorun ev, hazırlık veya gerilim gibi davranmasına odaklan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (concept != null) ...[
                const SizedBox(height: 14),
                ConceptCardButton(concept: concept),
              ],
              const SizedBox(height: 14),
              _familyGuide(theme),
              const SizedBox(height: 14),
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

  Widget _familyGuide(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _familyChip(theme, HarmonicFunction.tonic, 'I · iii · vi'),
        _familyChip(theme, HarmonicFunction.subdominant, 'IV · ii'),
        _familyChip(theme, HarmonicFunction.dominant, 'V · vii°'),
      ],
    );
  }

  Widget _familyChip(
    ThemeData theme,
    HarmonicFunction function,
    String romans,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            function.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            romans,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _degreeCard(DegreeChord d) {
    final theme = Theme.of(context);
    final playing = _playingRoman == d.roman;
    final bg = playing
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final accent =
        playing ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  d.roman,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.chord.label} · ${d.function.label}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.roleHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.why,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
