import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_theme.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../harmony/harmony_lesson.dart';
import '../harmony/harmony_lesson_flow_page.dart';
import '../home/curriculum.dart';
import '../lesson/lesson.dart';
import '../mascot/player_eko.dart';
import '../melody/echo_game_page.dart';
import '../melody/melody_lesson.dart';
import '../note_recognition/note_recognition_page.dart';
import '../rhythm/rhythm_echo_page.dart';
import '../rhythm/rhythm_lesson.dart';
import 'placement_ladder.dart';

// -----------------------------------------------------------------------------
// SEVİYE TESPİTİ — MERDİVEN TESTİ
//
// Kullanıcı GERÇEK ders ekranlarıyla sınanır: uydurma bir "test arayüzü" yok.
// Her basamak bir track'in en zor dersidir ve üç soru sorar. Geçersen o track'in
// tamamı açılır ve bir üst basamağa çıkarsın; ilk takıldığın yerde test biter.
//
// ÜÇ TASARIM KARARI:
//  (a) GERÇEK DERS EKRANI — kullanıcı testte gördüğü şeyi derste de görür;
//      ayrıca "bu seviyeyi biliyor musun" sorusunun tek dürüst cevabı, dersin
//      kendisini oynatmaktır. (Eski test bunu yapıyordu ama yalnızca iki
//      track için; üç yetenek track'i hiç yoklanmıyordu.)
//  (b) GEÇME BARAJI = dersin kendi barajı ([kPassAccuracy]) — bir track'i
//      ATLAMAK, o dersi GEÇMEKle aynı ölçüde olmalı. Üç soruda bu "üçü de
//      doğru" demek. Bilinçli olarak sıkı: yanlış atlama kullanıcıyı
//      bilmediği derslere düşürür (churn); gereksiz tekrar ise yalnızca biraz
//      sıkıcıdır. İki hatanın maliyeti eşit değil.
//  (c) MERDİVEN GÖRÜNÜR — her basamak arasında kullanıcı nerede olduğunu
//      görür. Görünmeyen bir test, art arda beş yabancı ekran demektir.
// -----------------------------------------------------------------------------

enum _Stage { ladder, running, result }

class PlacementTestPage extends ConsumerStatefulWidget {
  const PlacementTestPage({super.key});

  @override
  ConsumerState<PlacementTestPage> createState() => _PlacementTestPageState();
}

class _PlacementTestPageState extends ConsumerState<PlacementTestPage> {
  static const int _questionsPerRung = 3;

  final NotePlayer _player = createNotePlayer();
  late final VocalRange? _range = ref.read(progressProvider).vocalRange;

  _Stage _stage = _Stage.ladder;

  /// Geçilen basamak sayısı = sıradaki basamağın indeksi.
  int _passed = 0;

  /// Takılarak mı bitti? (Sonuç metni buna göre değişir.)
  bool _stopped = false;

  List<String> get _rungs => placementRungIds;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onRungComplete(LessonResult result) {
    // Baraj dersin kendi barajı: bir track'i atlamak, o dersi geçmekle aynı.
    if (result.accuracy >= kPassAccuracy) {
      setState(() {
        _passed++;
        _stage = _passed >= _rungs.length ? _Stage.result : _Stage.ladder;
      });
    } else {
      setState(() {
        _stopped = true;
        _stage = _Stage.result;
      });
    }
  }

