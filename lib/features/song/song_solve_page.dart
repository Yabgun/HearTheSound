import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_theme.dart';
import '../../ui/coach_mark.dart';
import '../../ui/play_button.dart';
import '../harmony/chord_label.dart';
import '../harmony/harmony_round.dart';
import '../mascot/player_eko.dart';
import 'song_puzzle.dart';

// -----------------------------------------------------------------------------
// ŞARKI ÇÖZ — uygulamanın varış noktası
//
// Track değil MOD: bir şarkı çalınır, kullanıcı akorlarını ölçü ölçü çıkarır.
// Armoni Kulağı'ndaki "Kalıbı Çöz" dersinin gerçek şarkı boyundaki hâli — o
// ders cihazda "tam olarak istediğim" diye onaylandığı için mekanik AYNEN
// korunuyor, yalnızca ölçek büyüyor.
//
// İKİ ŞEY BUNU BİR ALIŞTIRMADAN ŞARKI ÇÖZMEYE ÇEVİRİR:
//  1. ÖLÇÜYE DOKUNUP TEK BAŞINA DİNLEMEK — gerçek transkripsiyonun temel
//     hareketi budur (takıldığın yeri döngüye al). Sekiz ölçüyü baştan sona
//     dinleyip aklında tutmak hafıza sınavı olurdu; asıl beceri değil.
//  2. ŞARKININ KENDİNİ TEKRAR ETMESİ — ikinci yarı çoğu zaman birincinin
//     aynısıdır. Kullanıcı bunu fark ettiğinde iş yarıya iner; fark etmesi
//     istenen sezgi tam olarak bu. Adı çözümden SONRA konur.
//
// v1 sadeliği bilinçli: ölçüde bir akor, sabit süre. Ritim/senkop Ritim Kulağı
// ile gelir; buraya erken karıştırmak iki beceriyi birden ölçerdi.
// -----------------------------------------------------------------------------

/// İlerleme kaydında Şarkı Çöz'ün beceri kimliği.
///
/// Müfredat dersi DEĞİLDİR: `completeLesson(completed: false)` ile yazılır →
/// hiçbir kilidi açmaz, tekrar rotasyonuna girmez (denetleyici tekrar kaydını
/// yalnızca zaten rotasyondaki beceriler için tazeler). Yaptığı tek şey XP,
/// günlük seri ve karıştırma istatistiğini beslemek.
const String kSongSolveSkillId = 'song_solve';

/// Şarkı Çöz'ün açılması için bitmesi gereken ders: Kalıbı Çöz.
/// Mekaniği ilk orada öğreniyor; önce açılsa kullanıcı boğulurdu.
const String kSongSolveUnlockLesson = 'har8';

enum _Phase { chooser, solving }

class SongSolvePage extends ConsumerStatefulWidget {
  const SongSolvePage({super.key, this.player});

  /// Ses çalıcı. Normalde sayfa kendi çalıcısını kurar; testler sessiz bir
  /// sahte çalıcı geçirebilsin diye dışarıdan verilebilir (diğer egzersiz
  /// sayfalarıyla aynı sözleşme). Dışarıdan gelen çalıcıyı sayfa KAPATMAZ —
  /// sahibi verendir.
  final NotePlayer? player;

  @override
  ConsumerState<SongSolvePage> createState() => _SongSolvePageState();
}

class _SongSolvePageState extends ConsumerState<SongSolvePage> {
  static const int _xpPerBar = 8;

  final Random _rng = Random();
  late final NotePlayer _player = widget.player ?? createNotePlayer();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(_player);

  _Phase _phase = _Phase.chooser;
  late SongDifficulty _difficulty;
  SongPuzzle? _puzzle;

  // Coach-mark turu hedefleri. Modun kilit hareketi — ÖLÇÜYE DOKUNUP TEK
  // BAŞINA DİNLEMEK — kendiliğinden keşfedilmiyor (cihaz geri bildirimi:
  // "genel kitlenin aklına gelmeyebilir"). Bu yüzden üç katmanlı anlatım var:
  // ilk şarkıda spot ışıklı tur + ızgaranın altında kalıcı tek satır ipucu +
  // başlıkta istendiği zaman turu tekrar açan düğme.
  final GlobalKey _firstBarKey = GlobalKey();
  final GlobalKey _paletteKey = GlobalKey();
  bool _showCoach = false;

