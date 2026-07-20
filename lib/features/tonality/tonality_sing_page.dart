import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/pitch_meter.dart';
import '../calibration/reach_badge.dart';
import 'tonality_lesson.dart';

// -----------------------------------------------------------------------------
// DERECEYİ SÖYLE — tonik referansından sonra hedef dereceyi üret
//
// Kullanıcı önce tonik "ev" notasını ve hedef dereceyi duyar; sonra hedef dereceyi
// kendi sesiyle söyler. Eşleşme tam MIDI/oktav üzerinden yapılır.
// -----------------------------------------------------------------------------

class TonalitySingPage extends StatefulWidget {
  const TonalitySingPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.range,
  });

  final List<ScaleDegree> pool;
  final NotePlayer player;
  final VoidCallback onComplete;
  final VocalRange? range;

  @override
  State<TonalitySingPage> createState() => _TonalitySingPageState();
}

class _TonalitySingPageState extends State<TonalitySingPage> {
  static const Duration _holdTarget = Duration(seconds: 3);
  static const Color _green = AppColors.success;

  final PitchService _pitch = PitchService();

  late final List<ScaleDegree> _toSing = _pick();
  late final int _lessonOctaveOffset = _computeLessonOffset();

  int _index = 0;
  int _manualOctaveShift = 0;
  double _hold = 0;
  DateTime? _lastTick;
  NoteReading? _reading;
  bool _micActive = false;
  bool _celebrating = false;
  bool _busy = false;
  bool _permissionDenied = false;

  late Note _tonic;
  late Note _target;

  ScaleDegree get _degree => _toSing[_index];

  List<ScaleDegree> _pick() {
    final shuffled = List<ScaleDegree>.from(widget.pool)..shuffle();
    final count = widget.pool.length <= 4 ? widget.pool.length : 4;
    return shuffled.take(count).toList();
  }

  int _computeLessonOffset() {
    final c4 = Note.fromName('C', 4);
    final targets = [
      c4.midi,
      for (final degree in widget.pool) c4.midi + degree.semitonesFromTonic,
    ];
    return octaveOffsetFor(targets, widget.range);
  }

