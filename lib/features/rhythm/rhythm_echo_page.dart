import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import '../mascot/player_eko.dart';
import 'rhythm_lesson.dart';
import 'rhythm_pattern.dart';
import 'rhythm_timeline.dart';

// -----------------------------------------------------------------------------
// RİTİM EKO OYUNU — "çaldığımı geri vur"
//
// Melodi'deki Eko Oyunu'nun ritim ikizi: Eko bir kalıp çalar, kullanıcı aynısını
// DOKUNARAK üretir. Etiket yok, seçenek yok — cevap duyduğu şeyin kendisi.
//
// GÖRSEL ZAMAN ÇİZELGESİ neden var: ritim, melodinin aksine "yuva yuva"
// gösterilemez — aralıklar süreklidir. Çizelge hem çalarken nerede olduğumuzu
// hem cevaptan sonra kullanıcının vuruşlarının hedefe göre NEREYE düştüğünü
// (erken/geç) gösterir. "Yanlış" demek yetmez; ritimde öğreten şey YÖNdür.
//
// Kullanıcı hazır olduğunda başlar: karşılaştırma her iki tarafı da kendi ilk
// vuruşuna göre hizalar (bkz. rhythm_pattern.dart), o yüzden geri sayıma ya da
// metronoma gerek yok — egzersize fazladan ses eklemek de bu projede yasak.
// -----------------------------------------------------------------------------

/// Ritim kalıbının sesi — perde anlamsız olduğu için HER vuruşta aynı nota.
final Note kRhythmNote = Note.fromName('C', 5);

enum _Phase { playing, answering, answered }

class RhythmEchoPage extends StatefulWidget {
  const RhythmEchoPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onComplete,
    this.questionCount,
  });

  final RhythmLesson lesson;
  final NotePlayer player;
  final void Function(LessonResult result) onComplete;

  /// Soru sayısını dersin varsayılanı yerine dışarıdan belirler (Sonsuz Pratik
  /// ve tekrar oturumu kısa turlar ister).
  final int? questionCount;

  @override
  State<RhythmEchoPage> createState() => _RhythmEchoPageState();
}

