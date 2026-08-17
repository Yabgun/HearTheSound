import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../core/echo.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/pitch_meter.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'chord_lesson.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKORDA SES ÜRETME (dersler 3, 4, 5) — track'in kalbi
//
// ESKİ "SÖYLE" ADIMININ SORUNU: akoru arpejleyerek söyletiyordu. Akor AYNI ANDA
// duyulan bir şeydir; onu tek tek söyletmek nesneyi melodiye çevirir. Üstelik
// eski ekran her hedef notayı söylemeden ÖNCE tek tek çalıyor ve ibreyi hedefe
// dikiyordu → egzersiz "şu tek sesi tuttur"a dönüşüyordu; akor kulağını hiç
// çalıştırmıyordu.
//
// YENİ KURAL: akorda söylenecek şey akorun TEK bir sesidir —
//   • ÜÇLÜ (ders 3): majörle minörü ayıran tek ses. Bulabilen kullanıcı rengin
//     sebebini ezberlemez, elinde tutar.
//   • TEPE (ders 4): en tiz ses. Çevrimler burada, "kaçıncı çevrim" diye
//     sordurmadan yaşanır.
// Arpej yalnızca ders 5'te dürüsttür: orada amaç taklit değil İNŞA — kök
// verilir, üç sesi kullanıcı kurar.
//
// PITCHMETER YALNIZCA "AKORU KUR"DA: orada hedef zaten söylenmiştir, ibre
// cevabı ele vermez, tam tersine NOKTA ATIŞI akort geri bildirimi verir.
// Üçlü/tepe bulmada hedef cevabın kendisidir — ibre gösterilse soru ölürdü;
// oralarda yalnızca "sesini sabit tut" halkası vardır.
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class ChordProducePage extends StatefulWidget {
  const ChordProducePage({
    super.key,
    required this.lesson,
    required this.player,
    required this.mode,
    required this.onModeChanged,
    required this.onComplete,
    this.range,
    this.questionCount,
  });

  final ChordLesson lesson;
  final NotePlayer player;
  final EchoInputMode mode;
  final ValueChanged<EchoInputMode> onModeChanged;
  final void Function(LessonResult result) onComplete;

  /// Kullanıcının ses aralığı — akor onun rahat oktavına taşınır (söyleme modu
  /// için şart; ibre de o zaman doğru oktavı gösterir).
  final VocalRange? range;

  final int? questionCount;

  @override
  State<ChordProducePage> createState() => _ChordProducePageState();
}

