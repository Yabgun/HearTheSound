import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/daily_challenge.dart';
import '../../core/spaced_repetition.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_theme.dart';
import '../concept/concept_sheet.dart';
import '../lesson/lesson.dart';
import '../mascot/eko_mascot.dart';
import 'endless_drill_page.dart';

// -----------------------------------------------------------------------------
// GÜNÜN MEYDAN OKUMASI — deterministik, kısa, karışık günlük set
//
// Sonsuz Pratik'in "her gün açılacak bir şey" kardeşi: bugüne SABİT (tarihten
// türetilen) birkaç beceriden kısa bir tanıma turu. Bitince "bugün tamam" olarak
// işaretlenir (Bugün ekranında rozet) → günlük dönüş alışkanlığını tetikler.
//
// Beceri adaptörü ve tanıma sayfaları Sonsuz Pratik ile ORTAK (buildDrillSkills);
// buradaki fark: seçim ağırlıklı değil deterministik, ve oturum SONLU.
// -----------------------------------------------------------------------------

/// Sonsuz Pratik ile aynı içerik tipi kuralı — kavram kartı.
Concept _challengeConcept() => Concept(
  title: t(en: 'Daily Challenge', tr: 'Günün Meydan Okuması'),
  sections: [
    ConceptSection(
      t(
        en:
            'A short, mixed set drawn from everything you have learned. It is '
            'fixed for the day — the same challenge each time you open it today.',
        tr:
            'Öğrendiğin her şeyden çekilen kısa, karışık bir set. Gün boyu '
            'sabittir — bugün her açtığında aynı meydan okuma gelir.',
      ),
    ),
    ConceptSection(
      heading: t(en: 'Why', tr: 'Neden'),
      t(
        en:
            'A tiny daily ritual is the habit that keeps your streak — and your '
            'ear — alive. Come back tomorrow for a fresh one.',
        tr:
            'Küçük bir günlük ritüel, serini — ve kulağını — canlı tutan '
            'alışkanlıktır. Yarın yenisi için tekrar gel.',
      ),
    ),
  ],
);

enum _Phase { intro, drilling, done }

class DailyChallengePage extends ConsumerStatefulWidget {
  const DailyChallengePage({super.key});

  @override
  ConsumerState<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends ConsumerState<DailyChallengePage> {
  // Kısa ve karışık: birkaç farklı beceri, her biri birkaç soru.
  static const int _segments = 3;
  static const int _segmentSize = 3;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();

  late final List<DrillSkill> _skills;
  late final List<int> _plan; // beceri indeksleri (deterministik, gün-tohumlu)

  _Phase _phase = _Phase.intro;
  int _i = 0; // plan içindeki mevcut segment
  int _answered = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    final p = ref.read(progressProvider);
    _skills = buildDrillSkills(p, p.vocalRange);
    // Gün tohumu UI'da (saf mantık DateTime.now() bilmez); gün içinde sabit.
    final seed = daySeedFor(DateTime.now());
    _plan = dailyChallengeSkillIndices(
      _skills.length,
      seed,
      segments: _segments,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  int get _totalQuestions => _plan.length * _segmentSize;

  void _onSegmentComplete(LessonResult result) {
    final skill = _skills[_plan[_i]];
    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: skill.id,
          xpEarned: result.correct * _xpPerCorrect,
          masteryGain: result.correct,
          accuracy: result.accuracy,
          completed: false, // meydan okuma yeni ders açmaz
          mistakes: result.mistakes,
        );
    _answered += result.total;
    _correct += result.correct;
    if (_i + 1 >= _plan.length) {
      // Son segment: bugünü tamamlandı işaretle, sonuç ekranına geç.
      ref.read(progressProvider.notifier).completeDailyChallenge();
      setState(() => _phase = _Phase.done);
    } else {
      setState(() => _i += 1); // faz drilling kalır → sıradaki segment kurulur
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_skills.isEmpty || _plan.isEmpty) return _buildEmpty(context);
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro(context);
      case _Phase.drilling:
        // Her segment BENZERSİZ key ile: ardışık segment aynı beceri/tanıma
        // sayfası tipinde olsa bile Flutter State'i yeniden KULLANMASIN → segment
        // sıfırdan başlasın (yoksa 2. segment 1.'nin "bitti" halinde takılır ve
        // meydan okuma erken "tamamlandı" görünürdü).
        return KeyedSubtree(
          key: ValueKey(_i),
          child: _skills[_plan[_i]].build(
            _player,
            _segmentSize,
            _onSegmentComplete,
          ),
        );
      case _Phase.done:
        return _buildDone(context);
    }
  }

