import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'rhythm_lesson.dart';
import 'rhythm_pattern.dart';

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

class _RhythmEchoPageState extends State<RhythmEchoPage> {
  final Random _rng = Random();

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
    super.dispose();
  }

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
              PlayButton(
                onTap: _playPattern,
                playing: _phase == _Phase.playing,
                size: 72,
                iconSize: 30,
              ),
              const SizedBox(height: 14),
              _timeline(theme),
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

  /// Zaman çizelgesi: üstte kalıp, cevaptan sonra altta kullanıcının vuruşları.
  /// İki satır alt alta durunca "erken mi geç mi vurdum" tek bakışta görülür.
  Widget _timeline(ThemeData theme) {
    final comparison = _comparison;
    final totalMs = _shape.totalMs;
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 20,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.wash,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                for (var i = 0; i < _targetMs.length; i++)
                  _mark(
                    x: _targetMs[i] / totalMs * (constraints.maxWidth - 18),
                    color: _soundingIndex == i
                        ? AppColors.grape
                        : theme.colorScheme.outline,
                    big: _soundingIndex == i,
                  ),
              ],
            ),
          ),
        ),
        if (comparison != null) ...[
          Text(
            t(en: 'you', tr: 'sen'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Kullanıcının vuruşları hedefle AYNI hizalamayla çizilir
                // (ilk vuruş = sıfır), yoksa "geç başladım" hatası gibi
                // görünürdü — oysa ölçülen şey aralıklar.
                final base = _tapMs.isEmpty ? 0 : _tapMs.first;
                return Stack(
                  children: [
                    for (var i = 0; i < _tapMs.length; i++)
                      _mark(
                        x:
                            (_tapMs[i] - base + _targetMs.first) /
                            totalMs *
                            (constraints.maxWidth - 18),
                        color: comparison.matches[i]
                            ? AppColors.success
                            : AppColors.danger,
                        big: true,
                        top: 6,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _mark({
    required double x,
    required Color color,
    required bool big,
    double top = 12,
  }) => Positioned(
    left: x.clamp(0, double.infinity),
    top: big ? top - 2 : top,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: big ? 22 : 18,
      height: big ? 22 : 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: big
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
    ),
  );

  /// Vuruş alanı: ekranın en büyük hedefi. Ritimde gecikme her şeydir, o yüzden
  /// [GestureDetector.onTapDown] kullanılır — onTap parmağın kalkmasını bekler.
  Widget _tapPad(ThemeData theme) {
    final remaining = _targetMs.length - _tapMs.length;
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 160,
              height: 160,
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
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      active
                          ? t(en: 'TAP', tr: 'VUR')
                          : t(en: '…', tr: '…'),
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
        const SizedBox(height: 10),
        Text(
          active
              ? t(
                  en: '$remaining hits to go',
                  tr: '$remaining vuruş kaldı',
                )
              : t(en: 'Listening…', tr: 'Dinleniyor…'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
