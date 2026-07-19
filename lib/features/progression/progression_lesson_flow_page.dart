import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../chords/chord_arpeggio_page.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import 'progression_build_page.dart';
import 'progression_learn_page.dart';
import 'progression_lesson.dart';
import 'progression_recognition_page.dart';

// -----------------------------------------------------------------------------
// İLERLEME DERS AKIŞI — Öğren → Kur → Tanı → Tamamla
//
// İşlev gibi analitik dinleme becerisi (söyleme adımı yok). Sonuç ilerlemeye
// işlenir (XP/streak/ustalık/tekrar).
// -----------------------------------------------------------------------------

enum _Phase { learning, building, arpeggiating, recognizing, done }

class ProgressionLessonFlowPage extends ConsumerStatefulWidget {
  const ProgressionLessonFlowPage({super.key, required this.lesson});

  final ProgressionLesson lesson;

  @override
  ConsumerState<ProgressionLessonFlowPage> createState() =>
      _ProgressionLessonFlowPageState();
}

class _ProgressionLessonFlowPageState
    extends ConsumerState<ProgressionLessonFlowPage> {
  static const int _questionCount = 8;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  _Phase _phase = _Phase.learning;
  LessonResult? _result;
  int _xpEarned = 0;

  // Akor zinciri, söyleme eklenince de ders boyunca tek oktavda kalır.
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;
  late final ProgressionLesson _keyLesson = widget.lesson.inKey(
    widget.lesson.key,
  );
  late final ProgressionLesson _lesson = ProgressionLesson(
    id: _keyLesson.id,
    title: _keyLesson.title,
    pool: transposeProgressionsForVoice(_keyLesson.pool, _range),
    key: _keyLesson.key,
    concept: _keyLesson.concept,
  );

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect;
    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: widget.lesson.id,
          xpEarned: xp,
          masteryGain: result.correct,
          accuracy: result.accuracy,
          mistakes: result.mistakes,
          completed: result.accuracy >= 0.7,
        );
    setState(() {
      _result = result;
      _xpEarned = xp;
      _phase = _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.learning:
        return ProgressionLearnPage(
          lesson: _lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.building),
        );
      case _Phase.building:
        return ProgressionBuildPage(
          pool: _lesson.pool,
          player: _player,
          majorKey: _lesson.key,
          onComplete: () => setState(() => _phase = _Phase.arpeggiating),
        );
      case _Phase.arpeggiating:
        return ChordArpeggioPage(
          // İlk iki akor, ilerlemenin hareketini sesle kurmak için yeterince
          // kısa ama anlamlı bir turdur; uzun ilerlemelerde kullanıcıyı yormaz.
          chords: _lesson.pool.first.chords.take(2).toList(),
          player: _player,
          range: _range,
          title: t(en: 'Arpeggiate the Progression', tr: 'İlerlemeyi Arpejle'),
          instruction: t(
            en:
                'Build the chords of the progression in order: start each '
                'one from its root.',
            tr:
                'İlerleme içindeki akorları sırayla kur: her birini kökünden '
                'başlat.',
          ),
          onComplete: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        return ProgressionRecognitionPage(
          pool: _lesson.pool,
          player: _player,
          questionCount: _questionCount,
          majorKey: _lesson.key,
          onComplete: _onComplete,
        );
      case _Phase.done:
        return LessonCompletePage(
          result: _result!,
          xpEarned: _xpEarned,
          streak: ref.watch(progressProvider).streak,
          onDone: () => Navigator.of(context).pop(),
          onReplay: () => setState(() {
            _result = null;
            _phase = _Phase.recognizing;
          }),
        );
    }
  }
}
