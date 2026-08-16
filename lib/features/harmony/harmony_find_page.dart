import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/echo.dart';
import '../../core/note.dart';
import '../../ui/app_theme.dart';
import '../../ui/phrase_dots.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'harmony_lesson.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ — BAS BULMA EKRANI (dersler 4, 5)
//
// "Bası Bul" tek ses, "Bas Hattını Çıkar" ise bir dizinin BÜTÜN bas sesleridir;
// mekanik aynı olduğu için tek ekran ikisini de karşılar (hedef listesinin
// uzunluğu değişir). Kullanıcı hiçbir şey etiketlemez — duyduğu sesi bulur.
//
// İki cevap modu (Eko Oyunu'yla aynı sözleşme, tercih Ayarlar'da saklanır):
//  • TUŞ  — tuşa basınca ses ÇALAR ve yuvaya girer; kullanıcı kulağıyla ARAR,
//           "geri al" ile vazgeçer, hazır olduğunda onaylar. Bu arama
//           serbestliği bilinçlidir: "bul" demek deneme hakkı vermek demektir;
//           ilk dokunuşu cevap saymak kumar olurdu.
//  • SÖYLE — mikrofona söyleyerek. Sesi sabit tutmak notayı kilitler; son nota
//           kilitlenince cevap kendiliğinden verilir (söylemek doğası gereği
//           geri alınamaz — orada onay düğmesi anlamsız olurdu).
//
// Hedefi gösteren bir PitchMeter YOKTUR: hedef nota cevabın kendisidir, ibre
// onu ele verirdi. Kullanıcı yalnızca "sesini sabit tut" geri bildirimi görür.
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class HarmonyFindPage extends StatefulWidget {
  const HarmonyFindPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.mode,
    required this.onModeChanged,
    required this.onComplete,
    this.questionCount,
  });

  final HarmonyLesson lesson;
  final NotePlayer player;
  final EchoInputMode mode;
  final ValueChanged<EchoInputMode> onModeChanged;
  final void Function(LessonResult result) onComplete;

  /// Soru sayısını dersin varsayılanı yerine dışarıdan belirler (Sonsuz Pratik
  /// ve tekrar oturumu kısa turlar ister).
  final int? questionCount;

  @override
  State<HarmonyFindPage> createState() => _HarmonyFindPageState();
}

