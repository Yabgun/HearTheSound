import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import 'chord_arpeggio_page.dart';
import 'chord_inversion_recognition_page.dart';
import 'chord_lesson.dart';
import 'chord_quality_recognition_page.dart';
import 'chord_recognition_page.dart';
import 'learn_chords_page.dart';

// -----------------------------------------------------------------------------
// AKOR DERS AKIŞI — Öğren → Söyle (arpej) → Tanı ("hangi akor?")
//
// Nota derslerinin akor karşılığı. Tanıma bitince sonuç ilerlemeye işlenir
// (XP, streak, ustalık, ders tamamlama → kilit açar).
// -----------------------------------------------------------------------------

enum _Phase { learning, singing, recognizing, done }

class ChordLessonFlowPage extends ConsumerStatefulWidget {
  const ChordLessonFlowPage({super.key, required this.lesson});

  final ChordLesson lesson;

  @override
  ConsumerState<ChordLessonFlowPage> createState() =>
      _ChordLessonFlowPageState();
}

class _ChordLessonFlowPageState extends ConsumerState<ChordLessonFlowPage> {
  static const int _questionCount = 8;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  _Phase _phase = _Phase.learning;
  LessonResult? _result;
  int _xpEarned = 0;

  // Kullanıcının ses aralığı + bu derse özel tek oktav offset'i. Akorlar ders
  // başında bir kez blok halinde transpoze edilir; öğren/söyle/tanı adımlarının
  // HEPSİ aynı transpoze havuzu kullanır. Kalibre değilse akorlar aynı kalır.
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;
  late final ChordLesson _lesson = ChordLesson(
    id: widget.lesson.id,
    title: widget.lesson.title,
    pool: transposeChordsForVoice(widget.lesson.pool, _range),
    recognizeBy: widget.lesson.recognizeBy, // transpoze ederken kaybolmasın
    concept: widget.lesson.concept,
  );

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onRecognitionComplete(LessonResult result) {
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
        return LearnChordsPage(
          lesson: _lesson,
          player: _player,
          onReady: () => setState(() => _phase = _Phase.singing),
        );
      case _Phase.singing:
        return ChordArpeggioPage(
          // Söyle aşamasında en çok 2 akoru arpej yap (kısa tut).
          chords: _lesson.pool.take(2).toList(),
          player: _player,
          range: _range,
          onComplete: () => setState(() => _phase = _Phase.recognizing),
        );
      case _Phase.recognizing:
        // Tanıma tipi derse göre: nitelik / çevrim / spesifik akor.
        return switch (_lesson.recognizeBy) {
          ChordRecognizeBy.quality => ChordQualityRecognitionPage(
            pool: _lesson.pool,
            player: _player,
            questionCount: _questionCount,
            onComplete: _onRecognitionComplete,
          ),
          ChordRecognizeBy.inversion => ChordInversionRecognitionPage(
            pool: _lesson.pool,
            player: _player,
            questionCount: _questionCount,
            onComplete: _onRecognitionComplete,
          ),
          ChordRecognizeBy.chord => ChordRecognitionPage(
            pool: _lesson.pool,
            player: _player,
            questionCount: _questionCount,
            onComplete: _onRecognitionComplete,
          ),
        };
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
