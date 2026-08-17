import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import '../lesson/lesson_intro_page.dart';
import '../lesson/theory_badge.dart';
import 'rhythm_echo_page.dart';
import 'rhythm_lesson.dart';

// -----------------------------------------------------------------------------
// RİTİM DERS AKIŞI — Vaat → Ritim Eko Oyunu → (Teori Rozeti) → Tamamla
//
// Melodi ve Armoni ile birebir aynı iskelet. Yeni bir akış deseni icat etmiyoruz:
// kullanıcı üç track'te de aynı ritüeli yaşar → uygulama tek bir dil konuşur.
// -----------------------------------------------------------------------------

enum _Phase { intro, playing, badge, done }

class RhythmLessonFlowPage extends ConsumerStatefulWidget {
  const RhythmLessonFlowPage({super.key, required this.lesson});

  final RhythmLesson lesson;

  @override
  ConsumerState<RhythmLessonFlowPage> createState() =>
      _RhythmLessonFlowPageState();
}

class _RhythmLessonFlowPageState extends ConsumerState<RhythmLessonFlowPage> {
  static const int _xpPerCorrect = 12;

  final NotePlayer _player = createNotePlayer();
  _Phase _phase = _Phase.intro;
  LessonResult? _result;
  int _xpEarned = 0;
  late final int _level;

  @override
  void initState() {
    super.initState();
    _level = ref.read(progressProvider).skillLevelOf(widget.lesson.id);
    // Taç tekrarında vaat ekranı atlanır (kullanıcı zaten biliyor).
    if (_level >= 1) _phase = _Phase.playing;
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
      final earned =
          widget.lesson.badge != null && result.accuracy >= kPassAccuracy;
      _phase = earned ? _Phase.badge : _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.intro:
        return LessonIntroPage(
          title: widget.lesson.title,
          promise: widget.lesson.promise,
          howItWorks: t(
            en: 'How it works: Eko taps out a rhythm — you tap it back on the '
                'big button. No notes, just timing.',
            tr: 'Nasıl oynanır: Eko bir ritim vurur — sen büyük düğmeye aynısını '
                'vurursun. Nota yok, sadece zamanlama.',
          ),
          onStart: () => setState(() => _phase = _Phase.playing),
        );
      case _Phase.playing:
        return RhythmEchoPage(
          lesson: widget.lesson,
          player: _player,
          onComplete: _onComplete,
        );
      case _Phase.badge:
        return TheoryBadgePage(
          badge: widget.lesson.badge!,
          onContinue: () => setState(() => _phase = _Phase.done),
        );
      case _Phase.done:
        return LessonCompletePage(
          result: _result!,
          xpEarned: _xpEarned,
          streak: ref.watch(progressProvider).streak,
          onDone: () => Navigator.of(context).pop(),
          onReplay: () => setState(() {
            _result = null;
            _phase = _Phase.playing;
          }),
        );
    }
  }
}
