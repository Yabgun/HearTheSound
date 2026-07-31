import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import '../lesson/lesson_intro_page.dart';
import 'interval_build_page.dart';
import 'interval_direction_page.dart';
import 'interval_learn_page.dart';
import 'interval_lesson.dart';
import 'interval_melody_page.dart';
import 'interval_recognition_page.dart';
import 'interval_sing_page.dart';

// -----------------------------------------------------------------------------
// ARALIK DERS AKIŞI — Öğren → Kur → Yön → Uygula → Söyle → Tanı → Tamamla
//
// Nota/akor akışlarının aralık karşılığı. Aralık göreceli olduğundan havuz
// transpoze EDİLMEZ; kök seçimini alt ekranlar yapar (söylemede kullanıcının
// aralığına, tanımada rastgele). Sonuç ilerlemeye işlenir (XP/streak/ustalık/
// tekrar zamanlama).
//
// HARMONİK dersler (lesson.harmonic): iki nota aynı anda çalınır ve akış
// kısalır — Öğren → Kur → Tanı. Yön/melodi/söyleme melodik kavramlardır;
// aynı anda tınlayan iki notada yön yoktur ve iki nota birden söylenemez.
// -----------------------------------------------------------------------------

enum _Phase {
  intro,
  learning,
  building,
  direction,
  applying,
  singing,
  recognizing,
  done,
}

class IntervalLessonFlowPage extends ConsumerStatefulWidget {
  const IntervalLessonFlowPage({super.key, required this.lesson});

  final IntervalLesson lesson;

  @override
  ConsumerState<IntervalLessonFlowPage> createState() =>
      _IntervalLessonFlowPageState();
}

class _IntervalLessonFlowPageState
    extends ConsumerState<IntervalLessonFlowPage> {
  static const int _questionCount = 8;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  // Vaat ekranı yalnızca dersin bir kazanım cümlesi varsa gösterilir.
  late _Phase _phase = widget.lesson.promise == null
      ? _Phase.learning
      : _Phase.intro;
  LessonResult? _result;
  int _xpEarned = 0;

  // Ustalık/taç seviyesi (0 = temel; ≥1 tekrar oynanışta zorlaşır).
  late final int _level;

  @override
  void initState() {
    super.initState();
    _level = ref.read(progressProvider).skillLevelOf(widget.lesson.id);
    // Taç tekrarında kur/yön/uygula/söyle atlanır → doğrudan (ipuçsuz) tanıma.
    if (_level >= 1) _phase = _Phase.recognizing;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect * (1 + _level);
    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: widget.lesson.id,
          xpEarned: xp,
          masteryGain: result.correct,
          accuracy: result.accuracy,
          mistakes: result.mistakes,
          completed: result.accuracy >= kPassAccuracy,
          reachedLevel: _level + 1,
        );
    setState(() {
      _result = result;
      _xpEarned = xp;
      _phase = _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final harmonic = widget.lesson.harmonic;
    switch (_phase) {
      case _Phase.intro:
        return LessonIntroPage(
          title: widget.lesson.title,
          promise: widget.lesson.promise!,
          onStart: () => setState(() => _phase = _Phase.learning),
        );
      case _Phase.learning:
        return IntervalLearnPage(
          lesson: widget.lesson,
          player: _player,
          harmonic: harmonic,
          onReady: () => setState(() => _phase = _Phase.building),
        );
      case _Phase.building:
        return IntervalBuildPage(
          pool: widget.lesson.pool,
          player: _player,
          harmonic: harmonic,
          // Harmonik derste yön/melodi/söyleme atlanır → doğrudan tanıma.
          onComplete: () => setState(
            () => _phase = harmonic ? _Phase.recognizing : _Phase.direction,
          ),
        );
      case _Phase.direction:
        return IntervalDirectionPage(
          pool: widget.lesson.pool,
          player: _player,
          onComplete: () => setState(() => _phase = _Phase.applying),
        );
      case _Phase.applying:
        return IntervalMelodyPage(
          pool: widget.lesson.pool,
          player: _player,
          onComplete: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return IntervalSingPage(
          pool: widget.lesson.pool,
          player: _player,
          range: ref.read(progressProvider).vocalRange,
          onComplete: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        return IntervalRecognitionPage(
          pool: widget.lesson.pool,
          player: _player,
          harmonic: harmonic,
          questionCount: _questionCount + _level * 2,
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
