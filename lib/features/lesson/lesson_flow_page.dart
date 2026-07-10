import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../state/progress_controller.dart';
import '../note_recognition/note_recognition_page.dart';
import 'learn_notes_page.dart';
import 'lesson.dart';
import 'lesson_complete_page.dart';
import 'sing_notes_page.dart';

// -----------------------------------------------------------------------------
// DERS AKIŞI — Duy -> Söyle -> Tanı -> Tamamla
//
// Çekirdek döngü: önce notaları öğren (duy), sonra mikrofona söyle, sonra tanı.
// Ses motoru (NotePlayer) üç aşamaya paylaştırılır. Test bitince sonuç ilerleme
// durumuna (ProgressController) işlenir: XP, günlük streak, ustalık.
// -----------------------------------------------------------------------------

enum _Phase { learning, singing, testing, done }

class LessonFlowPage extends ConsumerStatefulWidget {
  const LessonFlowPage({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonFlowPage> createState() => _LessonFlowPageState();
}

class _LessonFlowPageState extends ConsumerState<LessonFlowPage> {
  static const int _questionsPerLesson = 8;
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

  void _onTestComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect;
    final passed = result.accuracy >= 0.7; // dersi "geçme" barajı -> sonrakini açar
    ref.read(progressProvider.notifier).completeLesson(
          skillId: widget.lesson.id,
          xpEarned: xp,
          masteryGain: result.correct,
          completed: passed,
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
        return LearnNotesPage(
          lesson: widget.lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return SingNotesPage(
          pool: widget.lesson.pool,
          player: _player,
          onComplete: () => setState(() => _phase = _Phase.testing),
        );
      case _Phase.testing:
        return NoteRecognitionPage(
          pool: widget.lesson.pool,
          player: _player,
          questionCount: _questionsPerLesson,
          onComplete: _onTestComplete,
          onRelearn: () => setState(() => _phase = _Phase.learning),
        );
      case _Phase.done:
        final streak = ref.watch(progressProvider).streak;
        return LessonCompletePage(
          result: _result!,
          xpEarned: _xpEarned,
          streak: streak,
          onDone: () => Navigator.of(context).pop(),
          onReplay: () => setState(() {
            _result = null;
            _phase = _Phase.testing;
          }),
        );
    }
  }
}
