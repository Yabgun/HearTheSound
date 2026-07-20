import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/pitch_meter.dart';
import '../calibration/reach_badge.dart';

// -----------------------------------------------------------------------------
// ARALIĞI SÖYLE — "Söyle" adımı
//
// Her aralık için önce kök + üst nota melodik çalınır (referans). Sonra kullanıcı
// ÜST NOTAYI söyler; perde tespiti tam oktav eşleşmesini doğrular. Kök+üst çifti,
// ikisi de rahat söylenebilsin diye kullanıcının aralığına transpoze edilir.
// -----------------------------------------------------------------------------

class IntervalSingPage extends StatefulWidget {
  const IntervalSingPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.range,
  });

  final List<MusicInterval> pool;
  final NotePlayer player;
  final VoidCallback onComplete;
  final VocalRange? range;

  @override
  State<IntervalSingPage> createState() => _IntervalSingPageState();
}

class _IntervalSingPageState extends State<IntervalSingPage> {
  static const Duration _holdTarget = Duration(seconds: 3);
  static const Color _green = AppColors.success;

  final PitchService _pitch = PitchService();

  late final List<MusicInterval> _toSing = _pick();
  int _index = 0;
  double _hold = 0;
  DateTime? _lastTick;
  NoteReading? _reading;
  bool _micActive = false;
  bool _celebrating = false;
  bool _busy = false;
  bool _permissionDenied = false;

  late Note _root;
  late Note _top;

  List<MusicInterval> _pick() {
    final shuffled = List<MusicInterval>.from(widget.pool)..shuffle();
    final count = widget.pool.length <= 4 ? widget.pool.length : 4;
    return shuffled.take(count).toList();
  }

  MusicInterval get _interval => _toSing[_index];

  @override
  void initState() {
    super.initState();
    // _root/_top İLK build'den önce hazır olmalı — yoksa late alanlar
    // atanmadan build erişir ve bir kare kırmızı hata ekranı çakar.
    _prepareCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginInterval());
  }

  /// Geçerli aralığın kök + üst çiftini kullanıcının ses aralığına transpoze
  /// ederek hesaplar (senkron — çizimden önce hazır olmalı).
  void _prepareCurrent() {
    final c4 = Note.fromName('C', 4);
    final pair = transposeForVoice([
      c4,
      Note(c4.midi + _interval.semitones),
    ], widget.range);
    _root = pair[0];
    _top = pair[1];
  }

  Future<void> _beginInterval() async {
    _prepareCurrent();
    setState(() {
      _micActive = false;
      _celebrating = false;
      _hold = 0;
      _reading = null;
      _busy = true;
    });
    await _playMelodic();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _playMelodic() async {
    await widget.player.play(_root);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await widget.player.play(_top);
  }

  Future<void> _replay() async {
    if (_micActive) await _stopListening();
    setState(() => _busy = true);
    await _playMelodic();
    if (mounted) setState(() => _busy = false);
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
    final match = r != null && r.note.midi == _top.midi;
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
      _beginInterval();
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
          title: Text(t(en: 'Sing the Interval', tr: 'Aralığı Söyle')),
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

    final exact = _reading != null && _reading!.note.midi == _top.midi;
    final samePitchClass =
        _reading != null && _reading!.note.pitchClass == _top.pitchClass;
    final ringColor = (_celebrating || exact)
        ? _green
        : theme.colorScheme.primary;

    final String status;
    if (_celebrating) {
      status = t(en: 'Correct! ✓', tr: 'Doğru! ✓');
    } else if (_busy) {
      status = t(
        en: 'listen: ${_root.label} → ${_top.label}',
        tr: 'dinle: ${_root.label} → ${_top.label}',
      );
    } else if (!_micActive) {
      status = t(
        en: 'You heard the root. Now sing the top note 👇',
        tr: 'Kökü duydun. Şimdi üst notayı söyle 👇',
      );
    } else if (exact) {
      status = t(en: 'spot on — hold it!', tr: 'tam — böyle tut!');
    } else if (samePitchClass) {
      status = _reading!.note.midi < _top.midi
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
            en: 'Sing the Interval · ${_index + 1}/${_toSing.length}',
            tr: 'Aralığı Söyle · ${_index + 1}/${_toSing.length}',
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
                _interval.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t(en: 'SING THIS NOTE', tr: 'BU NOTAYI SÖYLE'),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _top.label,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _replay,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(t(en: 'Listen again', tr: 'Tekrar dinle')),
              ),
              const SizedBox(height: 10),
              ReachBadge(target: _top, range: widget.range),
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
                    Icon(
                      _celebrating ? Icons.check_rounded : Icons.mic_rounded,
                      size: 56,
                      color: _celebrating
                          ? _green
                          : (_micActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline),
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
              // Aralıkta hedef, söylenmekte olan ÜST notadır.
              PitchMeter(target: _top, reading: _reading, active: _micActive),
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
