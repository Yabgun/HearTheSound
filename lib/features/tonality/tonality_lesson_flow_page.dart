import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import 'tonality_learn_page.dart';
import 'tonality_lesson.dart';
import 'tonality_recognition_page.dart';
import 'tonality_sing_page.dart';

// -----------------------------------------------------------------------------
// TONALİTE DERS AKIŞI — Öğren → Söyle → Tanı → Tamamla
//
// Tonik bağlamı önce öğretilir; sonra kullanıcı hedef dereceyi sesiyle üretir ve
// en sonda ipuçsuz tanır.
// -----------------------------------------------------------------------------

enum _Phase { learning, singing, recognizing, done }

class TonalityLessonFlowPage extends ConsumerStatefulWidget {
  const TonalityLessonFlowPage({super.key, required this.lesson});

  final TonalityLesson lesson;

  @override
  ConsumerState<TonalityLessonFlowPage> createState() =>
      _TonalityLessonFlowPageState();
}

class _TonalityLessonFlowPageState
    extends ConsumerState<TonalityLessonFlowPage> {
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
        return TonalityLearnPage(
          lesson: widget.lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return TonalitySingPage(
          pool: widget.lesson.pool,
          player: _player,
          range: ref.read(progressProvider).vocalRange,
          onComplete: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        return TonalityRecognitionPage(
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
