import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../note_recognition/note_recognition_page.dart';
import 'learn_notes_page.dart';
import 'lesson.dart';
import 'lesson_complete_page.dart';
import 'lesson_intro_page.dart';
import 'sing_notes_page.dart';

// -----------------------------------------------------------------------------
// DERS AKIŞI — Duy -> Söyle -> Tanı -> Tamamla
//
// Çekirdek döngü: önce notaları öğren (duy), sonra mikrofona söyle, sonra tanı.
// Ses motoru (NotePlayer) üç aşamaya paylaştırılır. Test bitince sonuç ilerleme
// durumuna (ProgressController) işlenir: XP, günlük streak, ustalık.
// -----------------------------------------------------------------------------

enum _Phase { intro, learning, singing, testing, done }

class LessonFlowPage extends ConsumerStatefulWidget {
  const LessonFlowPage({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonFlowPage> createState() => _LessonFlowPageState();
}

class _LessonFlowPageState extends ConsumerState<LessonFlowPage> {
  static const int _questionsPerLesson = 8;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  // Vaat ekranı yalnızca dersin bir kazanım cümlesi varsa gösterilir.
  late _Phase _phase = widget.lesson.promise == null
      ? _Phase.learning
      : _Phase.intro;
  LessonResult? _result;
  int _xpEarned = 0;

  // Kullanıcının ses aralığı + bu derse özel tek oktav offset'i. Ders başında
  // bir kez hesaplanır; öğren/söyle/tanı adımlarının HEPSİ aynı transpoze
  // havuzu kullanır ("hepsi birlikte kayar"). Kalibre değilse havuz aynı kalır.
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;
  late final Lesson _lesson = Lesson(
    id: widget.lesson.id,
    title: widget.lesson.title,
    pool: transposeForVoice(widget.lesson.pool, _range),
    concept: widget.lesson.concept,
  );

  // Ustalık/taç seviyesi (0 = temel; ≥1 tekrar oynanışta zorlaşır).
  late final int _level;

  @override
  void initState() {
    super.initState();
    _level = ref.read(progressProvider).skillLevelOf(widget.lesson.id);
    // Taç tekrarında öğren/söyle atlanır → doğrudan (ipuçsuz) tanıma.
    if (_level >= 1) _phase = _Phase.testing;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onTestComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect * (1 + _level);
    final passed =
        result.accuracy >= kPassAccuracy; // "geçme" barajı -> sonrakini açar
    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: widget.lesson.id,
          xpEarned: xp,
          masteryGain: result.correct,
          accuracy: result.accuracy,
          mistakes: result.mistakes,
          completed: passed,
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
    switch (_phase) {
      case _Phase.intro:
        return LessonIntroPage(
          title: widget.lesson.title,
          promise: widget.lesson.promise!,
          onStart: () => setState(() => _phase = _Phase.learning),
        );
      case _Phase.learning:
        return LearnNotesPage(
          lesson: _lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return SingNotesPage(
          pool: _lesson.pool,
          player: _player,
          range: _range,
          onComplete: () => setState(() => _phase = _Phase.testing),
        );
      case _Phase.testing:
        return NoteRecognitionPage(
          pool: _lesson.pool,
          player: _player,
          questionCount: _questionsPerLesson + _level * 2,
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
