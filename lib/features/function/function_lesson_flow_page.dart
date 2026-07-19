import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import 'function_build_page.dart';
import 'function_learn_page.dart';
import 'function_lesson.dart';
import 'function_recognition_page.dart';
import 'function_root_sing_page.dart';

// -----------------------------------------------------------------------------
// AKOR İŞLEVİ DERS AKIŞI — Öğren → Kur → Tanı → Tamamla
//
// İşlev analitik bir dinleme becerisi (üretim/söyleme adımı yok). Sonuç
// ilerlemeye işlenir (XP/streak/ustalık/tekrar).
// -----------------------------------------------------------------------------

enum _Phase { learning, building, singing, recognizing, done }

class FunctionLessonFlowPage extends ConsumerStatefulWidget {
  const FunctionLessonFlowPage({super.key, required this.lesson});

  final FunctionLesson lesson;

  @override
  ConsumerState<FunctionLessonFlowPage> createState() =>
      _FunctionLessonFlowPageState();
}

class _FunctionLessonFlowPageState
    extends ConsumerState<FunctionLessonFlowPage> {
  static const int _questionCount = 8;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  _Phase _phase = _Phase.learning;
  LessonResult? _result;
  int _xpEarned = 0;

  // Kök söyleme de diğer safhalarla aynı blok oktavı kullanır.
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;
  late final FunctionLesson _keyLesson = widget.lesson.inKey(widget.lesson.key);
  late final FunctionLesson _lesson = FunctionLesson(
    id: _keyLesson.id,
    title: _keyLesson.title,
    pool: transposeDegreesForVoice(_keyLesson.pool, _range),
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
        return FunctionLearnPage(
          lesson: _lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.building),
        );
      case _Phase.building:
        return FunctionBuildPage(
          pool: _lesson.pool,
          player: _player,
          majorKey: _lesson.key,
          onComplete: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return FunctionRootSingPage(
          pool: _lesson.pool,
          player: _player,
          range: _range,
          onComplete: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        return FunctionRecognitionPage(
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
