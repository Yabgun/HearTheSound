import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_recognition_page.dart';
import '../lesson/lesson.dart';
import '../note_recognition/note_recognition_page.dart';

// -----------------------------------------------------------------------------
// YERLEŞTİRME TESTİ — "bildiğin yerden başla"
//
// Kısa, tanıma-temelli (mikrofon gerektirmez) bir ön test. Zorluk kademeleri
// (checkpoint) hâlinde ilerler: kolay → zor. Bir kademeyi geçemezsen o track
// (nota/akor) durur. Geçtiğin en yüksek kademe, o track'te hangi derslerin
// "biliniyor" (kilidi açık) sayılacağını belirler.
//
// Neden checkpoint? Hepsini tek tek test etmek uzun sürer; en zoru geçen kolayları
// da bilir varsayımıyla birkaç kilit noktada ölçmek hızlı ve yeterince adaptiftir.
// -----------------------------------------------------------------------------

/// Bir zorluk kademesi.
class _Rung {
  final String track; // 'note' | 'chord'
  final List<String> unlocks; // geçilirse 'biliniyor' sayılacak ders kimlikleri
  final Lesson? note;
  final ChordLesson? chord;
  const _Rung({
    required this.track,
    required this.unlocks,
    this.note,
    this.chord,
  });
}

enum _Stage { intro, running, result }

class PlacementTestPage extends ConsumerStatefulWidget {
  const PlacementTestPage({super.key});

  @override
  ConsumerState<PlacementTestPage> createState() => _PlacementTestPageState();
}

class _PlacementTestPageState extends ConsumerState<PlacementTestPage> {
  static const int _questionsPerRung = 3;
  static const int _passCorrect = 2; // 3 soruda en az 2 doğru

  final NotePlayer _player = createNotePlayer();
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;

  late final List<_Rung> _rungs = _buildRungs();
  int _index = 0;
  _Stage _stage = _Stage.intro;

  // Track başına durum: durduysa kalan kademeleri atla.
  bool _noteStopped = false;
  bool _chordStopped = false;
  // Track başına en yüksek geçilen kademenin unlock kümesi.
  List<String> _noteUnlocks = const [];
  List<String> _chordUnlocks = const [];

  List<_Rung> _buildRungs() {
    Lesson l(String id) => lessons.firstWhere((e) => e.id == id);
    ChordLesson cl(String id) => chordLessons.firstWhere((e) => e.id == id);
    return [
      _Rung(
        track: 'note',
        note: l('l3_penta'),
        unlocks: const ['first_notes', 'l2_cde', 'l3_penta'],
      ),
      _Rung(
        track: 'note',
        note: l('l5_chromatic'),
        unlocks: const [
          'first_notes',
          'l2_cde',
          'l3_penta',
          'l4_diatonic',
          'l5_chromatic',
        ],
      ),
      _Rung(track: 'chord', chord: cl('ch1'), unlocks: const ['ch1']),
      _Rung(
        track: 'chord',
        chord: cl('ch3'),
        unlocks: const ['ch1', 'ch2', 'ch3'],
      ),
    ];
  }

  Iterable<String> get _known => {..._noteUnlocks, ..._chordUnlocks};

  bool _trackStopped(String track) =>
      track == 'note' ? _noteStopped : _chordStopped;

  void _onRungComplete(_Rung rung, LessonResult result) {
    final passed = result.correct >= _passCorrect;
    if (passed) {
      if (rung.track == 'note') {
        _noteUnlocks = rung.unlocks;
      } else {
        _chordUnlocks = rung.unlocks;
      }
    } else {
      // Bu kademeyi geçemedi → track dursun (daha zoru sorulmasın).
      if (rung.track == 'note') {
        _noteStopped = true;
      } else {
        _chordStopped = true;
      }
    }
    _advance();
  }

  void _advance() {
    var next = _index + 1;
    // Track'i durmuş kademeleri atla.
    while (next < _rungs.length && _trackStopped(_rungs[next].track)) {
      next++;
    }
    setState(() {
      if (next >= _rungs.length) {
        _stage = _Stage.result;
      } else {
        _index = next;
      }
    });
  }

  void _finish() {
    ref.read(progressProvider.notifier).applyPlacement(_known);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.intro => _buildIntro(context),
      _Stage.running => _buildRung(context),
      _Stage.result => _buildResult(context),
    };
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: "Let's get to know you", tr: 'Seni tanıyalım')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.quiz_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                t(en: 'A quick placement', tr: 'Kısa bir yerleştirme'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  en:
                      "I'll play a few notes and chords and you name them "
                      "(no mic). I'll spot what you already know and start "
                      "you at the right lesson. Can't tell yet? No problem — "
                      'we begin from scratch.',
                  tr:
                      'Birkaç nota ve akoru çalacağım, sen tanıyacaksın (mikrofon yok). '
                      'Bildiklerini bulup seni doğru dersten başlatacağım. Bilemezsen '
                      'sorun değil — sıfırdan başlarız.',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _stage = _Stage.running),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(t(en: 'Start', tr: 'Başla')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  t(
                    en: 'Start from scratch (skip the test)',
                    tr: 'Sıfırdan başla (testi atla)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRung(BuildContext context) {
    final rung = _rungs[_index];
    final key = ValueKey('placement-$_index');
    if (rung.note != null) {
      return NoteRecognitionPage(
        key: key,
        pool: transposeForVoice(rung.note!.pool, _range),
        player: _player,
        questionCount: _questionsPerRung,
        onComplete: (r) => _onRungComplete(rung, r),
      );
    }
    return ChordRecognitionPage(
      key: key,
      pool: transposeChordsForVoice(rung.chord!.pool, _range),
      player: _player,
      questionCount: _questionsPerRung,
      onComplete: (r) => _onRungComplete(rung, r),
    );
  }

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final noteCount = _noteUnlocks.length;
    final chordCount = _chordUnlocks.length;
    final nothing = _known.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                nothing ? Icons.flag_rounded : Icons.auto_awesome_rounded,
                size: 84,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                nothing
                    ? t(en: 'Starting fresh', tr: 'Baştan başlıyoruz')
                    : t(en: 'Found your spot! ✨', tr: 'Yerin belli! ✨'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nothing
                    ? t(
                        en: "We'll start gently from the first lesson — no rush.",
                        tr: 'İlk dersten güzelce başlayalım — acelesi yok.',
                      )
                    : t(
                        en: "I've unlocked the parts you know — carry on from there.",
                        tr: 'Bildiğin bölümleri açtım, kaldığın yerden devam edebilirsin.',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!nothing) ...[
                const SizedBox(height: 24),
                if (noteCount > 0)
                  _statCard(
                    theme,
                    t(en: 'Note lessons unlocked', tr: 'Açılan nota dersi'),
                    '$noteCount',
                  ),
                if (chordCount > 0) ...[
                  const SizedBox(height: 10),
                  _statCard(
                    theme,
                    t(en: 'Chord lessons unlocked', tr: 'Açılan akor dersi'),
                    '$chordCount',
                  ),
                ],
              ],
              const Spacer(flex: 3),
              FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t(en: 'Continue', tr: 'Devam')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
