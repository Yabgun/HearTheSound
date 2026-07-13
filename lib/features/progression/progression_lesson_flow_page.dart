import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import 'progression_learn_page.dart';
import 'progression_lesson.dart';
import 'progression_recognition_page.dart';

// -----------------------------------------------------------------------------
// İLERLEME DERS AKIŞI — Öğren → Tanı → Tamamla
//
// İşlev gibi analitik dinleme becerisi (söyleme adımı yok). Sonuç ilerlemeye
// işlenir (XP/streak/ustalık/tekrar).
// -----------------------------------------------------------------------------

enum _Phase { learning, recognizing, done }

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

  final NotePlayer _player = SynthNotePlayer();
  _Phase _phase = _Phase.learning;
  LessonResult? _result;
  int _xpEarned = 0;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect;
    ref.read(progressProvider.notifier).completeLesson(
          skillId: widget.lesson.id,
          xpEarned: xp,
          masteryGain: result.correct,
          accuracy: result.accuracy,
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
          lesson: widget.lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        return ProgressionRecognitionPage(
          pool: widget.lesson.pool,
          player: _player,
          questionCount: _questionCount,
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
