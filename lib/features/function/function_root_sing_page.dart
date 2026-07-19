import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/pitch_meter.dart';
import '../calibration/reach_badge.dart';
import 'function_lesson.dart';

// -----------------------------------------------------------------------------
// DERECENİN KÖKÜNÜ SÖYLE — işlevi sesle kurma
//
// Kullanıcı tonik ve hedef akoru duyduktan sonra akorun kök notasını söyler.
// Bu, işlevi yalnızca dinlenen bir etiket olmaktan çıkarıp "hangi dereceden
// başladım?" hissine bağlar. Eşleşme kasıtlı olarak tam MIDI/oktavdır.
// -----------------------------------------------------------------------------

class FunctionRootSingPage extends StatefulWidget {
  const FunctionRootSingPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.range,
  });

  final List<DegreeChord> pool;
  final NotePlayer player;
  final VoidCallback onComplete;
  final VocalRange? range;

  @override
  State<FunctionRootSingPage> createState() => _FunctionRootSingPageState();
}

class _FunctionRootSingPageState extends State<FunctionRootSingPage> {
  static const Duration _holdTarget = Duration(seconds: 3);
  static const Color _green = AppColors.success;

  final PitchService _pitch = PitchService();
  final Random _random = Random();

  late final List<DegreeChord> _rounds = _pickRounds();
  int _index = 0;
  double _hold = 0;
  DateTime? _lastTick;
  NoteReading? _reading;
  bool _micActive = false;
  bool _busy = false;
  bool _celebrating = false;
  bool _permissionDenied = false;

  DegreeChord get _degree => _rounds[_index];
  Note get _target => _degree.chord.root;

  List<DegreeChord> _pickRounds() {
    final shuffled = List<DegreeChord>.from(widget.pool)..shuffle(_random);
    return shuffled.take(min(4, shuffled.length)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentChord());
  }

  /// Önce ev, sonra hedef akor ve en sonda onun kökü duyulur. Kök sesi
  /// rehberdir; asıl amaç kullanıcının onu kendi sesiyle tam oktavda üretmesi.
  Future<void> _presentChord() async {
    setState(() {
      _micActive = false;
      _busy = true;
      _celebrating = false;
      _hold = 0;
      _reading = null;
    });
    await widget.player.playChord(tonicForDegrees(widget.pool).notes);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await widget.player.playChord(_degree.chord.notes);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await widget.player.play(_target);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _startListening() async {
    await widget.player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
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

  void _onReading(NoteReading? reading) {
    if (_celebrating || !_micActive || !mounted) return;
    final now = DateTime.now();
    final elapsed = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds /
              _holdTarget.inMilliseconds;
    _lastTick = now;
    final match = reading != null && reading.note.midi == _target.midi;
    setState(() {
      _reading = reading;
      _hold = (_hold + (match ? elapsed : -elapsed * 0.6)).clamp(0.0, 1.0);
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
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_index + 1 >= _rounds.length) {
      widget.onComplete();
    } else {
      setState(() => _index++);
      _presentChord();
    }
  }

  Future<void> _skip() async {
    await _pitch.stop();
    if (!mounted) return;
    if (_index + 1 >= _rounds.length) {
      widget.onComplete();
    } else {
      setState(() => _index++);
      _presentChord();
    }
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
          title: Text(t(en: 'Sing the Root', tr: 'Kökü Söyle')),
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
                  onPressed: _skip,
                  child: Text(t(en: 'Skip this round', tr: 'Bu turu geç')),
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
      status = t(
        en: 'Correct! The root locked in. ✓',
        tr: 'Doğru! Kök yerine oturdu. ✓',
      );
    } else if (_busy) {
      status = t(
        en: 'listen: home → chord → root',
        tr: 'dinle: ev → akor → kök',
      );
    } else if (!_micActive) {
      status = t(
        en: 'Sing the root of the ${_degree.roman} chord',
        tr: '${_degree.roman} akorunun kökünü söyle',
      );
    } else if (exact) {
      status = t(en: 'spot on — hold it! 🎯', tr: 'tam — böyle tut! 🎯');
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
            en: 'Sing the Root · ${_index + 1}/${_rounds.length}',
            tr: 'Kökü Söyle · ${_index + 1}/${_rounds.length}',
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
                '${_degree.roman} · ${_degree.chord.label}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_degree.function.label}: ${_degree.roleHint}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _presentChord,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(
                  t(
                    en: 'Hear home → chord → root',
                    tr: 'Ev → akor → kök dinle',
                  ),
                ),
              ),
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
                          t(en: 'ROOT', tr: 'KÖK'),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          _target.label,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: ringColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ReachBadge(target: _target, range: widget.range),
              const SizedBox(height: 8),
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
                        onPressed: (_busy || _celebrating)
                            ? null
                            : _startListening,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(
                          t(
                            en: 'Sing ${_target.label}',
                            tr: '${_target.label} notasını söyle',
                          ),
                        ),
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
