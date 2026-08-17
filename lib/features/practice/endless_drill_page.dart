import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/endless_drill.dart';
import '../../core/octave_mapping.dart';
import '../../core/player_progress.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_theme.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../concept/concept_sheet.dart';
import '../harmony/harmony_lesson.dart';
import '../harmony/harmony_lesson_flow_page.dart';
import '../harmony/harmony_round.dart';
import '../lesson/lesson.dart';
import '../mascot/player_eko.dart';
import '../melody/echo_game_page.dart';
import '../melody/melody_lesson.dart';
import '../note_recognition/note_recognition_page.dart';
import '../rhythm/rhythm_echo_page.dart';
import '../rhythm/rhythm_lesson.dart';

// -----------------------------------------------------------------------------
// SONSUZ PRATİK — bitmeyen, ağırlıklı, karışık tanıma oturumu
//
// Kullanıcının ÖĞRENDİĞİ (tamamladığı) tüm becerilerden sonu gelmeyen bir tanıma
// akışı üretir. Her mini-tur, ağırlıklı seçimle (bkz. core/endless_drill.dart)
// bir beceriye ayrılır: zayıf (az çalışılmış) ve çok karıştırılan konular daha
// sık gelir. Böylece "dersleri bitirdim, yapacak şey kalmadı" sorununu çözer —
// asıl tekrar-oynanabilirlik motoru budur.
//
// Mimari: akış sayfalarıyla AYNI desen — bir "hub" fazı (ilerleme + sıradaki
// beceri + kavram kartı) ile "drilling" fazı (mevcut becerinin MEVCUT tanıma
// sayfasını tam ekran döndürür) arasında geçer. Tanıma sayfaları olduğu gibi
// yeniden kullanılır; iç içe Scaffold yoktur (her faz kendi tam-ekran sayfası).
// -----------------------------------------------------------------------------

/// Sonsuz pratikte tek bir "çalıştırılabilir" beceri: kimlik + karıştırma tipi +
/// başlık + o becerinin tanıma sayfasını kuran fabrika. Fabrika, dersin havuzunu
/// (ses aralığına transpoze edilmiş) ve doğru tanıma tipini kapsül içinde tutar.
class DrillSkill {
  final String id; // ilerleme kaydı beceri kimliği (ders id'si)
  final String type; // karıştırma tipi (note/chord/quality/inv/interval/degree/function/prog)
  final String title;
  final Widget Function(
    NotePlayer player,
    int questionCount,
    void Function(LessonResult) onComplete,
  )
  build;

  const DrillSkill({
    required this.id,
    required this.type,
    required this.title,
    required this.build,
  });
}

