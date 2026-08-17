import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import '../lesson/lesson_intro_page.dart';
import '../lesson/theory_badge.dart';
import 'chord_color_page.dart';
import 'chord_lesson.dart';
import 'chord_produce_page.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKOR DERS AKIŞI — Vaat → Oyun → (Teori Rozeti) → Tamamla
//
// Eski akış "vaat → uzun kavram kartı → arpej söyleme → çoktan seçmeli tanıma"
// idi. Uygulamadaki diğer üç yetenek track'i (Melodi, Armoni, Ritim) bu iskeleti
// çoktan bıraktı ve kullanıcı onları onayladı; Akorlar da aynı ritüele geçti:
// uzun kavram kartı YOK, teori en sonda rozet.
// -----------------------------------------------------------------------------

enum _Phase { intro, playing, badge, done }

class ChordLessonFlowPage extends ConsumerStatefulWidget {
  const ChordLessonFlowPage({super.key, required this.lesson});

  final ChordLesson lesson;

  @override
  ConsumerState<ChordLessonFlowPage> createState() =>
      _ChordLessonFlowPageState();
}

class _ChordLessonFlowPageState extends ConsumerState<ChordLessonFlowPage> {
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
          howItWorks: _howItWorks(),
          onStart: () => setState(() => _phase = _Phase.playing),
        );
      case _Phase.playing:
        return buildChordGame(
          lesson: widget.lesson,
          player: _player,
          ref: ref,
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

  String _howItWorks() {
    if (widget.lesson.drill == ChordDrill.match) {
      return t(
        en: 'How it works: Eko plays a chord, then you play both options and '
            'pick the one that sounds the same. Nothing to memorise.',
        tr: 'Nasıl oynanır: Eko bir akor çalar; sen iki şıkkı da çalıp aynı '
            'gelen sesi seçersin. Ezberlenecek bir şey yok.',
      );
    }
    if (!widget.lesson.isProduction) {
      return t(
        en: 'How it works: Eko plays a chord — you say how it felt. No terms '
            'to learn first.',
        tr: 'Nasıl oynanır: Eko bir akor çalar — sen nasıl geldiğini '
            'söylersin. Önceden öğrenilecek terim yok.',
      );
    }
    if (widget.lesson.colorIsHeard) {
      return t(
        en: 'How it works: Eko plays a chord — you work out its colour and '
            'play the same chord back, note by note. Get it right and it rings '
            'out as one chord.',
        tr: 'Nasıl oynanır: Eko bir akor çalar — sen rengini bulup aynısını ses '
            'ses çalarsın. Doğru kurunca akor bir bütün olarak çalar.',
      );
    }
    return t(
      en: 'How it works: the recipe is on screen and the next key is marked. '
          'Count up from the root and the chord appears under your fingers.',
      tr: 'Nasıl oynanır: tarif ekranda, sıradaki tuş işaretli. Kökten sayarak '
          'ilerle, akor parmaklarının altında oluşsun.',
    );
  }
}

/// Bir akor dersinin oyun ekranını kurar.
///
/// Akış sayfası, Sonsuz Pratik ve tekrar oturumu AYNI fabrikayı kullanır →
/// davranış her yerde birebir aynı kalır.
Widget buildChordGame({
  required ChordLesson lesson,
  required NotePlayer player,
  required WidgetRef ref,
  required void Function(LessonResult result) onComplete,
  int? questionCount,
}) {
  if (!lesson.isProduction) {
    return ChordColorPage(
      lesson: lesson,
      player: player,
      questionCount: questionCount,
      onComplete: onComplete,
    );
  }
  // Üretim ekranı cevap modunu (tuş/söyle) Ayarlar'dan okur — Eko Oyunu ve
  // Armoni ile ORTAK tercih, kullanıcıya her track'te yeniden sorulmaz.
  return ChordProducePage(
    lesson: lesson,
    player: player,
    range: ref.watch(progressProvider).vocalRange,
    questionCount: questionCount,
    mode: ref.watch(settingsProvider).echoInputMode,
    onModeChanged: (mode) =>
        ref.read(settingsProvider.notifier).setEchoInputMode(mode),
    onComplete: onComplete,
  );
}