class _RhythmEchoPageState extends State<RhythmEchoPage>
    with TickerProviderStateMixin {
  final Random _rng = Random();

  /// Çalma imleci (0→1). Süresi her kalıpta yeniden ayarlanır; çizelge bunu
  /// dinleyip yalnızca kendini yeniden boyar (sayfa yeniden kurulmaz).
  late final AnimationController _playhead = AnimationController(vsync: this);

  /// Eko'nun tempo tutuşu: her seste bir kez tetiklenir.
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  /// Vuruş alanının dokunma dalgası.
  late final AnimationController _tapPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// Kullanıcının vuruşlarını ölçen kronometre (ilk vuruşta başlar).
  final Stopwatch _watch = Stopwatch();

  late List<int> _targetMs;
  final List<int> _tapMs = [];
  RhythmComparison? _comparison;

  _Phase _phase = _Phase.playing;
  int? _soundingIndex;
  int _index = 0;
  int _correct = 0;
  final List<String> _mistakes = [];

  /// Sıradaki sesi bekleyen zamanlayıcı. Tek bir zamanlayıcı zinciri kullanmak
  /// bilinçli: sayfadan çıkılınca ya da baştan çalınınca TEK `cancel()` bütün
  /// kalıbı susturur. (Önce `Future.delayed` zinciri vardı; iptal edilemediği
  /// için sayfa kapandıktan sonra bile zamanlayıcı askıda kalıyordu — testler
  /// yakaladı.)
  Timer? _timer;

  int get _total => widget.questionCount ?? widget.lesson.questionCount;

  RhythmShape get _shape => widget.lesson.shape;

  @override
  void initState() {
    super.initState();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playPattern());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playhead.dispose();
    _bounce.dispose();
    _tapPulse.dispose();
    super.dispose();
  }

  /// İmlecin kat edeceği süre: son sesten sonra kısa bir kuyruk. Ölçünün
  /// sonuna kadar süzülmesi, kalıp erken bitiyorsa kullanıcıyı boş yere
  /// bekletirdi.
  int get _playheadSpanMs => (_targetMs.isEmpty ? 0 : _targetMs.last) + 400;

  void _newRound() {
    _targetMs = onsetTimesMs(
      slots: generateRhythm(shape: _shape, rng: _rng),
      shape: _shape,
    );
    _tapMs.clear();
    _watch.reset();
    _comparison = null;
    _phase = _Phase.playing;
    _soundingIndex = null;
  }

  /// Kalıbı baştan çalar.
  void _playPattern() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.playing;
      _soundingIndex = null;
    });
    _playhead
      ..duration = Duration(milliseconds: _playheadSpanMs)
      ..forward(from: 0);
    _scheduleOnset(0, DateTime.now());
  }

  /// Sıradaki sesi zamanlar. Bekleme süresi MUTLAK programa göre hesaplanır
  /// ("hedef an eksi başlangıçtan bu yana geçen süre") — böylece ses çalma
  /// gecikmesi adım adım birikip kalıbı yavaşlatmaz.
  void _scheduleOnset(int index, DateTime start) {
    if (!mounted) return;

    if (index >= _targetMs.length) {
      // Son sesin duyulması için kısa bir kuyruk, sonra cevap sırası.
      _timer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _soundingIndex = null;
          if (_phase == _Phase.playing) _phase = _Phase.answering;
        });
      });
      return;
    }

    final elapsed = DateTime.now().difference(start).inMilliseconds;
    final wait = _targetMs[index] - elapsed;
    _timer = Timer(Duration(milliseconds: wait > 0 ? wait : 0), () {
      if (!mounted) return;
      setState(() => _soundingIndex = index);
      _bounce.forward(from: 0); // Eko her seste tempo tutar
      // Beklemeden çal: çalma çağrısını beklemek bir sonraki sesi geciktirir.
      unawaited(widget.player.play(kRhythmNote));
      _scheduleOnset(index + 1, start);
    });
  }

  /// Kullanıcı vuruşu. İlk vuruş kronometreyi başlatır ve zaman sıfırı olur.
  Future<void> _tap() async {
    if (_phase != _Phase.answering || _tapMs.length >= _targetMs.length) return;
    if (!_watch.isRunning) _watch.start();
    setState(() => _tapMs.add(_watch.elapsedMilliseconds));
    _tapPulse.forward(from: 0);
    await widget.player.play(kRhythmNote);
    if (_tapMs.length == _targetMs.length) _evaluate();
  }

  void _evaluate() {
    _watch.stop();
    final comparison = compareRhythm(
      targetMs: _targetMs,
      tapMs: _tapMs,
      toleranceMs: widget.lesson.toleranceMs,
    );
    for (var i = 0; i < comparison.matches.length; i++) {
      final offset = comparison.offsetsMs[i];
      if (!comparison.matches[i] && offset != null) {
        // Dil-BAĞIMSIZ karıştırma anahtarı: ritimde karıştırılan şey nota değil
        // YÖN — kullanıcı sürekli erken mi vuruyor, geç mi?
        _mistakes.add(offset < 0 ? 'rhythm:onTime>early' : 'rhythm:onTime>late');
      }
    }
    setState(() {
      _comparison = comparison;
      _phase = _Phase.answered;
      if (comparison.isPerfect) _correct++;
    });
  }

  void _retry() {
    _playhead.stop();
    setState(() {
      _tapMs.clear();
      _watch.reset();
      _comparison = null;
      _phase = _Phase.playing;
    });
    _playPattern();
  }

  Future<void> _next() async {
    if (_index + 1 >= _total) {
      widget.onComplete(LessonResult(_correct, _total, mistakes: _mistakes));
      return;
    }
    setState(() {
      _index++;
      _newRound();
    });
    _playPattern();
  }

  // --- Görünüm ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final progress = (_index + (_phase == _Phase.answered ? 1 : 0)) / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Rhythm ${_index + 1} / $total',
            tr: 'Ritim ${_index + 1} / $total',
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '★ $_correct',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
              // Eko + çal düğmesi yan yana: bu, uygulamadaki TEK karaktersiz
              // ekrandı ve diğer derslerden kopuk duruyordu.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _keepingTime(),
                  const SizedBox(width: 18),
                  PlayButton(
                    onTap: _playPattern,
                    playing: _phase == _Phase.playing,
                    size: 72,
                    iconSize: 30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RhythmTimeline(
                shape: _shape,
                targetMs: _targetMs,
                tapMs: _tapMs,
                comparison: _comparison,
                soundingIndex: _soundingIndex,
                playhead: _phase == _Phase.playing ? _playhead : null,
                playheadSpanMs: _playheadSpanMs,
              ),
              const Spacer(),
              if (_phase == _Phase.answered)
                _resultArea(theme)
              else
                _tapPad(theme),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt() => switch (_phase) {
    _Phase.playing => t(en: 'Listen…', tr: 'Dinle…'),
    _Phase.answering => t(
      en: 'Now tap it back — start whenever you are ready',
      tr: 'Şimdi sen vur — hazır olduğunda başla',
    ),
    _Phase.answered => (_comparison?.isPerfect ?? false)
        ? t(en: 'Spot on!', tr: 'Tam isabet!')
        : t(en: 'Close — listen again', tr: 'Az kaldı — tekrar dinle'),
  };

  /// Eko tempo tutar: her seste hafifçe zıplar. Hareket GERÇEK sese bağlı —
  /// serbest bir animasyon olsaydı yanlış tempo öğretirdi.
  Widget _keepingTime() => AnimatedBuilder(
    animation: _bounce,
    builder: (context, child) {
      final pulse = sin(pi * _bounce.value); // 0 → 1 → 0
      return Transform.translate(
        offset: Offset(0, -10 * pulse),
        child: Transform.scale(scale: 1 + 0.07 * pulse, child: child),
      );
    },
    child: PlayerEko(
      size: 60,
      celebrate: _phase == _Phase.answered && (_comparison?.isPerfect ?? false),
    ),
  );

  /// Vuruş alanı: ekranın en büyük hedefi. Ritimde gecikme her şeydir, o yüzden
  /// [GestureDetector.onTapDown] kullanılır — onTap parmağın kalkmasını bekler.
  ///
  /// Her dokunuşta genişleyen bir halka + hafif büyüme: eskiden 160 px'lik bu
  /// daireye basınca ekranda HİÇBİR ŞEY olmuyordu; en büyük öğe en sessiz
  /// öğeydi.
  Widget _tapPad(ThemeData theme) {
    final active = _phase == _Phase.answering;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: active,
          label: t(en: 'Tap the beat', tr: 'Vuruşa dokun'),
          child: GestureDetector(
            onTapDown: active ? (_) => _tap() : null,
            child: AnimatedBuilder(
              animation: _tapPulse,
              builder: (context, child) {
                final v = _tapPulse.value; // 0 → 1
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dışa açılan halka — dokunuşun "duyulur" karşılığı.
                      if (v > 0 && v < 1)
                        Container(
                          width: 130 + 60 * v,
                          height: 130 + 60 * v,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.45 * (1 - v),
                              ),
                              width: 3,
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: 1 + 0.06 * (1 - v) * (v > 0 ? 1 : 0),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.32,
                            ),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        active ? t(en: 'TAP', tr: 'VUR') : '…',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: active
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _remainingDots(theme, active),
      ],
    );
  }

  /// Kalan vuruşlar — sayı yerine NOKTA: kaç kez daha vuracağını saymadan
  /// görürsün (ritim sırasında okumak için vakit yok).
  Widget _remainingDots(ThemeData theme, bool active) {
    if (!active) {
      return Text(
        t(en: 'Listening…', tr: 'Dinleniyor…'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _targetMs.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i < _tapMs.length ? 12 : 10,
            height: i < _tapMs.length ? 12 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _tapMs.length
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }

  Widget _resultArea(ThemeData theme) {
    final comparison = _comparison!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!comparison.isPerfect)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _timingHint(comparison),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(t(en: 'Try again', tr: 'Tekrar dene')),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _next,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _index + 1 >= _total
                        ? t(en: 'Finish', tr: 'Bitir')
                        : t(en: 'Next', tr: 'Sonraki'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Ritimde "yanlış" demek öğretmez; YÖN öğretir. Kullanıcının kaçırdığı
  /// vuruşların çoğu erkense "acele ettin", geçse "geciktin" denir.
  String _timingHint(RhythmComparison comparison) {
    var early = 0;
    var late = 0;
    for (var i = 0; i < comparison.matches.length; i++) {
      final offset = comparison.offsetsMs[i];
      if (comparison.matches[i] || offset == null) continue;
      if (offset < 0) {
        early++;
      } else {
        late++;
      }
    }
    if (early == 0 && late == 0) {
      return t(
        en: 'Some hits were missing — tap once for every sound you hear.',
        tr: 'Bazı vuruşlar eksik kaldı — duyduğun her ses için bir kez vur.',
      );
    }
    if (early > late) {
      return t(
        en: 'You were rushing — wait a touch longer between hits.',
        tr: 'Acele ettin — vuruşlar arasında birazcık daha bekle.',
      );
    }
    if (late > early) {
      return t(
        en: 'You were dragging — the hits came a little sooner than that.',
        tr: 'Geciktin — vuruşlar bundan biraz daha erken geliyordu.',
      );
    }
    return t(
      en: 'The spacing drifted — listen for the gaps, not the hits.',
      tr: 'Aralıklar kaydı — vuruşları değil ARALARINI dinle.',
    );
  }
}