/// Tamamlanmış derslerden çalıştırılabilir beceri listesini kurar. Her ders,
/// akış sayfasındaki ile AYNI şekilde (transpoze + doğru tanıma sayfası)
/// paketlenir; böylece davranış birebir tutarlı kalır.
List<DrillSkill> buildDrillSkills(PlayerProgress p, VocalRange? range) {
  final skills = <DrillSkill>[];

  // Notalar
  for (final l in lessons) {
    if (!p.isLessonCompleted(l.id)) continue;
    final pool = transposeForVoice(l.pool, range);
    skills.add(
      DrillSkill(
        id: l.id,
        type: 'note',
        title: l.title,
        build: (player, qc, onDone) => NoteRecognitionPage(
          pool: pool,
          player: player,
          questionCount: qc,
          onComplete: onDone,
        ),
      ),
    );
  }

  // Akorlar — RENK duyma ve akorda ses üretme. Karıştırma tipi mekaniğe göre
  // ayrılır ki "en çok karıştırdıkların" istatistiği anlamlı kalsın.
  for (final l in chordLessons) {
    if (!p.isLessonCompleted(l.id)) continue;
    skills.add(
      DrillSkill(
        id: l.id,
        type: l.isProduction ? 'chordNote' : 'color',
        title: l.title,
        build: (player, qc, onDone) => Consumer(
          builder: (context, ref, _) => buildChordGame(
            lesson: l,
            player: player,
            ref: ref,
            questionCount: qc,
            onComplete: onDone,
          ),
        ),
      ),
    );
  }

  // Melodi Kulağı — Eko oyunu. Diğerlerinden farklı olarak TANIMA değil ÜRETME
  // becerisi; cevap modu (tuş/söyle) kullanıcının Ayarlar'daki tercihinden
  // okunur, o yüzden widget bir Consumer içinde kurulur.
  for (final l in melodyLessons) {
    if (!p.isLessonCompleted(l.id)) continue;
    skills.add(
      DrillSkill(
        id: l.id,
        type: 'melody',
        title: l.title,
        build: (player, qc, onDone) => Consumer(
          builder: (context, ref, _) => EchoGamePage(
            lesson: l,
            player: player,
            range: range,
            questionCount: qc,
            mode: ref.watch(settingsProvider).echoInputMode,
            onModeChanged: (mode) =>
                ref.read(settingsProvider.notifier).setEchoInputMode(mode),
            onComplete: onDone,
          ),
        ),
      ),
    );
  }

  // Armoni Kulağı — soru tipine göre üç ekrandan biri. Karıştırma tipi de
  // mekaniğe göre ayrılır ki "en çok karıştırdıkların" istatistiği anlamlı
  // kalsın: iki seçenekli algı ('harmony'), bas bulma ('bass') ve kalıp
  // dizme ('progression') bambaşka becerilerdir.
  for (final l in harmonyLessons) {
    if (!p.isLessonCompleted(l.id)) continue;
    skills.add(
      DrillSkill(
        id: l.id,
        type: switch (l.drill) {
          HarmonyDrill.findBass || HarmonyDrill.bassLine => 'bass',
          HarmonyDrill.pattern => 'progression',
          _ => 'harmony',
        },
        title: l.title,
        build: (player, qc, onDone) => Consumer(
          builder: (context, ref, _) => buildHarmonyGame(
            lesson: l,
            player: player,
            ref: ref,
            questionCount: qc,
            onComplete: onDone,
          ),
        ),
      ),
    );
  }

  // Ritim Kulağı — perde yok, zamanlama var. Tanıma değil ÜRETME becerisi
  // (melodi Eko oyunuyla aynı aile), o yüzden kendi tipiyle ayrılır.
  for (final l in rhythmLessons) {
    if (!p.isLessonCompleted(l.id)) continue;
    skills.add(
      DrillSkill(
        id: l.id,
        type: 'rhythm',
        title: l.title,
        build: (player, qc, onDone) => RhythmEchoPage(
          lesson: l,
          player: player,
          questionCount: qc,
          onComplete: onDone,
        ),
      ),
    );
  }

  return skills;
}

/// Karıştırma tipi belirteci → görünen (yerelleştirilmiş) ad.
String _typeLabel(String type) => switch (type) {
  'note' => t(en: 'notes', tr: 'notalar'),
  'color' => t(en: 'chord colours', tr: 'akor renkleri'),
  'chordNote' => t(en: 'notes inside chords', tr: 'akorun sesleri'),
  'interval' => t(en: 'intervals', tr: 'aralıklar'),
  'melody' => t(en: 'melodies', tr: 'ezgiler'),
  'harmony' => t(en: 'hearing harmony', tr: 'armoni duyma'),
  'bass' => t(en: 'the bass line', tr: 'bas hattı'),
  'progression' => t(en: 'chord patterns', tr: 'akor kalıpları'),
  'rhythm' => t(en: 'rhythm', tr: 'ritim'),
  _ => type,
};

