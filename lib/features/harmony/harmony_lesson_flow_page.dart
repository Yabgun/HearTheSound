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
import 'harmony_choice_page.dart';
import 'harmony_find_page.dart';
import 'harmony_lesson.dart';
import 'harmony_pattern_page.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ DERS AKIŞI — Vaat → Oyun → (Teori Rozeti) → Tamamla
//
// Melodi Kulağı'yla birebir aynı iskelet: uzun kavram kartı yok, ders "bu
// dersten sonra şunu yapabileceksin" ile açılır, teori en sonda YAŞANDIKTAN
// sonra rozet olur. Tek fark, soru tipine göre üç oyun ekranından birinin
// açılması.
// -----------------------------------------------------------------------------

enum _Phase { intro, playing, badge, done }

class HarmonyLessonFlowPage extends ConsumerStatefulWidget {
  const HarmonyLessonFlowPage({super.key, required this.lesson});

  final HarmonyLesson lesson;

  @override
  ConsumerState<HarmonyLessonFlowPage> createState() =>
      _HarmonyLessonFlowPageState();
}

class _HarmonyLessonFlowPageState
    extends ConsumerState<HarmonyLessonFlowPage> {
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
      // Rozet yalnızca ders GEÇİLDİYSE açılır: kavramı gerçekten yaşamadan
      // adını vermek, kaldırdığımız eski hatanın ta kendisi olurdu.
      final earned =
          widget.lesson.badge != null && result.accuracy >= kPassAccuracy;
      _phase = earned ? _Phase.badge : _Phase.done;
    });
  }

  /// Dersin mekaniğine göre oyun ekranı.
  Widget _gamePage() => buildHarmonyGame(
    lesson: widget.lesson,
    player: _player,
    ref: ref,
    onComplete: _onComplete,
  );

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
        return _gamePage();
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

  /// Tek satırlık "nasıl oynanır" — jargonsuz, oyunun tamamını anlatır.
  String _howItWorks() => switch (widget.lesson.drill) {
    HarmonyDrill.howMany ||
    HarmonyDrill.changed ||
    HarmonyDrill.bassDirection => t(
      en: 'How it works: Eko plays something — you say what you heard. '
          'Two buttons, no words to learn.',
      tr: 'Nasıl oynanır: Eko bir şey çalar — sen ne duyduğunu söylersin. '
          'İki düğme, ezberlenecek kelime yok.',
    ),
    HarmonyDrill.findBass => t(
      en: 'How it works: Eko plays a chord — you find its lowest note, on the '
          'keys or with your voice. Tap around until it matches.',
      tr: 'Nasıl oynanır: Eko bir akor çalar — sen onun en pes sesini '
          'bulursun, tuşlarda ya da sesinle. Tutana kadar deneyebilirsin.',
    ),
    HarmonyDrill.bassLine => t(
      en: 'How it works: Eko plays a few chords — you find the lowest note of '
          'each one, in order. Undo as often as you like.',
      tr: 'Nasıl oynanır: Eko birkaç akor çalar — sen her birinin en pes '
          'sesini sırayla bulursun. İstediğin kadar geri alabilirsin.',
    ),
    HarmonyDrill.pattern => t(
      en: 'How it works: Eko plays a pattern — you lay the chords out in the '
          'order you heard them. Tap a chord to hear it before you place it.',
      tr: 'Nasıl oynanır: Eko bir kalıp çalar — sen akorları duyduğun sırayla '
          'dizersin. Yerleştirmeden önce taşa basıp dinleyebilirsin.',
    ),
  };
}

/// Bir armoni dersinin oyun ekranını kurar.
///
/// Akış sayfası, Sonsuz Pratik ve tekrar oturumu AYNI fabrikayı kullanır →
/// davranış (soru tipi, cevap modu, puanlama) her yerde birebir aynı kalır.
Widget buildHarmonyGame({
  required HarmonyLesson lesson,
  required NotePlayer player,
  required WidgetRef ref,
  required void Function(LessonResult result) onComplete,
  int? questionCount,
}) => switch (lesson.drill) {
  HarmonyDrill.howMany ||
  HarmonyDrill.changed ||
  HarmonyDrill.bassDirection => HarmonyChoicePage(
    lesson: lesson,
    player: player,
    questionCount: questionCount,
    onComplete: onComplete,
  ),
  // Bas bulma ekranları cevap modunu (tuş/söyle) Ayarlar'dan okur — Eko
  // Oyunu'yla ortak tercih, kullanıcıya iki kez sorulmaz.
  HarmonyDrill.findBass || HarmonyDrill.bassLine => HarmonyFindPage(
    lesson: lesson,
    player: player,
    questionCount: questionCount,
    mode: ref.watch(settingsProvider).echoInputMode,
    onModeChanged: (mode) =>
        ref.read(settingsProvider.notifier).setEchoInputMode(mode),
    onComplete: onComplete,
  ),
  HarmonyDrill.pattern => HarmonyPatternPage(
    lesson: lesson,
    player: player,
    questionCount: questionCount,
    onComplete: onComplete,
  ),
};
