import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/echo.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/phrase_dots.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'melody_generator.dart';
import 'melody_lesson.dart';

// -----------------------------------------------------------------------------
// EKO OYUNU — "çaldığımı tekrarla"
//
// Uygulamanın teori tarafındaki kök sorunu, kullanıcıya müziği ETİKETLETMESİYDİ.
// Burada etiket yok: Eko bir ezgi çalar, kullanıcı aynısını üretir. Her müzik
// öğretmeninin ilk günden yaptığı şey; hiçbir terim bilmeden oynanır.
//
// İki cevap modu (kullanıcı seçer):
//  • TUŞ  — ekrandaki notalara basarak. Her yerde çalışır, doğrulaması kesin.
//           Tuşa basınca ses ÇALAR → kullanıcı notayı kulağıyla arayabilir.
//  • SÖYLE — mikrofona söyleyerek. Uygulamanın çekirdek Duy→Söyle döngüsü.
//           Burada PitchMeter gibi hedefi gösteren bir rehber YOKTUR: rehber
//           gösterilse kullanıcı ezgiyi hatırlamak yerine ibreyi takip ederdi.
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class EchoGamePage extends StatefulWidget {
  const EchoGamePage({
    super.key,
    required this.lesson,
    required this.player,
    required this.mode,
    required this.onModeChanged,
    required this.onComplete,
    this.range,
    this.questionCount,
  });

  final MelodyLesson lesson;
  final NotePlayer player;
  final EchoInputMode mode;
  final ValueChanged<EchoInputMode> onModeChanged;
  final void Function(LessonResult result) onComplete;
  final VocalRange? range;

  /// Soru sayısını dersin varsayılanı yerine dışarıdan belirler (Sonsuz Pratik
  /// ve tekrar oturumu kısa turlar ister).
  final int? questionCount;

  @override
  State<EchoGamePage> createState() => _EchoGamePageState();
}

