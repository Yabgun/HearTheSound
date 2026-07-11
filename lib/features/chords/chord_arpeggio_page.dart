import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/chord.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// AKORU SÖYLE (arpej) — "Söyle" adımı
//
// Akor referans çalınır; sonra kullanıcı notaları SIRAYLA söyler. Her nota için
// önce O NOTA tek tek çalınır (ne söyleyeceğini duysun), sonra mikrofon dinler.
// Baklalara dokunarak da her notayı istediğinde dinleyebilir.
// -----------------------------------------------------------------------------

enum _NoteState { done, current, pending }

class ChordArpeggioPage extends StatefulWidget {
  const ChordArpeggioPage({
    super.key,
    required this.chords,
    required this.player,
    required this.onComplete,
  });

  final List<Chord> chords;
  final NotePlayer player;
  final VoidCallback onComplete;

  @override
  State<ChordArpeggioPage> createState() => _ChordArpeggioPageState();
}

class _ChordArpeggioPageState extends State<ChordArpeggioPage> {
  static const Duration _holdTarget = Duration(seconds: 3);

  final PitchService _pitch = PitchService();
  int _chordIndex = 0;
  int _noteIndex = 0;
  double _hold = 0;
  DateTime? _lastTick;
  NoteReading? _reading;
  bool _micActive = false;
  bool _hearing = false; // hedef nota referansı çalınıyor
  bool _celebrating = false;
  bool _permissionDenied = false;

  Chord get _chord => widget.chords[_chordIndex];
  Note get _target => _chord.notes[_noteIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginChord());
  }

  /// Yeni akora girişte tüm akoru duyur (mikrofon başlamaz).
  Future<void> _beginChord() async {
    setState(() {
      _noteIndex = 0;
      _micActive = false;
      _hearing = false;
      _celebrating = false;
      _hold = 0;
      _reading = null;
    });
    await widget.player.playChord(_chord.notes);
  }

  Future<void> _replayChord() async {
    if (_micActive) await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
    await widget.player.playChord(_chord.notes);
  }

  /// Bir notaya dokununca (bakla) o notayı tek tek çal — referans için.
  Future<void> _hearNote(Note note) async {
    if (_micActive) return; // dinlerken bozmayalım
    await widget.player.play(note);
  }

  /// Hedef notayı önce ÇAL (duy), sonra mikrofonu başlat (söyle).
  Future<void> _presentTarget() async {
    await widget.player.stop();
    if (!mounted) return;
    setState(() {
      _micActive = false;
      _hearing = true;
      _hold = 0;
      _reading = null;
      _celebrating = false;
    });
    await widget.player.play(_target);
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted || !_hearing) return; // arada durdurulduysa çık
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _lastTick = null;
    if (mounted) {
      setState(() {
        _hearing = false;
        _micActive = true;
      });
    }
  }

  Future<void> _stopListening() async {
    await _pitch.stop();
    if (mounted) {
      setState(() {
        _micActive = false;
        _hearing = false;
      });
    }
  }

  void _onReading(NoteReading? r) {
    if (_celebrating || !_micActive || !mounted) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds / _holdTarget.inMilliseconds;
    _lastTick = now;
    // Tam oktav eşleşmesi (E4 = E4; farklı oktav kabul edilmez).
    final match = r != null && r.note.midi == _target.midi;
    setState(() {
      _reading = r;
      _hold = (_hold + (match ? dt : -dt * 0.6)).clamp(0.0, 1.0);
    });
    if (_hold >= 1.0) _noteSucceed();
  }

  Future<void> _noteSucceed() async {
    if (_celebrating) return;
    setState(() => _celebrating = true);
    await _pitch.stop();
    if (!mounted) return;
    setState(() => _micActive = false);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    if (_noteIndex + 1 < _chord.notes.length) {
      setState(() {
        _noteIndex++;
        _celebrating = false;
      });
      _presentTarget(); // sıradaki notayı duyur, sonra dinle
    } else {
      setState(() => _celebrating = false);
      _nextChordOrDone();
    }
  }

  void _nextChordOrDone() {
    if (_chordIndex + 1 < widget.chords.length) {
      setState(() => _chordIndex++);
      _beginChord();
    } else {
      widget.onComplete();
    }
  }

  Future<void> _skip() async {
    await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
    _nextChordOrDone();
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
        appBar: AppBar(title: const Text('Akoru Söyle')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bu adım için mikrofon izni gerekli.',
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _permissionDenied = false);
                    _presentTarget();
                  },
                  child: const Text('İzin ver ve tekrar dene'),
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Bu adımı atla')),
              ],
            ),
          ),
        ),
      );
    }

    final exact = _reading != null && _reading!.note.midi == _target.midi;
    final samePitchClass =
        _reading != null && _reading!.note.pitchClass == _target.pitchClass;
    const green = Color(0xFF56C271);
    final ringColor = (_celebrating || exact) ? green : theme.colorScheme.primary;

    final String status;
    if (_celebrating) {
      status = 'Doğru! ✓';
    } else if (_hearing) {
      status = 'dinle: ${_target.label} …';
    } else if (!_micActive) {
      status = 'Notaları dinle, sonra sırayla söyle 👇';
    } else if (exact) {
      status = 'tam — böyle tut! 🎯';
    } else if (samePitchClass) {
      status = _reading!.note.midi < _target.midi
          ? 'doğru nota — bir oktav tiz söyle'
          : 'doğru nota — bir oktav pes söyle';
    } else if (_reading != null) {
      status = 'duyduğum: ${_reading!.note.label}';
    } else {
      status = 'sesini duyayım…';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Akoru Söyle · ${_chordIndex + 1}/${widget.chords.length}'),
        actions: [TextButton(onPressed: _skip, child: const Text('Geç'))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                _chord.label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'notalarına dokunup dinle, sonra sırayla söyle',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _replayChord,
                icon: const Icon(Icons.piano_rounded),
                label: const Text('Akorun tamamını dinle'),
              ),
              const SizedBox(height: 20),
              // Bireysel notalar — dokunarak dinlenebilir.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _chord.notes.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _noteChip(
                        theme,
                        _chord.notes[i],
                        i < _noteIndex
                            ? _NoteState.done
                            : i == _noteIndex
                                ? _NoteState.current
                                : _NoteState.pending,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: _hold,
                        strokeWidth: 9,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('şimdi',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
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
                      ? green
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: _micActive
                    ? OutlinedButton.icon(
                        onPressed: _stopListening,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Durdur'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _hearing ? null : _presentTarget,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text('${_target.label} notasını söyle'),
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

  Widget _noteChip(ThemeData theme, Note note, _NoteState state) {
    late final Color bg;
    late final Color fg;
    switch (state) {
      case _NoteState.done:
        bg = const Color(0xFF56C271);
        fg = Colors.white;
      case _NoteState.current:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
      case _NoteState.pending:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
    }
    return InkWell(
      onTap: _micActive ? null : () => _hearNote(note),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.volume_up_rounded, size: 12, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