/// Sonsuz Pratik kavram kartı (kural: her yeni içerik tipine kavram kartı).
Concept _endlessConcept() => Concept(
  title: t(en: 'Endless Practice', tr: 'Sonsuz Pratik'),
  sections: [
    ConceptSection(
      t(
        en:
            'A never-ending recognition session that mixes every skill you have '
            'learned so far. There is no last question — you set your own goal '
            'and stop whenever you like.',
        tr:
            'Şimdiye kadar öğrendiğin TÜM becerileri karıştıran, sonu gelmeyen '
            'bir tanıma oturumu. Son soru yoktur — hedefini kendin koyar, '
            'istediğin an durursun.',
      ),
    ),
    ConceptSection(
      heading: t(en: 'Why it works', tr: 'Neden işe yarar'),
      t(
        en:
            'Mixing skills (interleaving) and returning in short daily bursts is '
            'what actually makes an ear stick — far more than doing each lesson '
            'once.',
        tr:
            'Becerileri karıştırmak (interleaving) ve her gün kısa turlarla geri '
            'dönmek, kulağı asıl kalıcı yapan şeydir — her dersi bir kez yapmaktan '
            'çok daha etkilidir.',
      ),
    ),
    ConceptSection(
      heading: t(en: 'It targets your weak spots', tr: 'Zayıf noktana odaklanır'),
      t(
        en:
            'Skills you have practiced less, and the pairs you mix up most, come '
            'up more often — so your time goes where it helps the most.',
        tr:
            'Daha az çalıştığın beceriler ve en çok karıştırdığın çiftler daha '
            'sık gelir — böylece vaktin en çok işe yarayacağı yere gider.',
      ),
    ),
  ],
);

/// Oturum fazı: hub (özet/başlat) ↔ drilling (mevcut tanıma sayfası).
enum _Phase { hub, drilling }

class EndlessDrillPage extends ConsumerStatefulWidget {
  const EndlessDrillPage({super.key});

  @override
  ConsumerState<EndlessDrillPage> createState() => _EndlessDrillPageState();
}

class _EndlessDrillPageState extends ConsumerState<EndlessDrillPage> {
  // Bir mini-turdaki soru sayısı: karışıklığı korurken bölünmeyi az tutar.
  static const int _segment = 5;
  // Oturum hedefi ("Bugün 20 soru" hissi) — ulaşınca kutlanır ama akış bitmez.
  static const int _goal = 20;
  static const int _xpPerCorrect = 10;

  final NotePlayer _player = createNotePlayer();
  final Random _rng = Random();

  late final VocalRange? _range;
  late final List<DrillSkill> _skills;

  _Phase _phase = _Phase.hub;
  DrillSkill? _current; // sıradaki/aktif beceri
  int _answered = 0; // oturumdaki toplam soru
  int _correct = 0; // oturumdaki doğru sayısı

  @override
  void initState() {
    super.initState();
    final p = ref.read(progressProvider);
    _range = p.vocalRange;
    _skills = buildDrillSkills(p, _range);
    if (_skills.isNotEmpty) _current = _pickSkill();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Güncel ilerlemeye göre ağırlıklı bir beceri seç (zayıf/karıştırılan öne çıkar).
  DrillSkill _pickSkill() {
    final p = ref.read(progressProvider);
    final idx = pickDrillIndex(
      [for (final s in _skills) DrillCandidate(skillId: s.id, type: s.type)],
      skillXp: p.skillXp,
      confusionCounts: p.confusionCounts,
      roll: _rng.nextDouble(),
    );
    return _skills[idx < 0 ? 0 : idx];
  }

  /// Mini-tur bitti: sonucu ilerlemeye işle (XP/ustalık/karıştırma/tekrar —
  /// ama kilit AÇMAZ), sayaçları güncelle, sıradaki beceriyi seç, hub'a dön.
  void _onSegmentComplete(LessonResult result) {
    final xp = result.correct * _xpPerCorrect;
    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: _current!.id,
          xpEarned: xp,
          masteryGain: result.correct,
          accuracy: result.accuracy,
          completed: false, // sonsuz pratik yeni ders açmaz
          mistakes: result.mistakes,
        );
    setState(() {
      _answered += result.total;
      _correct += result.correct;
      _current = _pickSkill();
      _phase = _Phase.hub;
    });
  }

