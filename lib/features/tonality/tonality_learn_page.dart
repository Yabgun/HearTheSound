import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../concept/concept_sheet.dart';
import 'tonality_lesson.dart';

// -----------------------------------------------------------------------------
// TONALİTE ÖĞREN — önce bağlamı kur, sonra dereceyi duy
//
// Sabit Do majör ile başlıyoruz. Amaç absolute pitch ezberletmek değil; tonik
// referansından sonra hedef derecenin "ev içindeki yerini" hissettirmek.
// -----------------------------------------------------------------------------

class TonalityLearnPage extends StatefulWidget {
  const TonalityLearnPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onReady,
  });

  final TonalityLesson lesson;
  final NotePlayer player;
  final VoidCallback onReady;

  @override
  State<TonalityLearnPage> createState() => _TonalityLearnPageState();
}

class _TonalityLearnPageState extends State<TonalityLearnPage> {
  static final Note _tonic = Note.fromName('C', 4);

  int? _playingDegree;
  bool _playingScale = false;

  Future<void> _playScale() async {
    if (_playingScale) return;
    setState(() => _playingScale = true);
    for (final note in majorScaleFrom(_tonic)) {
      if (!mounted) break;
      await widget.player.play(note);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (mounted) setState(() => _playingScale = false);
  }

  Future<void> _playDegree(ScaleDegree degree) async {
    setState(() => _playingDegree = degree.number);
    await widget.player.play(_tonic);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(degree.noteFrom(_tonic));
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (mounted && _playingDegree == degree.number) {
      setState(() => _playingDegree = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Scales and Tonality', tr: 'Diziler ve Tonalite')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t(en: 'Hear home first', tr: 'Önce evi duy'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  en:
                      'The tonic C4 is our home. Listen to the major scale '
                      'first, then compare how each degree feels next to home.',
                  tr:
                      'Tonik C4 bizim evimiz. Önce majör diziyi dinle, sonra '
                      'her derecenin eve göre nasıl hissettirdiğini '
                      'karşılaştır.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              ConceptCardButton(concept: widget.lesson.concept),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _playingScale ? null : _playScale,
                icon: const Icon(Icons.piano_rounded),
                label: Text(
                  t(
                    en: 'Listen to the C major scale',
                    tr: 'Do majör dizisini dinle',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
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
                child: Text(
                  t(
                    en: "I'm Ready · Start Recognizing",
                    tr: 'Hazırım · Tanımaya geç',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _degreeCard(ScaleDegree degree) {
    final theme = Theme.of(context);
    final playing = _playingDegree == degree.number;
    final note = degree.noteFrom(_tonic);
    return Material(
      color: playing
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _playDegree(degree),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '${degree.number}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: playing
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${degree.label} · ${degree.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${note.label} · ${degree.role}',
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
