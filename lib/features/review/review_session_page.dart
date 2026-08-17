import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../../state/settings_controller.dart';
import '../harmony/harmony_lesson.dart';
import '../harmony/harmony_lesson_flow_page.dart';
import '../lesson/lesson.dart';
import '../melody/echo_game_page.dart';
import '../melody/melody_lesson.dart';
import '../note_recognition/note_recognition_page.dart';
import '../rhythm/rhythm_echo_page.dart';
import '../rhythm/rhythm_lesson.dart';

// -----------------------------------------------------------------------------
// TEKRAR OTURUMU — aralıklı tekrar (SM-2)
//
// Vadesi gelen becerileri SIRAYLA kısa bir tanıma testinden geçirir. Her beceri
// için doğruluk SM-2'ye işlenir (recordReviewResult) → bir sonraki tekrar tarihi
// güncellenir. Nota ve akor dersleri tek oturumda karışabilir. İçerik kullanıcının
// ses aralığına transpoze edilir (derslerdeki gibi tutarlı).
// -----------------------------------------------------------------------------

class ReviewSessionPage extends ConsumerStatefulWidget {
  const ReviewSessionPage({super.key, required this.skillIds});

  final List<String> skillIds;

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  static const int _questionsPerSkill = 5;
  static const int _xpPerCorrect = 5;

  final NotePlayer _player = createNotePlayer();
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;

  // Sadece içeriğe çözülebilen (tanıdığımız) becerileri tut.
  late final List<String> _skills = widget.skillIds.where(_isKnown).toList();

  int _index = 0;
  bool _done = false;
  int _totalCorrect = 0;
  int _totalQuestions = 0;
  int _xpEarned = 0;

  bool _isKnown(String id) =>
      _noteLessonById(id) != null ||
      _chordLessonById(id) != null ||
      _melodyLessonById(id) != null ||
      _harmonyLessonById(id) != null ||
      _rhythmLessonById(id) != null;

  Lesson? _noteLessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  ChordLesson? _chordLessonById(String id) {
    for (final l in chordLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  MelodyLesson? _melodyLessonById(String id) {
    for (final l in melodyLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  HarmonyLesson? _harmonyLessonById(String id) {
    for (final l in harmonyLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  RhythmLesson? _rhythmLessonById(String id) {
    for (final l in rhythmLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_skills.isEmpty) _done = true;
  }

  void _grade(String skillId, LessonResult result) {
    ref
        .read(progressProvider.notifier)
        .recordReviewResult(
          skillId: skillId,
          xpEarned: result.correct * _xpPerCorrect,
          accuracy: result.accuracy,
          mistakes: result.mistakes,
        );
    setState(() {
      _totalCorrect += result.correct;
      _totalQuestions += result.total;
      _xpEarned += result.correct * _xpPerCorrect;
      if (_index + 1 >= _skills.length) {
        _done = true;
      } else {
        _index++;
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildSummary(context);

    final id = _skills[_index];
    // key: her beceride tanıma ekranının State'i sıfırlansın (yeni sorular).
    final key = ValueKey('review-$_index-$id');

    final note = _noteLessonById(id);
    if (note != null) {
      return NoteRecognitionPage(
        key: key,
        pool: transposeForVoice(note.pool, _range),
        player: _player,
        questionCount: _questionsPerSkill,
        onComplete: (r) => _grade(id, r),
      );
    }
    final chord = _chordLessonById(id);
    if (chord != null) {
      return KeyedSubtree(
        key: key,
        child: buildChordGame(
          lesson: chord,
          player: _player,
          ref: ref,
          questionCount: _questionsPerSkill,
          onComplete: (r) => _grade(id, r),
        ),
      );
    }
    // Melodi dersi — Eko oyunu (tanıma değil ÜRETME). Cevap modu kullanıcının
    // Ayarlar'daki tercihinden okunur.
    final melody = _melodyLessonById(id);
    if (melody != null) {
      return EchoGamePage(
        key: key,
        lesson: melody,
        player: _player,
        range: _range,
        questionCount: _questionsPerSkill,
        mode: ref.watch(settingsProvider).echoInputMode,
        onModeChanged: (mode) =>
            ref.read(settingsProvider.notifier).setEchoInputMode(mode),
        onComplete: (r) => _grade(id, r),
      );
    }
    // Ritim dersi — dokunarak tekrar (perde yok).
    final rhythm = _rhythmLessonById(id);
    if (rhythm != null) {
      return RhythmEchoPage(
        key: key,
        lesson: rhythm,
        player: _player,
        questionCount: _questionsPerSkill,
        onComplete: (r) => _grade(id, r),
      );
    }
    // Armoni dersi — soru tipine göre üç oyun ekranından biri. (_isKnown
    // süzgecinden geçtiği için buraya gelen id mutlaka bir armoni dersidir.)
    return KeyedSubtree(
      key: key,
      child: buildHarmonyGame(
        lesson: _harmonyLessonById(id)!,
        player: _player,
        ref: ref,
        questionCount: _questionsPerSkill,
        onComplete: (r) => _grade(id, r),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalQuestions == 0 ? 1 : _totalQuestions;
    final pct = (_totalCorrect / total * 100).round();
    final nothing = _skills.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                nothing
                    ? Icons.check_circle_outline_rounded
                    : Icons.replay_rounded,
                size: 88,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                nothing
                    ? t(en: 'No reviews', tr: 'Tekrar yok')
                    : t(en: 'Reviews done! 🔁', tr: 'Tekrar tamam! 🔁'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nothing
                    ? t(
                        en: 'Nothing to review right now.',
                        tr: 'Şimdilik tekrar edilecek bir şey yok.',
                      )
                    : t(
                        en: '$_totalCorrect / $_totalQuestions correct · $pct%',
                        tr: '$_totalCorrect / $_totalQuestions doğru · %$pct',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!nothing) ...[
                const SizedBox(height: 24),
                _statCard(
                  theme,
                  t(en: 'Skills reviewed', tr: 'Tekrar edilen beceri'),
                  '${_skills.length}',
                ),
                const SizedBox(height: 10),
                _statCard(
                  theme,
                  t(en: 'XP earned', tr: 'Kazanılan XP'),
                  '+$_xpEarned',
                ),
              ],
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t(en: 'Finish', tr: 'Bitir')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