class _ChordProducePageState extends State<ChordProducePage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);
  final PitchService _pitch = PitchService();

  static const Duration _lockHold = Duration(milliseconds: 700);

  late Chord _chord;
  late MusicalPhrase _phrase;
  late List<Note> _targets;
  ChordQuality? _buildQuality;

  final List<Note> _attempt = [];
  List<bool>? _matches;

  _Phase _phase = _Phase.playing;
  int _index = 0;
  int _correct = 0;
  final List<String> _mistakes = [];

  // Söyleme modu durumu.
  bool _micActive = false;
  bool _permissionDenied = false;
  int? _candidateMidi;
  NoteReading? _reading;
  double _lockProgress = 0;
  DateTime? _lastTick;
  DateTime? _lockedAt;

  EchoInputMode get _mode =>
      _permissionDenied ? EchoInputMode.tap : widget.mode;

  int get _total => widget.questionCount ?? widget.lesson.questionCount;

  bool get _isFull => _attempt.length == _targets.length;

  bool get _isPerfect => _matches != null && _matches!.every((m) => m);

  /// Hedefin kullanıcıya SÖYLENDİĞİ ders — yalnızca burada ibre gösterilir.
  bool get _targetIsKnown => widget.lesson.drill == ChordDrill.buildChord;

  /// Şu an üretilmesi beklenen ses (ibre bunu gösterir).
  Note get _currentTarget =>
      _targets[_attempt.length.clamp(0, _targets.length - 1)];

  List<Note> get _pads => chromaticPadsFrom(_chord.root);

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
    final raw = generateChordProduce(drill: widget.lesson.drill, rng: _rng);
    // Akoru kullanıcının rahat oktavına taşı; hedefler ve çalınan ses aynı
    // kaymayı alır ki ilişkiler bozulmasın.
    final offset = octaveOffsetFor(
      raw.chord.notes.map((n) => n.midi),
      widget.range,
    );
    _chord = Chord(
      Note(raw.chord.root.midi + offset),
      raw.chord.quality,
      inversion: raw.chord.inversion,
    );
    _phrase = raw.phrase.transposedBy(offset);
    _targets = [for (final note in raw.targets) Note(note.midi + offset)];
    _buildQuality = raw.buildQuality;

    _attempt.clear();
    _matches = null;
    _phase = _Phase.playing;
    _candidateMidi = null;
    _reading = null;
    _lockProgress = 0;
  }

  Future<void> _playPhrase() async {
    if (_micActive) await _stopListening();
    setState(() {
      if (_phase != _Phase.answered) _phase = _Phase.playing;
    });
    await _phrasePlayer.play(_phrase);
    if (!mounted) return;
    setState(() {
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
      setState(() {
        _reading = null;
        _lockProgress = (_lockProgress - dt).clamp(0.0, 1.0);
      });
      return;
    }

    setState(() {
      _reading = reading;
      if (_candidateMidi == reading.note.midi) {
        _lockProgress = (_lockProgress + dt).clamp(0.0, 1.0);
      } else {
        _candidateMidi = reading.note.midi;
        _lockProgress = 0;
      }
    });

    if (_lockProgress >= 1.0 && _candidateMidi != null) {
      _lockedAt = now;
      setState(() {
        _attempt.add(Note(_candidateMidi!));
        _lockProgress = 0;
        _candidateMidi = null;
      });
      // Söylemek geri alınamaz → dolunca cevap kendiliğinden verilir.
      if (_isFull) {
        _stopListening();
        _evaluate();
      }
    }
  }

  // --- Değerlendirme ----------------------------------------------------------

  void _evaluate() {
    if (_phase != _Phase.answering) return;
    // Perde SINIFI üzerinden: söylerken herkes kendi oktavında söyler.
    final matches = [
      for (var i = 0; i < _targets.length; i++)
        i < _attempt.length &&
            _attempt[i].pitchClass == _targets[i].pitchClass,
    ];
    for (var i = 0; i < matches.length; i++) {
      if (!matches[i] && i < _attempt.length) {
        _mistakes.add('chordNote:${_targets[i].name}>${_attempt[i].name}');
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
            en: 'Chord ${_index + 1} / $total',
            tr: 'Akor ${_index + 1} / $total',
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
          // Kaydırılabilir gövde + sabit alt eylemler: 12 kromatik tuş + yuvalar
          // + ibre büyük yazı tipinde ekrana sığmayabilir.
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
                      PlayButton(
                        onTap: _playPhrase,
                        playing: _phase == _Phase.playing,
                        size: 80,
                        iconSize: 34,
                      ),
                      const SizedBox(height: 14),
                      _slotRow(theme),
                      const SizedBox(height: 12),
                      if (_phase != _Phase.answered) ...[
                        if (_mode == EchoInputMode.tap)
                          _padGrid(theme)
                        else
                          _singArea(theme),
                        const SizedBox(height: 10),
                        _modeToggle(theme),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _actions(theme),
              const SizedBox(height: 10),
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
      ChordDrill.findThird => t(
        en: 'Find the note that gives it that colour',
        tr: 'Ona o rengi veren sesi bul',
      ),
      ChordDrill.findTop => t(
        en: 'Find the highest note in the chord',
        tr: 'Akorun en tiz sesini bul',
      ),
      ChordDrill.buildChord => _buildQuality == ChordQuality.minor
          ? t(
              en: 'Build a MINOR chord on ${_chord.root.label}',
              tr: '${_chord.root.label} üstüne MİNÖR akoru kur',
            )
          : t(
              en: 'Build a MAJOR chord on ${_chord.root.label}',
              tr: '${_chord.root.label} üstüne MAJÖR akoru kur',
            ),
      _ => '',
    };
  }

  /// Cevap yuvaları + yanlışta doğru cevabın yazısı.
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
                  width: single ? 84 : 70,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _slotColor(theme, i),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i == _attempt.length && _matches == null
                          ? AppColors.grape
                          : theme.colorScheme.outline.withValues(alpha: 0.5),
                      width: i == _attempt.length && _matches == null ? 2.5 : 1,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      i < _attempt.length ? _attempt[i].label : '?',
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
        if (_phase == _Phase.answered && !_isPerfect) ...[
          const SizedBox(height: 8),
          Text(
            t(
              en: 'It was: ${_targets.map((n) => n.label).join(' · ')}',
              tr: 'Doğrusu: ${_targets.map((n) => n.label).join(' · ')}',
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

  /// Kromatik tuş sırası — 12 ses, iki satırda altışar. Diyatonik bir havuz
  /// yetmezdi: minör üçlü çoğu tonda dizinin dışında kalır.
  Widget _padGrid(ThemeData theme) {
    final pads = _pads;
    const spacing = 6.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing * 5) / 6;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final note in pads)
              SizedBox(width: width, child: _pad(theme, note)),
          ],
        );
      },
    );
  }

  Widget _pad(ThemeData theme, Note note) {
    // Akorun kendi sesleri hafifçe belirgin: "nokta atışı" demek kör atış
    // demek değil — kullanıcı aradığı sesin çevresini görebilmeli.
    final isChordTone = _chord.notes.any(
      (n) => n.pitchClass == note.pitchClass,
    );
    return Semantics(
      button: true,
      label: note.label,
      child: Material(
        color: isChordTone && _phase == _Phase.answered
            ? AppColors.grapeSoft
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering && !_isFull
              ? () => _tapPad(note)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                note.label,
                style: theme.textTheme.titleSmall?.copyWith(
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
          size: 32,
          color: _micActive ? AppColors.grape : theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
        if (_targetIsKnown)
          // Hedef zaten söylendi → ibre cevabı ele vermez, NOKTA ATIŞI akort
          // geri bildirimi verir. Kullanıcının en net bulduğu gösterge bu.
          PitchMeter(
            target: _currentTarget,
            reading: _reading,
            active: _micActive,
          )
        else
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

  Widget _actions(ThemeData theme) {
    if (_phase == _Phase.answered) {
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
    return Row(
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
                    : t(en: "That's my chord", tr: 'Akorum bu'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