class _HarmonyFindPageState extends State<HarmonyFindPage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);
  final PitchService _pitch = PitchService();

  /// Söylenen notanın "kilitlenmesi" için gereken sabit tutma süresi.
  static const Duration _lockHold = Duration(milliseconds: 700);

  late Note _tonic;
  late FindRound _round;
  final List<Note> _attempt = [];
  List<bool>? _matches;

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

  List<Note> get _targets => _round.targets;

  bool get _isPerfect => _matches != null && _matches!.every((m) => m);

  bool get _isFull => _attempt.length == _targets.length;

  List<Note> get _pads =>
      padNotesFor(tonic: _tonic, degrees: widget.lesson.degrees);

  @override
  void initState() {
    super.initState();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playPhrase());
  }

  @override
  void dispose() {
    _phrasePlayer.cancel();
    _pitch.dispose();
    super.dispose();
  }

  void _newRound() {
    _tonic = harmonyTonic(varyKey: widget.lesson.varyKey, rng: _rng);
    _round = generateFindRound(
      drill: widget.lesson.drill,
      tonic: _tonic,
      degrees: widget.lesson.degrees,
      rng: _rng,
    );
    _attempt.clear();
    _matches = null;
    _phase = _Phase.playing;
    _eventIndex = null;
    _candidateMidi = null;
    _lockProgress = 0;
  }

  Future<void> _playPhrase() async {
    if (_micActive) await _stopListening();
    setState(() {
      _eventIndex = null;
      if (_phase != _Phase.answered) _phase = _Phase.playing;
    });
    await _phrasePlayer.play(
      _round.phrase,
      onEvent: (i) {
        if (mounted) setState(() => _eventIndex = i);
      },
    );
    if (!mounted) return;
    setState(() {
      _eventIndex = null;
      if (_phase == _Phase.playing) _phase = _Phase.answering;
    });
    if (_phase == _Phase.answering && _mode == EchoInputMode.sing) {
      _startListening();
    }
  }

  // --- Tuş modu ---------------------------------------------------------------

  Future<void> _tapPad(Note note) async {
    if (_phase != _Phase.answering || _isFull) return;
    setState(() => _attempt.add(note));
    await widget.player.play(note); // kulakla arayabilsin diye ses verir
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
      // Söylemek geri alınamaz → hat dolunca cevap kendiliğinden verilir.
      if (_isFull) {
        _stopListening();
        _evaluate();
      }
    }
  }

  // --- Değerlendirme ----------------------------------------------------------

  void _evaluate() {
    if (_phase != _Phase.answering) return;
    // Doğruluk PERDE SINIFI üzerinden ölçülür: söylerken herkes kendi
    // oktavında söyler, tuş oktavı da hedefle aynı olmak zorunda değil.
    final matches = [
      for (var i = 0; i < _targets.length; i++)
        i < _attempt.length &&
            _attempt[i].pitchClass == _targets[i].pitchClass,
    ];
    for (var i = 0; i < matches.length; i++) {
      if (!matches[i] && i < _attempt.length) {
        // Dil-BAĞIMSIZ karıştırma anahtarı (nota adları çevrilmez).
        _mistakes.add('bass:${_targets[i].name}>${_attempt[i].name}');
      }
    }
    setState(() {
      _matches = matches;
      _phase = _Phase.answered;
      _lockProgress = 0;
      _candidateMidi = null;
      if (matches.every((m) => m)) _correct++;
    });
  }

  /// Doğru cevabı duyurur — yanlışta "doğrusu buymuş" anı olmadan öğrenme olmaz.
  Future<void> _playTargets() async {
    for (final note in _targets) {
      await widget.player.play(note);
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
    }
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) _playPhrase();
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
            en: 'Question ${_index + 1} / $total',
            tr: 'Soru ${_index + 1} / $total',
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
              const SizedBox(height: 14),
              PlayButton(
                onTap: _playPhrase,
                playing: _phase == _Phase.playing,
                size: 88,
                iconSize: 38,
              ),
              const SizedBox(height: 10),
              PhraseDots(
                count: _round.phrase.events.length,
                activeIndex: _eventIndex,
                semanticsLabel: t(en: 'Chords', tr: 'Akorlar'),
              ),
              const SizedBox(height: 14),
              _slotRow(theme),
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

  String _prompt() {
    if (_phase == _Phase.playing) return t(en: 'Listen…', tr: 'Dinle…');
    if (_phase == _Phase.answered) {
      return _isPerfect
          ? t(en: 'Exactly right!', tr: 'Tam isabet!')
          : t(en: 'Not quite — hear the answer', tr: 'Olmadı — doğrusunu dinle');
    }
    return switch (widget.lesson.drill) {
      HarmonyDrill.findBass => t(
        en: 'Find the lowest note you heard',
        tr: 'Duyduğun en pes sesi bul',
      ),
      HarmonyDrill.bassLine => t(
        en: 'Find every bass note, in order',
        tr: 'Bütün bas seslerini sırayla bul',
      ),
      _ => '',
    };
  }

  /// Cevap yuvaları: bulunan sesler (cevaptan sonra tek tek renklenir).
  Widget _slotRow(ThemeData theme) {
    final single = _targets.length == 1;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _targets.length; i++)
                Container(
                  width: single ? 74 : 60,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _slotColor(theme, i),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      i < _attempt.length ? _attempt[i].name : '?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _matches != null ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Yanlışta doğru cevap YAZIYLA da verilir: "neyi kaçırdım" sorusu
        // cevapsız kalırsa deneme öğrenmeye dönüşmez.
        if (_phase == _Phase.answered && !_isPerfect) ...[
          const SizedBox(height: 8),
          Text(
            t(
              en: 'It was: ${_targets.map((n) => n.name).join(' · ')}',
              tr: 'Doğrusu: ${_targets.map((n) => n.name).join(' · ')}',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Color _slotColor(ThemeData theme, int index) {
    final matches = _matches;
    if (matches != null) {
      return matches[index] ? AppColors.success : AppColors.danger;
    }
    if (index < _attempt.length) return AppColors.grapeSoft;
    return theme.colorScheme.surfaceContainerHighest;
  }

  Widget _padArea(ThemeData theme) {
    final pads = _pads;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final note in pads) ...[
              if (note != pads.first) const SizedBox(width: 6),
              Expanded(child: _pad(theme, note)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _attempt.isEmpty ? null : _undo,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(t(en: 'Undo', tr: 'Geri al')),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _isFull ? _evaluate : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _targets.length == 1
                        ? t(en: 'This one', tr: 'Bu ses')
                        : t(en: "That's it", tr: 'Hattım bu'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pad(ThemeData theme, Note note) {
    return Semantics(
      button: true,
      label: note.name,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering && !_isFull
              ? () => _tapPad(note)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                note.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _micActive ? Icons.mic_rounded : Icons.mic_off_rounded,
          size: 34,
          color: _micActive ? AppColors.grape : theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
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
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _resultArea(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _playTargets,
            icon: const Icon(Icons.volume_up_rounded, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t(en: 'Hear it', tr: 'Doğrusunu duy')),
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
    );
  }

  /// Cevap modu seçici — Eko Oyunu'yla ortak tercih (Ayarlar'da saklanır).
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