  /// Kullanıcının ölçü ölçü cevabı (null = boş ölçü).
  List<Chord?> _answer = [];

  /// Şu an üzerinde çalışılan ölçü — palet dokunuşu buraya yazar.
  int _current = 0;

  /// Çalınan ölçünün indisi (tümü çalarken canlı ilerler).
  int? _playingBar;

  /// Çözüm kontrol edildiyse ölçü ölçü doğruluk.
  List<bool>? _checked;

  bool get _isSolved => _checked != null && _checked!.every((c) => c);

  bool get _isFull => _answer.every((c) => c != null);

  @override
  void dispose() {
    _phrasePlayer.cancel();
    if (widget.player == null) _player.dispose();
    super.dispose();
  }

  void _startSong(SongDifficulty difficulty) {
    setState(() {
      _difficulty = difficulty;
      _phase = _Phase.solving;
      _newPuzzle();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Önce şarkı bir kez çalsın: tur, kullanıcı NE duyduğunu bildikten sonra
      // "şimdi bununla ne yapacaksın"ı anlatır. Ters sırada tur soyut kalırdı.
      await _playSong();
      if (!mounted) return;
      if (!ref.read(settingsProvider).songTutorialSeen) _openCoach();
    });
  }

  void _openCoach() {
    if (mounted) setState(() => _showCoach = true);
  }

  void _closeCoach() {
    ref.read(settingsProvider.notifier).setSongTutorialSeen(true);
    if (mounted) setState(() => _showCoach = false);
  }

  List<CoachStep> _coachSteps() => [
    CoachStep(
      title: t(en: 'Stuck on a bar?', tr: 'Bir ölçüde takıldın mı?'),
      body: t(
        en: 'Tap any bar and it plays on its own, as many times as you like. '
            'That is how musicians actually work a song out — loop the bit you '
            'cannot catch.',
        tr: 'Herhangi bir ölçüye dokun; o ölçü tek başına çalar, istediğin '
            'kadar. Müzisyenler bir şarkıyı gerçekte böyle çıkarır — '
            'yakalayamadığın yeri döngüye alarak.',
      ),
      targetKey: _firstBarKey,
    ),
    CoachStep(
      title: t(en: 'Then place a chord', tr: 'Sonra bir akor koy'),
      body: t(
        en: 'Tap a chord down here to hear it. If it matches, it drops into '
            'the bar you are working on. Wrong one? Just tap another.',
        tr: 'Aşağıdaki akorlardan birine dokun, çalsın. Tuttuysa üzerinde '
            'çalıştığın ölçüye yazılır. Tutmadıysa başkasına dokun.',
      ),
      targetKey: _paletteKey,
    ),
  ];

  void _newPuzzle() {
    final puzzle = generateSongPuzzle(difficulty: _difficulty, rng: _rng);
    _puzzle = puzzle;
    _answer = List<Chord?>.filled(puzzle.barCount, null);
    _current = 0;
    _checked = null;
    _playingBar = null;
  }

  // --- Ses --------------------------------------------------------------------

  Future<void> _playSong() async {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    await _phrasePlayer.play(
      puzzle.phrase,
      onEvent: (i) {
        if (mounted) setState(() => _playingBar = i);
      },
    );
    if (mounted) setState(() => _playingBar = null);
  }