  @override
  void initState() {
    super.initState();
    _prepareCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginDegree());
  }

  /// Hedefleri ilk build'den önce hazırlar; böylece geçici late-field hatası olmaz.
  void _prepareCurrent() {
    final baseTonic =
        Note.fromName('C', 4).midi + _lessonOctaveOffset + _manualOctaveShift;
    _tonic = Note(baseTonic);
    _target = Note(baseTonic + _degree.semitonesFromTonic);
  }

  Future<void> _beginDegree() async {
    _prepareCurrent();
    setState(() {
      _micActive = false;
      _celebrating = false;
      _hold = 0;
      _reading = null;
      _busy = true;
    });
    await _playReference();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _playReference() async {
    await widget.player.play(_tonic);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(_target);
  }

  Future<void> _replay() async {
    if (_micActive) await _stopListening();
    setState(() => _busy = true);
    await _playReference();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _shiftOctave(int delta) async {
    final next = _manualOctaveShift + delta;
    final nextTonic = Note.fromName('C', 4).midi + _lessonOctaveOffset + next;
    final nextTarget = nextTonic + _degree.semitonesFromTonic;
    if (nextTonic < 24 || nextTarget > 96) return;
    if (_micActive) await _stopListening();
    if (!mounted) return;
    setState(() => _manualOctaveShift = next);
    _beginDegree();
  }

  Future<void> _startListening() async {
    await widget.player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _lastTick = null;
    if (mounted) {
      setState(() {
        _micActive = true;
        _hold = 0;
        _reading = null;
      });
    }
  }

  Future<void> _stopListening() async {
    await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
  }

  void _onReading(NoteReading? r) {
    if (_celebrating || !_micActive || !mounted) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds /
              _holdTarget.inMilliseconds;
    _lastTick = now;
    final match = r != null && r.note.midi == _target.midi;
    setState(() {
      _reading = r;
      _hold = (_hold + (match ? dt : -dt * 0.6)).clamp(0.0, 1.0);
    });
    if (_hold >= 1.0) _succeed();
  }

  Future<void> _succeed() async {
    if (_celebrating) return;
    setState(() {
      _celebrating = true;
      _micActive = false;
    });
    await _pitch.stop();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _advance();
  }

  void _advance() {
    if (!mounted) return;
    if (_index + 1 >= _toSing.length) {
      widget.onComplete();
    } else {
      setState(() => _index++);
      _beginDegree();
    }
  }

  Future<void> _skip() async {
    await _pitch.stop();
    _advance();
  }

  @override
  void dispose() {
    _pitch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_permissionDenied) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t(en: 'Sing the Degree', tr: 'Dereceyi Söyle')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t(
                    en: 'This step needs microphone permission.',
                    tr: 'Bu adım için mikrofon izni gerekli.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _permissionDenied = false);
                    _startListening();
                  },
                  child: Text(
                    t(en: 'Allow and try again', tr: 'İzin ver ve tekrar dene'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onComplete,
                  child: Text(t(en: 'Skip this step', tr: 'Bu adımı atla')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final exact = _reading != null && _reading!.note.midi == _target.midi;
    final samePitchClass =
        _reading != null && _reading!.note.pitchClass == _target.pitchClass;
    final ringColor = (_celebrating || exact)
        ? _green
        : theme.colorScheme.primary;

    final String status;
    if (_celebrating) {
      status = t(en: 'Correct! ✓', tr: 'Doğru! ✓');
    } else if (_busy) {
      status = t(
        en: 'listen: ${_tonic.label} → ${_target.label}',
        tr: 'dinle: ${_tonic.label} → ${_target.label}',
      );
    } else if (!_micActive) {
      status = t(
        en: 'You heard home. Now sing ${_degree.label}',
        tr: 'Evi duydun. Şimdi ${_degree.label} notasını söyle',
      );
    } else if (exact) {
      status = t(en: 'spot on — hold it!', tr: 'tam — böyle tut!');
    } else if (samePitchClass) {
      status = _reading!.note.midi < _target.midi
          ? t(
              en: 'right note — sing an octave higher',
              tr: 'doğru nota — bir oktav tiz söyle',
            )
          : t(
              en: 'right note — sing an octave lower',
              tr: 'doğru nota — bir oktav pes söyle',
            );
    } else if (_reading != null) {
      status = t(
        en: 'I hear: ${_reading!.note.label}',
        tr: 'duyduğum: ${_reading!.note.label}',
      );
    } else {
      status = t(en: 'let me hear you…', tr: 'sesini duyayım…');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Sing the Degree · ${_index + 1}/${_toSing.length}',
            tr: 'Dereceyi Söyle · ${_index + 1}/${_toSing.length}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(t(en: 'Skip', tr: 'Geç')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                '${_degree.label} · ${_degree.name}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  en: 'Tonic: ${_tonic.label}  →  target: ${_target.label}',
                  tr: 'Tonik: ${_tonic.label}  →  hedef: ${_target.label}',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _replay,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(
                  t(en: 'Hear tonic → target', tr: 'Tonik → hedef dinle'),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: _micActive ? null : () => _shiftOctave(-12),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    tooltip: t(en: 'One octave lower', tr: 'Bir oktav pes'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      t(en: 'octave', tr: 'oktav'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _micActive ? null : () => _shiftOctave(12),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    tooltip: t(en: 'One octave higher', tr: 'Bir oktav tiz'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ReachBadge(target: _target, range: widget.range),
              const Spacer(),
              SizedBox(
                width: 156,
                height: 156,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 156,
                      height: 156,
                      child: CircularProgressIndicator(
                        value: _hold,
                        strokeWidth: 10,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(en: 'sing', tr: 'söyle'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _target.label,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ringColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                status,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: (_celebrating || exact)
                      ? _green
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // Canlı perde ibresi: sesin hedefe göre tam nerede olduğunu gösterir.
              PitchMeter(
                target: _target,
                reading: _reading,
                active: _micActive,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: _micActive
                    ? OutlinedButton.icon(
                        onPressed: _celebrating ? null : _stopListening,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(t(en: 'Stop', tr: 'Durdur')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: (_celebrating || _busy)
                            ? null
                            : _startListening,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(t(en: 'Sing', tr: 'Söyle')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
