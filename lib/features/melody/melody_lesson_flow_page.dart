import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_theme.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_complete_page.dart';
import '../lesson/lesson_intro_page.dart';
import '../mascot/player_eko.dart';
import 'echo_game_page.dart';
import 'melody_lesson.dart';

// -----------------------------------------------------------------------------
// MELODİ DERS AKIŞI — Vaat → Eko Oyunu → (Teori Rozeti) → Tamamla
//
// Uzun kavram kartı YOK. Ders şununla açılır: "bu dersten sonra şunu
// yapabileceksin". Teori en sonda, YAŞANDIKTAN sonra rozet olarak verilir —
// kullanıcı kavramı zaten duymuştur, biz yalnızca adını koyarız.
// -----------------------------------------------------------------------------

enum _Phase { intro, playing, badge, done }

class MelodyLessonFlowPage extends ConsumerStatefulWidget {
  const MelodyLessonFlowPage({super.key, required this.lesson});

  final MelodyLesson lesson;

  @override
  ConsumerState<MelodyLessonFlowPage> createState() =>
      _MelodyLessonFlowPageState();
}

class _MelodyLessonFlowPageState extends ConsumerState<MelodyLessonFlowPage> {
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

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.intro:
        return LessonIntroPage(
          title: widget.lesson.title,
          promise: widget.lesson.promise,
          howItWorks: t(
            en: 'How it works: Eko plays a short tune — you repeat it. '
                'That is the whole game.',
            tr: 'Nasıl oynanır: Eko kısa bir ezgi çalar — sen tekrarlarsın. '
                'Oyunun tamamı bu.',
          ),
          onStart: () => setState(() => _phase = _Phase.playing),
        );
      case _Phase.playing:
        return EchoGamePage(
          lesson: widget.lesson,
          player: _player,
          range: ref.read(progressProvider).vocalRange,
          mode: ref.watch(settingsProvider).echoInputMode,
          onModeChanged: (mode) =>
              ref.read(settingsProvider.notifier).setEchoInputMode(mode),
          onComplete: _onComplete,
        );
      case _Phase.badge:
        return _badgePage(context);
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

  /// Teori rozeti — yaşanmış sezgiye ad koyar. ("Önce yaşat, sonra adını koy.")
  Widget _badgePage(BuildContext context) {
    final theme = Theme.of(context);
    final badge = widget.lesson.badge!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: PlayerEko(size: 96, celebrate: true)),
              const SizedBox(height: 20),
              Text(
                t(en: 'You just earned a word', tr: 'Bir kelime kazandın'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.term,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.grape,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge.insight,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => setState(() => _phase = _Phase.done),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t(en: 'Got it', tr: 'Anladım')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