  /// Tek bir ölçüyü çalar ve onu "üzerinde çalışılan ölçü" yapar.
  Future<void> _playBar(int index) async {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    await _phrasePlayer.cancel();
    setState(() {
      _current = index;
      _playingBar = index;
    });
    await _player.playChord(puzzle.barVoicing(index));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _playingBar = null);
  }

  // --- Çözme ------------------------------------------------------------------

  /// Palet taşı: akoru çalar ve ÜZERİNDE ÇALIŞILAN ölçüye yazar.
  Future<void> _place(Chord chord) async {
    if (_checked != null) return;
    setState(() {
      _answer[_current] = chord;
      // İmleç sıradaki BOŞ ölçüye atlar; hepsi doluysa yerinde kalır ki
      // kullanıcı aynı ölçüyü değiştirmeye devam edebilsin.
      final next = _answer.indexWhere((c) => c == null);
      if (next >= 0) _current = next;
    });
    await _player.playChord(bandVoicing(chord));
  }

  void _clearCurrent() {
    if (_checked != null) return;
    setState(() => _answer[_current] = null);
  }

  void _check() {
    final puzzle = _puzzle;
    if (puzzle == null || !_isFull) return;
    final result = checkSongSolution(puzzle: puzzle, answer: _answer);
    final correct = result.where((c) => c).length;

    final mistakes = <String>[];
    for (var i = 0; i < result.length; i++) {
      if (!result[i] && _answer[i] != null) {
        // Kalıbı Çöz ile AYNI anahtar biçimi → iki ekranın hatası tek bir
        // istatistikte toplanır (dil-bağımsız, oktavsız).
        mistakes.add(
          'progression:${shortChordName(puzzle.bars[i])}'
          '>${shortChordName(_answer[i]!)}',
        );
      }
    }

    ref
        .read(progressProvider.notifier)
        .completeLesson(
          skillId: kSongSolveSkillId,
          xpEarned: correct * _xpPerBar,
          masteryGain: correct,
          accuracy: correct / result.length,
          mistakes: mistakes,
        );

    setState(() => _checked = result);
  }

  // --- Görünüm ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.chooser) return _buildChooser(context);
    // Tur, çözme ekranının ÜSTÜNDE tam ekran bir katman: spot ışığı hedefin
    // gerçek konumunu ölçtüğü için sayfa normal yerleşimiyle çizilmeli.
    return Stack(
      children: [
        _buildSolving(context),
        if (_showCoach)
          CoachMarks(steps: _coachSteps(), onDone: _closeCoach),
      ],
    );
  }

  // ---- Zorluk seçimi --------------------------------------------------------

  String _difficultyName(SongDifficulty d) => switch (d.id) {
    'easy' => t(en: 'Short song', tr: 'Kısa şarkı'),
    'medium' => t(en: 'Full song', tr: 'Tam şarkı'),
    _ => t(en: 'Real thing', tr: 'Gerçeği'),
  };

  String _difficultySubtitle(SongDifficulty d) => switch (d.id) {
    'easy' => t(
      en: '4 bars · one chord never played',
      tr: '4 ölçü · bir tanesi hiç çalmayan akor',
    ),
    'medium' => t(
      en: '8 bars · the second half is a clue',
      tr: '8 ölçü · ikinci yarı bir ipucu',
    ),
    _ => t(
      en: '8 bars · two decoys · a different key every time',
      tr: '8 ölçü · iki tuzak · her seferinde başka bir ton',
    ),
  };

  Widget _buildChooser(BuildContext context) {
    final theme = Theme.of(context);
    // Kilit: mekaniği önce Kalıbı Çöz dersinde öğrenmeli.
    final unlocked = ref
        .watch(progressProvider)
        .isLessonCompleted(kSongSolveUnlockLesson);

    return Scaffold(
      appBar: AppBar(title: Text(t(en: 'Solve a Song', tr: 'Şarkı Çöz'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: PlayerEko(size: 96)),
            const SizedBox(height: 18),
            Text(
              t(
                en: 'This is the whole point',
                tr: 'Bütün mesele bu',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                en: 'Eko plays a song. You work out its chords, bar by bar, and '
                    'write it down. Stuck on a bar? Tap it and hear it alone.',
                tr: 'Eko bir şarkı çalar. Sen akorlarını ölçü ölçü çıkarıp '
                    'yazarsın. Bir ölçüde takıldın mı? Ölçüye dokun, tek '
                    'başına dinle.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            if (!unlocked)
              _lockedCard(theme)
            else
              for (final difficulty in kSongDifficulties) ...[
                _difficultyCard(theme, difficulty),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _lockedCard(ThemeData theme) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(Icons.lock_outline_rounded, size: 32, color: context.colors.muted),
        const SizedBox(height: 12),
        Text(
          t(
            en: 'Finish "Crack the Pattern" first',
            tr: 'Önce "Kalıbı Çöz" dersini bitir',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            en: 'That lesson in Harmony Ear teaches this exact move on four '
                'bars. Once it clicks there, a whole song is just more of it.',
            tr: 'Armoni Kulağı\'ndaki o ders bu hareketi dört ölçüde öğretiyor. '
                'Orada oturduğunda, bir şarkı bunun uzunu oluyor.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _difficultyCard(ThemeData theme, SongDifficulty difficulty) =>
      Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _startSong(difficulty),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded, color: AppColors.pink),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _difficultyName(difficulty),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _difficultySubtitle(difficulty),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );

  // ---- Çözme ekranı ---------------------------------------------------------

  Widget _buildSolving(BuildContext context) {
    final theme = Theme.of(context);
    final puzzle = _puzzle!;
    final filled = _answer.where((c) => c != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Solve a Song', tr: 'Şarkı Çöz')),
        actions: [
          // Turu atlayan ya da unutan kullanıcı elinde kalmasın: tek dokunuşla
          // her zaman geri açılır.
          IconButton(
            tooltip: t(en: 'How does this work?', tr: 'Bu nasıl çalışıyor?'),
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _openCoach,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$filled / ${puzzle.barCount}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Kaydırılabilir gövde + sabit alt eylemler: bu ekran uygulamanın en
          // yoğunu (ölçü ızgarası + palet), büyük yazı tipinde taşmasın.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        _prompt(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isSolved)
                        const PlayerEko(size: 76, celebrate: true)
                      else
                        PlayButton(
                          onTap: _playSong,
                          playing: _phrasePlayer.isPlaying,
                          size: 76,
                          iconSize: 32,
                        ),
                      const SizedBox(height: 14),
                      _barGrid(theme, puzzle),
                      const SizedBox(height: 8),
                      // KALICI ipucu: tur atlanmış ya da unutulmuş olabilir ve
                      // "ölçüye dokun" hareketi kendiliğinden akla gelmiyor.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              t(
                                en: 'Tap a bar to hear it on its own',
                                tr: 'Bir ölçüye dokun, tek başına çalsın',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_checked != null) ...[
                        const SizedBox(height: 14),
                        _verdict(theme, puzzle),
                      ],
                      const SizedBox(height: 16),
                      if (_checked == null) _palette(theme, puzzle),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _actions(theme),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt() {
    if (_checked != null) {
      return _isSolved
          ? t(en: 'You solved the song!', tr: 'Şarkıyı çözdün!')
          : t(
              en: 'Close — the green bars were right',
              tr: 'Az kaldı — yeşil ölçüler doğruydu',
            );
    }
    return t(
      en: 'Work out the chord in each bar',
      tr: 'Her ölçüdeki akoru çıkar',
    );
  }

  /// Ölçü ızgarası — satır başına 4 ölçü (müzikte cümle dört ölçüdür; ızgara da
  /// öyle bölününce ikinci satırın birincinin tekrarı olduğu GÖRÜNÜR hale gelir).
  Widget _barGrid(ThemeData theme, SongPuzzle puzzle) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing * 3) / 4;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < puzzle.barCount; i++)
              SizedBox(
                // İlk ölçü tur hedefidir (spot ışığı buraya düşer).
                key: i == 0 ? _firstBarKey : null,
                width: width,
                child: _bar(theme, i),
              ),
          ],
        );
      },
    );
  }

  Widget _bar(ThemeData theme, int index) {
    final checked = _checked;
    final chord = _answer[index];
    final isCurrent = _checked == null && index == _current;
    final isPlaying = _playingBar == index;

    final Color background;
    final Color foreground;
    if (checked != null) {
      background = checked[index] ? context.colors.success : context.colors.danger;
      foreground = checked[index]
          ? context.colors.onSuccess
          : context.colors.onDanger;
    } else if (chord != null) {
      background = context.colors.grapeSoft;
      foreground = context.colors.ink;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = context.colors.ink;
    }

    return Semantics(
      button: true,
      selected: isCurrent,
      label: t(en: 'Bar ${index + 1}', tr: '${index + 1}. ölçü'),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Cevaptan sonra da dinlenebilir: "doğrusu neymiş" anı burada yaşanır.
          onTap: () => _playBar(index),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPlaying
                    ? context.colors.grape
                    : isCurrent
                    ? context.colors.grape.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: isPlaying ? 3 : 2,
              ),
            ),
            // Ölçü kutusu sabit yükseklikte (ızgara hizalı dursun) ama içeriği
            // ölçeklenir: büyük sistem yazı tipinde ölçü numarası + akor
            // sığmayıp taşıyordu.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 24,
                    child: chord == null
                        ? Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: foreground.withValues(alpha: 0.45),
                          )
                        : ChordLabel(chord, color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _palette(ThemeData theme, SongPuzzle puzzle) {
    const spacing = 8.0;
    final perRow = puzzle.palette.length <= 4 ? puzzle.palette.length : 3;
    return Column(
      key: _paletteKey,
      children: [
        Text(
          t(
            en: 'Tap a chord to hear it and drop it into bar ${_current + 1}',
            tr: 'Bir akora dokun: çalar ve ${_current + 1}. ölçüye yazılır',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: [
                for (final chord in puzzle.palette)
                  SizedBox(
                    width: width,
                    child: _paletteTile(theme, chord),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _paletteTile(ThemeData theme, Chord chord) => Semantics(
    button: true,
    label: fullChordName(chord),
    child: Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _place(chord),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ChordLabel(chord, color: context.colors.ink),
        ),
      ),
    ),
  );

  /// Çözümden sonra: doğru sayısı + şarkının YAPISI hakkındaki içgörü.
  Widget _verdict(ThemeData theme, SongPuzzle puzzle) {
    final correct = _checked!.where((c) => c).length;
    final insight = _formInsight(puzzle.form);
    return Column(
      children: [
        Text(
          t(
            en: '$correct of ${puzzle.barCount} bars right',
            tr: '${puzzle.barCount} ölçünün $correct tanesi doğru',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (insight != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.grapeSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              insight,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Şarkının yapısını ADLANDIRIR — ama ancak kullanıcı onu çözdükten SONRA.
  /// ("Önce yaşat, sonra adını koy": teori rozetleriyle aynı ilke.)
  String? _formInsight(SongForm form) => switch (form) {
    SongForm.single => null,
    SongForm.repeat => t(
      en: 'Notice: the second half was exactly the same as the first. Songs '
          'repeat themselves — solve half, and you often have the whole thing.',
      tr: 'Fark ettin mi: ikinci yarı birincinin tıpatıp aynısıydı. Şarkılar '
          'kendini tekrar eder — yarısını çözdüğünde çoğu zaman tamamını '
          'çözmüş olursun.',
    ),
    SongForm.repeatVariedEnding => t(
      en: 'Notice: the second half repeated the first, and only the LAST chord '
          'changed. That single swap is the most common trick in popular music.',
      tr: 'Fark ettin mi: ikinci yarı birinciyi tekrarladı, yalnızca SON akor '
          'değişti. Bu tek değişiklik popüler müziğin en yaygın numarasıdır.',
    ),
    SongForm.contrast => t(
      en: 'This one did not repeat: the second half went somewhere new. That '
          'is a song moving into a different section.',
      tr: 'Bu sefer tekrar yoktu: ikinci yarı yeni bir yere gitti. Şarkının '
          'başka bir bölüme geçmesi böyle olur.',
    ),
  };

  Widget _actions(ThemeData theme) {
    if (_checked == null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _answer[_current] == null ? null : _clearCurrent,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t(en: 'Clear bar', tr: 'Ölçüyü sil')),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _isFull ? _check : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t(en: 'Check it', tr: 'Çözdüm')),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _phase = _Phase.chooser),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t(en: 'Finish', tr: 'Bitir')),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () {
              setState(_newPuzzle);
              _playSong();
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t(en: 'New song', tr: 'Yeni şarkı')),
            ),
          ),
        ),
      ],
    );
  }
}