class _EchoGamePageState extends State<EchoGamePage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);
  final PitchService _pitch = PitchService();

  /// Ev değişen derslerde kullanılacak merkezler (C'den yarım ses uzaklık).
  static const List<int> _keyShifts = [0, 2, 4, 5, 7, -2, -4];

  /// Söylenen notanın "kilitlenmesi" için gereken sabit tutma süresi.
  static const Duration _lockHold = Duration(milliseconds: 700);

  late Note _tonic;
  late MusicalPhrase _melody;
  final List<Note> _attempt = [];
  EchoComparison? _comparison;

  _Phase _phase = _Phase.playing;
  int? _eventIndex;
  int _index = 0;
  int _correct = 0;
  final List<String> _mistakes = [];

  // Söyleme modu durumu.
  bool _micActive = false;
  bool _permissionDenied = false;
  int? _candidateMidi;
  double _lockProgress = 0;
  DateTime? _lastTick;
  DateTime? _lockedAt;

  EchoInputMode get _mode =>
      _permissionDenied ? EchoInputMode.tap : widget.mode;

  int get _total => widget.questionCount ?? widget.lesson.questionCount;

  List<Note> get _target => _melody.allNotes;

  /// Tuş modundaki notalar — dersin derece havuzu, pesten tize.
  ///
  /// Tuşlar OKTAVLI ad taşır ("C4", "C5"). Oktavsız yazımda üst oktav toniği
  /// içeren derslerde (mel5/mel8, derece 8) iki tuş da "C" görünüyordu: biri
  /// doğru biri yanlış, ayırt edilemez halde. Ayrıca Armoni Kulağı'ndaki
  /// tuşlarla aynı dili konuşur — kullanıcı iki oyunda iki farklı yazım
  /// öğrenmek zorunda kalmaz.
  List<Note> get _pads => [
    for (final degree in (widget.lesson.shape.degrees.toSet().toList()..sort()))
      Note(_tonic.midi + majorDegreeSemitones(degree)),
  ];

  @override
  void initState() {
    super.initState();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playMelody());
  }

  @override
  void dispose() {
    _phrasePlayer.cancel();
    _pitch.dispose();
    super.dispose();
  }

  void _newRound() {
    final shift = widget.lesson.varyKey
        ? _keyShifts[_rng.nextInt(_keyShifts.length)]
        : 0;
    final baseMidi = Note.fromName('C', 4).midi + shift;
    // Ezgiyi kullanıcının rahat söyleyebileceği oktava taşı (söyleme modu için
    // şart; tuş modunda da aşırı tiz/pes çalmayı önler).
    final candidates = [
      for (final degree in widget.lesson.shape.degrees)
        baseMidi + majorDegreeSemitones(degree),
    ];
    _tonic = Note(baseMidi + octaveOffsetFor(candidates, widget.range));
    _melody = generateMelody(
      tonic: _tonic,
      shape: widget.lesson.shape,
      rng: _rng,
    );
    _attempt.clear();
    _comparison = null;
    _phase = _Phase.playing;
    _eventIndex = null;
    _candidateMidi = null;
    _lockProgress = 0;
  }

  Future<void> _playMelody() async {
    if (_micActive) await _stopListening();
    setState(() {
      _phase = _Phase.playing;
      _eventIndex = null;
    });

    // Ezginin ÖNÜNE hiçbir şey çalınmaz. (Bir ara "ev sesi" ipucu eklenmişti;
    // cihazda kafa karıştırıcı bulundu ve kaldırıldı. Oyunun görevi tonaliteyi
    // hissetmek değil, DUYDUĞUNU TEKRARLAMAK — fazladan her ses gürültüdür.)
    await _phrasePlayer.play(
      _melody,
      onEvent: (i) {
        if (mounted) setState(() => _eventIndex = i);
      },
    );
    if (!mounted) return;
    setState(() {
      _eventIndex = null;
      // Cevap zaten verildiyse (tekrar dinleme) sonuç ekranında kal.
      if (_phase == _Phase.playing) _phase = _Phase.answering;
    });
    if (_phase == _Phase.answering && _mode == EchoInputMode.sing) {
      _startListening();
    }
  }

  // --- Tuş modu ---------------------------------------------------------------

  Future<void> _tapPad(Note note) async {
    if (_phase != _Phase.answering || _attempt.length >= _target.length) return;
    setState(() => _attempt.add(note));
    await widget.player.play(note); // kulakla arayabilsin diye ses verir
    if (_attempt.length == _target.length) _evaluate();
  }

  void _undo() {
    if (_phase != _Phase.answering || _attempt.isEmpty) return;
    setState(_attempt.removeLast);
  }

  // --- Söyleme modu -----------------------------------------------------------

  Future<void> _startListening() async {
    await widget.player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      // İzin yoksa sessizce tuş moduna düş — kullanıcı derste tıkanmasın.
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _lastTick = null;
    if (mounted) {
      setState(() {
        _micActive = true;
        _candidateMidi = null;
        _lockProgress = 0;
      });
    }
  }

  Future<void> _stopListening() async {
    await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
  }

  void _onReading(NoteReading? reading) {
    if (!_micActive || !mounted || _phase != _Phase.answering) return;

    // Kilitlemeden hemen sonra kısa bir sağırlık: aynı nota iki kez sayılmasın.
    final lockedAt = _lockedAt;
    if (lockedAt != null &&
        DateTime.now().difference(lockedAt).inMilliseconds < 350) {
      return;
    }

    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds / _lockHold.inMilliseconds;
    _lastTick = now;

    if (reading == null) {
      setState(() => _lockProgress = (_lockProgress - dt).clamp(0.0, 1.0));
      return;
    }

    setState(() {
      if (_candidateMidi == reading.note.midi) {
        _lockProgress = (_lockProgress + dt).clamp(0.0, 1.0);
      } else {
        _candidateMidi = reading.note.midi;
        _lockProgress = 0;
      }
    });

    if (_lockProgress >= 1.0 && _candidateMidi != null) {
      _lockedAt = now;
      final locked = Note(_candidateMidi!);
      setState(() {
        _attempt.add(locked);
        _lockProgress = 0;
        _candidateMidi = null;
      });
      if (_attempt.length == _target.length) {
        _stopListening();
        _evaluate();
      }
    }
  }

  // --- Değerlendirme ----------------------------------------------------------

  void _evaluate() {
    final comparison = compareEcho(
      target: _target,
      attempt: _attempt,
      // Söyleme modunda kullanıcı kendi oktavında söyler.
      octaveTolerant: _mode == EchoInputMode.sing,
    );
    for (var i = 0; i < comparison.matches.length; i++) {
      if (!comparison.matches[i] && i < _attempt.length) {
        _mistakes.add('melody:${_target[i].name}>${_attempt[i].name}');
      }
    }
    setState(() {
      _comparison = comparison;
      _phase = _Phase.answered;
      if (comparison.isPerfect) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 >= _total) {
      widget.onComplete(
        LessonResult(_correct, _total, mistakes: _mistakes),
      );
      return;
    }
    setState(() {
      _index++;
      _newRound();
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) _playMelody();
  }

  Future<void> _retry() async {
    setState(() {
      _attempt.clear();
      _comparison = null;
      _phase = _Phase.playing;
    });
    await _playMelody();
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
            en: 'Tune ${_index + 1} / $total',
            tr: 'Ezgi ${_index + 1} / $total',
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
              const SizedBox(height: 16),
              PlayButton(
                onTap: _playMelody,
                playing: _phase == _Phase.playing,
                size: 96,
                iconSize: 42,
              ),
              const SizedBox(height: 10),
              PhraseDots(
                count: _melody.events.length,
                activeIndex: _eventIndex,
                semanticsLabel: t(en: 'Tune', tr: 'Ezgi'),
              ),
              const SizedBox(height: 18),
              _attemptRow(theme),
              const Spacer(),
              if (_phase == _Phase.answered)
                _resultArea(theme)
              else if (_mode == EchoInputMode.tap)
                _padArea(theme)
              else
                _singArea(theme),
              const SizedBox(height: 10),
              if (_phase != _Phase.answered) _modeToggle(theme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt() => switch (_phase) {
    _Phase.playing => t(en: 'Listen…', tr: 'Dinle…'),
    _Phase.answering => _mode == EchoInputMode.tap
        ? t(en: 'Now play it back', tr: 'Şimdi sen çal')
        : t(en: 'Now sing it back', tr: 'Şimdi sen söyle'),
    _Phase.answered => (_comparison?.isPerfect ?? false)
        ? t(en: 'Exactly right!', tr: 'Tam isabet!')
        : t(en: 'Close — listen again', tr: 'Az kaldı — tekrar dinle'),
  };

  /// Kullanıcının şu ana kadar verdiği notalar (cevaptan sonra renklenir).
  Widget _attemptRow(ThemeData theme) {
    final comparison = _comparison;
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _target.length; i++)
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _slotColor(theme, i, comparison),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  i < _attempt.length ? _attempt[i].label : '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: comparison != null ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _slotColor(ThemeData theme, int index, EchoComparison? comparison) {
    if (comparison != null) {
      return comparison.matches[index] ? AppColors.success : AppColors.danger;
    }
    if (index < _attempt.length) return AppColors.grapeSoft;
    return theme.colorScheme.surfaceContainerHighest;
  }

  Widget _padArea(ThemeData theme) {
    final pads = _pads;
    return Column(
      children: [
        Row(
          children: [
            for (final note in pads) ...[
              if (note != pads.first) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  button: true,
                  label: note.label,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _phase == _Phase.answering
                          ? () => _tapPad(note)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            note.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _attempt.isEmpty ? null : _undo,
          icon: const Icon(Icons.backspace_outlined, size: 18),
          label: Text(t(en: 'Undo', tr: 'Geri al')),
        ),
      ],
    );
  }

  Widget _singArea(ThemeData theme) {
    if (_permissionDenied) {
      return Text(
        t(
          en: 'Microphone is off — switch to the keys below.',
          tr: 'Mikrofon kapalı — aşağıdan tuşlara geç.',
        ),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      );
    }
    return Column(
      children: [
        Icon(
          _micActive ? Icons.mic_rounded : Icons.mic_off_rounded,
          size: 34,
          color: _micActive ? AppColors.grape : theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
        // Hedefi GÖSTERMEYEN ilerleme halkası: kullanıcı ibreyi değil, ezgiyi
        // hatırlamak zorunda. Yalnızca "sesi sabit tut" geri bildirimi verir.
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _lockProgress,
              minHeight: 8,
              backgroundColor: AppColors.wash,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _micActive
              ? t(en: 'Hold each note steady', tr: 'Her sesi sabit tut')
              : t(en: 'Getting the mic ready…', tr: 'Mikrofon hazırlanıyor…'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _resultArea(ThemeData theme) {
    final perfect = _comparison?.isPerfect ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!perfect)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              t(
                en: 'The tune was: ${_target.map((n) => n.label).join(' · ')}',
                tr: 'Ezgi şuydu: ${_target.map((n) => n.label).join(' · ')}',
              ),
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

  /// Cevap modu seçici — kullanıcı ortamına göre değiştirir (otobüste tuş,
  /// evde ses). Seçim Ayarlar'a yazılır, her derste tekrar sorulmaz.
  Widget _modeToggle(ThemeData theme) {
    if (_permissionDenied) return const SizedBox.shrink();
    return SegmentedButton<EchoInputMode>(
      segments: [
        ButtonSegment(
          value: EchoInputMode.tap,
          icon: const Icon(Icons.piano_rounded, size: 18),
          label: Text(t(en: 'Keys', tr: 'Tuşlar')),
        ),
        ButtonSegment(
          value: EchoInputMode.sing,
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: Text(t(en: 'Sing', tr: 'Söyle')),
        ),
      ],
      selected: {_mode},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (selection) async {
        final next = selection.first;
        if (next == _mode) return;
        await _stopListening();
        setState(_attempt.clear);
        widget.onModeChanged(next);
        if (next == EchoInputMode.sing && _phase == _Phase.answering) {
          _startListening();
        }
      },
    );
  }
}