  // ---- Giriş ----------------------------------------------------------------

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    // Bugün zaten tamamlanmış mı? (tekrar açıldıysa nazik bir not — yine de oynanır)
    final doneToday = ref
        .watch(progressProvider)
        .isChallengeDoneOn(dayKeyFor(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Daily Challenge', tr: 'Günün Meydan Okuması')),
        actions: [
          IconButton(
            tooltip: t(en: 'What is this?', tr: 'Bu nedir?'),
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showConceptSheet(context, _challengeConcept()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              EkoMascot(size: 104, celebrate: doneToday),
              const SizedBox(height: 20),
              Text(
                doneToday
                    ? t(en: "Today's is done ✓", tr: 'Bugünkü tamam ✓')
                    : t(en: "Today's Challenge", tr: 'Günün Meydan Okuması'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                doneToday
                    ? t(
                        en:
                            'You already cleared it today. Feel free to run it '
                            'again — a fresh set arrives tomorrow.',
                        tr:
                            'Bugünküyü bitirdin bile. İstersen tekrar oyna — '
                            'yarın yeni bir set gelir.',
                      )
                    : t(
                        en:
                            '$_totalQuestions mixed questions from what you have '
                            'learned. Same set all day — how sharp is your ear?',
                        tr:
                            'Öğrendiklerinden $_totalQuestions karışık soru. Gün '
                            'boyu aynı set — kulağın ne kadar keskin?',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ConceptCardButton(concept: _challengeConcept()),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _phase = _Phase.drilling),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    doneToday
                        ? t(en: 'Play again', tr: 'Tekrar oyna')
                        : t(en: 'Start challenge', tr: 'Meydan okumaya başla'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(en: 'Maybe later', tr: 'Belki sonra')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Sonuç ----------------------------------------------------------------

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final allRight = _correct == _answered;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Daily Challenge', tr: 'Günün Meydan Okuması')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const EkoMascot(size: 120, celebrate: true),
              const SizedBox(height: 20),
              Text(
                t(en: 'Challenge complete!', tr: 'Meydan okuma tamam!'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t(
                    en: '$_correct / $_answered correct',
                    tr: '$_answered soruda $_correct doğru',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                allRight
                    ? t(
                        en: 'Flawless — come back tomorrow for a fresh one!',
                        tr: 'Kusursuz — yarın yenisi için tekrar gel!',
                      )
                    : t(
                        en: 'Nice work. A new challenge arrives tomorrow.',
                        tr: 'Güzel iş. Yarın yeni bir meydan okuma gelir.',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(t(en: 'Done', tr: 'Bitti')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Boş durum ------------------------------------------------------------

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Daily Challenge', tr: 'Günün Meydan Okuması')),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EkoMascot(size: 96),
                const SizedBox(height: 20),
                Text(
                  t(en: 'Finish a lesson first', tr: 'Önce bir ders tamamla'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    en:
                        "The daily challenge mixes skills you have learned. "
                        'Complete a lesson and it opens up.',
                    tr:
                        'Günün meydan okuması öğrendiğin becerileri karıştırır. '
                        'Bir dersi tamamla, açılsın.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t(en: 'Back', tr: 'Geri')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