  void _startSegment() => setState(() => _phase = _Phase.drilling);

  @override
  Widget build(BuildContext context) {
    if (_skills.isEmpty) return _buildEmpty(context);
    if (_phase == _Phase.drilling && _current != null) {
      return _current!.build(_player, _segment, _onSegmentComplete);
    }
    return _buildHub(context);
  }

  // ---- Hub (özet + başlat) --------------------------------------------------

  Widget _buildHub(BuildContext context) {
    final theme = Theme.of(context);
    final started = _answered > 0;
    final goalReached = _answered >= _goal;
    final next = _current!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Endless Practice', tr: 'Sonsuz Pratik')),
        actions: [
          IconButton(
            tooltip: t(en: 'What is this?', tr: 'Bu nedir?'),
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showConceptSheet(context, _endlessConcept()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 4),
            Center(child: PlayerEko(size: 96, celebrate: goalReached)),
            const SizedBox(height: 16),
            Text(
              goalReached
                  ? t(en: 'Daily goal reached!', tr: 'Günlük hedef tamam!')
                  : started
                  ? t(en: 'Keep the momentum', tr: 'Devam et, momentum sende')
                  : t(en: 'Warm up your ear', tr: 'Kulağını ısıt'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              started
                  ? t(
                      en: 'Mixed questions from everything you have learned.',
                      tr: 'Öğrendiğin her şeyden karışık sorular.',
                    )
                  : t(
                      en:
                          'A never-ending, mixed session that leans into your '
                          'weak spots.',
                      tr:
                          'Zayıf noktalarına yaslanan, sonu gelmeyen karışık bir '
                          'oturum.',
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _progressCard(theme, goalReached),
            const SizedBox(height: 14),
            _nextUpCard(theme, next),
            const SizedBox(height: 14),
            ConceptCardButton(concept: _endlessConcept()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startSegment,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  started
                      ? t(en: 'Continue', tr: 'Devam et')
                      : t(en: 'Start practicing', tr: 'Pratiğe başla'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (started) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(en: 'Finish for now', tr: 'Şimdilik bitir')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Oturum ilerlemesi: soru sayısı (hedefe göre) + doğru sayısı.
  Widget _progressCard(ThemeData theme, bool goalReached) {
    final progress = (_answered / _goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t(en: 'This session', tr: 'Bu oturum'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                goalReached
                    ? t(en: '$_answered questions', tr: '$_answered soru')
                    : '$_answered / $_goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: goalReached ? 1 : progress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _answered == 0
                ? t(
                    en: 'Aim for $_goal questions in this session.',
                    tr: 'Bu oturumda $_goal soruyu hedefle.',
                  )
                : t(
                    en: '$_correct correct out of $_answered',
                    tr: '$_answered soruda $_correct doğru',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Sıradaki becerinin önizlemesi (başlık + tip).
  Widget _nextUpCard(ThemeData theme, DrillSkill next) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.all_inclusive_rounded, color: AppColors.amber),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(en: 'Up next', tr: 'Sıradaki'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _typeLabel(next.type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Boş durum (henüz tamamlanmış ders yok) -------------------------------

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Endless Practice', tr: 'Sonsuz Pratik')),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PlayerEko(size: 96),
                const SizedBox(height: 20),
                Text(
                  t(
                    en: 'Finish a lesson first',
                    tr: 'Önce bir ders tamamla',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    en:
                        'Endless Practice mixes the skills you have learned. '
                        'Complete at least one lesson and it will open up here.',
                    tr:
                        'Sonsuz Pratik öğrendiğin becerileri karıştırır. En az '
                        'bir dersi tamamla, burada açılsın.',
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