  /// Sonucu ilerlemeye yaz ve onboarding'e dön.
  void _finish() {
    ref.read(progressProvider.notifier).applyPlacement(placementUnlocks(_passed));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Testi bırakıp sıfırdan başla — hiçbir şey açılmaz.
  void _startFromScratch() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.ladder => _buildLadder(context),
      _Stage.running => _buildRung(context),
      _Stage.result => _buildResult(context),
    };
  }

  // --- Basamaklar arası: merdivenin kendisi ----------------------------------

  Widget _buildLadder(BuildContext context) {
    final theme = Theme.of(context);
    final isStart = _passed == 0;
    final next = curriculum[_passed];

    return Scaffold(
      appBar: AppBar(
        // Geri tuşu AÇIK bırakıldı: yanlışlıkla giren çıkabilmeli. Geri
        // dönülürse hiçbir şey uygulanmaz (pop null) ve onboarding başlangıç
        // noktası ekranında bekler — sonuç yarım kaydedilmez.
        title: Text(t(en: 'Finding your level', tr: 'Seviyeni buluyoruz')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(child: PlayerEko(size: isStart ? 96 : 84)),
            const SizedBox(height: 16),
            Text(
              isStart
                  ? t(en: 'Show me what you know', tr: 'Bildiğini göster')
                  : t(en: 'Nice — one step up!', tr: 'Güzel — bir basamak yukarı!'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isStart
                  ? t(
                      en: "I'll play the hardest lesson of each part. Get all "
                          'three right and we skip that part completely. Miss '
                          'one and we stop there — that is where you start.',
                      tr: 'Her bölümün en zor dersinden soracağım. Üçünü de '
                          'doğru bilirsen o bölümü tamamen atlıyoruz. Birini '
                          'kaçırırsan orada duruyoruz — başlangıcın orası.',
                    )
                  : t(
                      en: 'You know that part. Here comes the next one.',
                      tr: 'O bölümü biliyorsun. Sıradaki geliyor.',
                    ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < curriculum.length; i++)
              _LadderStep(
                track: curriculum[i],
                state: i < _passed
                    ? _StepState.passed
                    : (i == _passed ? _StepState.current : _StepState.upcoming),
                questions: _questionsPerRung,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(() => _stage = _Stage.running),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                isStart
                    ? t(en: 'Start', tr: 'Başla')
                    : t(en: 'Next part', tr: 'Sıradaki bölüm'),
              ),
            ),
            if (isStart)
              TextButton(
                onPressed: _startFromScratch,
                child: Text(
                  t(
                    en: 'Start from scratch instead',
                    tr: 'Bunun yerine sıfırdan başla',
                  ),
                ),
              )
            else
              // Basamak geçtikten sonra bırakmak da bir seçenek: kazanılan
              // basamaklar korunur, kalan bölümler baştan oynanır.
              TextButton(
                onPressed: _finish,
                child: Text(
                  t(en: 'Stop here', tr: 'Burada bırak'),
                ),
              ),
            // Sonraki bölümün adı düğmenin altında da yazılı: kullanıcı neye
            // gireceğini bilerek dokunsun.
            const SizedBox(height: 4),
            Text(
              t(en: 'Next: ${next.name}', tr: 'Sıradaki: ${next.name}'),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Basamağın kendisi: GERÇEK ders ekranı ---------------------------------

  Widget _buildRung(BuildContext context) {
    final id = _rungs[_passed];
    // Anahtar basamağa özel: aynı tipte iki basamak art arda gelse bile State
    // sıfırlansın (Günün Meydan Okuması'nda çıkan "9 soru dedi, 3'te bitti"
    // hatasının aynısı burada da olurdu).
    final key = ValueKey('placement-$_passed-$id');

    final note = lessons.where((l) => l.id == id).firstOrNull;
    if (note != null) {
      return NoteRecognitionPage(
        key: key,
        pool: transposeForVoice(note.pool, _range),
        player: _player,
        questionCount: _questionsPerRung,
        onComplete: _onRungComplete,
      );
    }

    final melody = melodyLessons.where((l) => l.id == id).firstOrNull;
    if (melody != null) {
      // Cevap modu (tuş/söyle) Ayarlar'daki ORTAK tercihten okunur — testte
      // başka, derste başka davranan bir ekran kafa karıştırırdı.
      return EchoGamePage(
        key: key,
        lesson: melody,
        player: _player,
        range: _range,
        questionCount: _questionsPerRung,
        mode: ref.watch(settingsProvider).echoInputMode,
        onModeChanged: (mode) =>
            ref.read(settingsProvider.notifier).setEchoInputMode(mode),
        onComplete: _onRungComplete,
      );
    }

    final chord = chordLessons.where((l) => l.id == id).firstOrNull;
    if (chord != null) {
      return KeyedSubtree(
        key: key,
        child: buildChordGame(
          lesson: chord,
          player: _player,
          ref: ref,
          questionCount: _questionsPerRung,
          onComplete: _onRungComplete,
        ),
      );
    }

    final harmony = harmonyLessons.where((l) => l.id == id).firstOrNull;
    if (harmony != null) {
      return KeyedSubtree(
        key: key,
        child: buildHarmonyGame(
          lesson: harmony,
          player: _player,
          ref: ref,
          questionCount: _questionsPerRung,
          onComplete: _onRungComplete,
        ),
      );
    }

    final rhythm = rhythmLessons.where((l) => l.id == id).firstOrNull;
    if (rhythm != null) {
      return RhythmEchoPage(
        key: key,
        lesson: rhythm,
        player: _player,
        questionCount: _questionsPerRung,
        onComplete: _onRungComplete,
      );
    }

    // Buraya düşmek, müfredata oyun ekranı bilinmeyen bir track eklendi demektir.
    // Nöbetçi test (placement_ladder_test) bunu kod düzeyinde yakalar; yine de
    // kullanıcıyı boş ekranda bırakmayalım: testi olduğu yerde bitir.
    return _buildResult(context);
  }

  // --- Sonuç -----------------------------------------------------------------

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final nothing = _passed == 0;
    final all = _passed >= curriculum.length;
    // Nereden başlayacak: geçemediği ilk track (hepsini geçtiyse sonuncusu —
    // son ders kuralı gereği orada tek bir ders açık kalır).
    final startTrack = curriculum[_passed.clamp(0, curriculum.length - 1)];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            const SizedBox(height: 12),
            Center(child: PlayerEko(size: 110, celebrate: !nothing)),
            const SizedBox(height: 16),
            Text(
              nothing
                  ? t(en: 'Starting fresh', tr: 'Baştan başlıyoruz')
                  : (all
                        ? t(en: 'You know it all!', tr: 'Hepsini biliyorsun!')
                        : t(en: 'Found your spot!', tr: 'Yerin belli!')),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              nothing
                  ? t(
                      en: "We'll start gently from the first lesson — no rush.",
                      tr: 'İlk dersten güzelce başlayalım — acelesi yok.',
                    )
                  : (all
                        ? t(
                            en: 'You cleared every part. I left the last lesson '
                                'open so you have somewhere to play.',
                            tr: 'Bütün bölümleri geçtin. Oynayacak bir yerin '
                                'olsun diye son dersi açık bıraktım.',
                          )
                        : t(
                            en: "I've unlocked what you already know. You start "
                                'at ${startTrack.name}.',
                            tr: 'Bildiklerini açtım. ${startTrack.name} '
                                'bölümünden başlıyorsun.',
                          )),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < curriculum.length; i++)
              _LadderStep(
                track: curriculum[i],
                state: i < _passed
                    ? _StepState.passed
                    : (i == _passed && _stopped
                          ? _StepState.start
                          : _StepState.upcoming),
                questions: _questionsPerRung,
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _finish,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(t(en: 'Continue', tr: 'Devam')),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState {
  passed, // geçildi → track açılacak
  current, // şimdi sorulan
  start, // testin durduğu yer = başlangıç noktası
  upcoming, // henüz sorulmadı
}

/// Merdivenin tek basamağı: track ikonu + adı + durumu.
///
/// Kullanıcının "şu an neredeyim" sorusunun cevabı; testin beş yabancı ekrana
/// dönüşmemesinin tek sebebi bu görünüm.
class _LadderStep extends StatelessWidget {
  final Track track;
  final _StepState state;
  final int questions;

  const _LadderStep({
    required this.track,
    required this.state,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = state != _StepState.upcoming;
    final color = active ? track.color : AppColors.faint;

    final String status = switch (state) {
      _StepState.passed => t(en: 'You know this', tr: 'Bunu biliyorsun'),
      _StepState.current => t(
        en: '$questions questions',
        tr: '$questions soru',
      ),
      _StepState.start => t(en: 'You start here', tr: 'Buradan başlıyorsun'),
      _StepState.upcoming => t(en: 'Later', tr: 'Sonra'),
    };

    final IconData badge = switch (state) {
      _StepState.passed => Icons.check_rounded,
      _StepState.start => Icons.flag_rounded,
      _ => track.icon,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : AppColors.wash,
          borderRadius: BorderRadius.circular(16),
          border: state == _StepState.current || state == _StepState.start
              ? Border.all(color: color, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: state == _StepState.passed ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: state == _StepState.passed
                    ? null
                    : Border.all(color: color, width: 2),
              ),
              child: Icon(
                badge,
                size: 20,
                color: state == _StepState.passed ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
