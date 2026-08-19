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
import '../../ui/note_names_sheet.dart';
import '../../ui/pitch_meter.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'chord_lesson.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKORU KUR — track'in kalbi (dersler 3, 4, 5, 7)
//
// TEK KAZANIM: duyduğun akoru ÇALABİLMEK. Kullanıcı akoru ses ses kurar; doğru
// kurunca akor ÇALINIR — "işte, ben çaldım" anı. Amaç görevin içindedir.
//
// ⚠️ CİHAZ GERİ BİLDİRİMİ (2026-08-17) VE KARŞILIKLARI:
//  • "Majör akorun nasıl kurulduğunu kullanıcı bilmiyor" → akorun TARİFİ artık
//    ekranda: "kökten 4 tuş, sonra 3 tuş". Kromatik tuş sırasında bu SAYILABİLİR
//    bir talimattır; tuşlar kökten uzaklıklarını (+4 gibi) yazar. Tanım değil
//    tarif veriyoruz.
//  • "Gergin/askıda ne demek bilmiyor" → o akorları önce KURAR (3+3 ve 4+4),
//    adını rozette alır. Kurduğu şeyin adını öğrenmek, adını duyup aramaktan
//    farklıdır.
//  • İlk kurma dersi REHBERLİdir: renk ekranda yazar ve sıradaki doğru tuş
//    işaretlenir. Sonraki derste rehber kalkar, renk kulakla bulunur.
//
// PITCHMETER: hedefin kullanıcıya SÖYLENDİĞİ derslerde (renk ekranda yazarken)
// görünür — orada ibre cevabı ele vermez, nokta atışı akort geri bildirimi
// verir. Rengin kulakla bulunduğu derslerde ibre YOKTUR; olsaydı doğru sesi
// göstererek soruyu öldürürdü.
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

  /// Kullanıcının ses aralığı — akor onun rahat oktavına taşınır.
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
  late bool _colorIsHeard;

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

  /// Renk ekranda yazıyorsa hedef bilinir → ibre gösterilebilir.
  bool get _targetIsKnown => !_colorIsHeard;

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
    final raw = generateChordProduce(
      qualities: widget.lesson.qualities,
      colorIsHeard: widget.lesson.colorIsHeard,
      rng: _rng,
    );
    // Akoru kullanıcının rahat oktavına taşı; hedefler ve çalınan ses aynı
    // kaymayı alır ki ilişkiler bozulmasın.
    final offset = octaveOffsetFor(
      raw.chord.notes.map((n) => n.midi),
      widget.range,
    );
    _chord = Chord(Note(raw.chord.root.midi + offset), raw.chord.quality);
    _phrase = raw.phrase.transposedBy(offset);
    _targets = [for (final note in raw.targets) Note(note.midi + offset)];
    _colorIsHeard = raw.colorIsHeard;

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
    await widget.player.play(note);
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

  Future<void> _evaluate() async {
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
    final perfect = matches.every((m) => m);
    setState(() {
      _matches = matches;
      _phase = _Phase.answered;
      _lockProgress = 0;
      _candidateMidi = null;
      if (perfect) _correct++;
    });
    // ÖDÜL: doğru kurulan akor bir bütün olarak çalar. Kullanıcı ses ses
    // dizdiği şeyin AKOR olduğunu ancak böyle duyar — "işte, ben çaldım".
    if (perfect) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) await widget.player.playChord(_chord.notes);
    }
  }

  /// Doğru cevabı duyurur: önce tek tek, sonra akor olarak.
  Future<void> _playTargets() async {
    for (final note in _targets) {
      await widget.player.play(note);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
    }
    await widget.player.playChord(_chord.notes);
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
          // Akoru KURARKEN tuşlar nota adı gösteriyor (kök C4, +4 tuş…).
          const NoteNamesButton(),
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
                      const SizedBox(height: 10),
                      PlayButton(
                        onTap: _playPhrase,
                        playing: _phase == _Phase.playing,
                        size: 72,
                        iconSize: 30,
                      ),
                      const SizedBox(height: 12),
                      _recipeCard(theme),
                      const SizedBox(height: 12),
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
          ? t(en: 'That is the chord!', tr: 'İşte akor bu!')
          : t(en: 'Not quite — hear the answer', tr: 'Olmadı — doğrusunu dinle');
    }
    if (_colorIsHeard) {
      return t(
        en: 'Play back the chord you just heard',
        tr: 'Az önce duyduğun akoru sen çal',
      );
    }
    return t(
      en: 'Build this chord on ${_chord.root.label}',
      tr: '${_chord.root.label} üstüne bu akoru kur',
    );
  }

  /// AKORUN TARİFİ — dersin öğrettiği asıl şey.
  ///
  /// "Majör akor 1-3-5'tir" bir TANIMdır; kullanıcı onunla hiçbir şey yapamaz.
  /// "Kökten 4 tuş, sonra 3 tuş" bir TARİFtir — kromatik tuş sırasında
  /// sayılarak uygulanır. Rengin kulakla bulunduğu derslerde tüm tarifler
  /// listelenir (hangisini duyduğuna kullanıcı karar verir); söylendiği
  /// derslerde yalnızca kurulacak olan gösterilir.
  Widget _recipeCard(ThemeData theme) {
    final qualities = _colorIsHeard
        ? widget.lesson.qualities
        : [_chord.quality];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.grapeSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(en: 'Chord recipe', tr: 'Akorun tarifi'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.colors.grape,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final quality in qualities)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  t(
                    en: '${chordColorName(quality)}: '
                        'root → ${chordRecipe(quality).map((s) => '+$s').join(' → ')} keys',
                    tr: '${chordColorName(quality)}: '
                        'kök → ${chordRecipe(quality).map((s) => '+$s').join(' → ')} tuş',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slotRow(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _targets.length; i++)
                Container(
                  width: 70,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _slotColor(theme, i),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i == _attempt.length && _matches == null
                          ? context.colors.grape
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
                        color: _slotTextColor(i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_phase == _Phase.answered) ...[
          const SizedBox(height: 8),
          Text(
            _isPerfect
                ? t(
                    en: 'You played ${_chord.root.name} '
                        '${chordColorName(_chord.quality)}',
                    tr: '${_chord.root.name} '
                        '${chordColorName(_chord.quality)} çaldın',
                  )
                : t(
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


  /// Yuva ETİKETİNİN rengi — zeminiyle çift gider (bkz. _slotColor).
  /// Dolgu success/danger olduğunda etiket paletten gelmeli: koyu temada dolgu
  /// açık yeşile/kırmızıya döner ve üstünde beyaz yazı okunmaz.
  Color _slotTextColor(int index) {
    final matches = _matches;
    if (matches == null) return context.colors.ink;
    return matches[index] ? context.colors.onSuccess : context.colors.onDanger;
  }

  Color _slotColor(ThemeData theme, int index) {
    final matches = _matches;
    if (matches != null) {
      return matches[index] ? context.colors.success : context.colors.danger;
    }
    if (index < _attempt.length) return context.colors.grapeSoft;
    return theme.colorScheme.surfaceContainerHighest;
  }

  /// Kromatik tuş sırası. Her tuş KÖKTEN UZAKLIĞINI yazar (+4 gibi) — tarif
  /// böylece ekranda uygulanabilir hale gelir; sayma işi kullanıcıyı yormaz,
  /// öğrenilen şey zaten hangi rengin kurulacağıdır.
  Widget _padGrid(ThemeData theme) {
    final pads = _pads;
    const spacing = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing * 6) / 7;
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
    final distance = note.midi - _chord.root.midi;
    final isRoot = distance == 0;
    // REHBERLİ ders: sıradaki doğru tuş işaretlenir. Tarif ilk kez burada
    // uygulanıyor; kullanıcıyı boşlukta bırakmak öğretmek değil sınamaktır.
    final isHint =
        widget.lesson.guided &&
        _phase == _Phase.answering &&
        !_isFull &&
        note.midi == _currentTarget.midi;

    return Semantics(
      button: true,
      label: note.label,
      child: Material(
        color: isHint
            ? context.colors.grapeSoft
            : isRoot
            ? context.colors.wash
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering && !_isFull
              ? () => _tapPad(note)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isHint
                  ? Border.all(color: context.colors.grape, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    note.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isRoot ? t(en: 'root', tr: 'kök') : '+$distance',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
          color: _micActive ? context.colors.grape : theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
        if (_targetIsKnown)
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
                backgroundColor: context.colors.wash,
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
                child: Text(t(en: 'Hear it', tr: 'Akoru duy')),
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
              child: Text(t(en: 'Play it', tr: 'Akorum bu')),
            ),
          ),
        ),
      ],
    );
  }
}
