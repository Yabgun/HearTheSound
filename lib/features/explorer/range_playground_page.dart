import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_theme.dart';

// -----------------------------------------------------------------------------
// SES ARALIĞI OYUN ALANI — puansız keşif
//
// Kullanıcının "istersem başka aralıkları da deneyeyim" ihtiyacı için: geniş bir
// nota yelpazesinde istediğini seç → duy → söylemeyi dene → tuttun mu gör.
// Rahat/esneme/dışı bölgeleri renkle işaretlenir. Baskı yok, kilit yok —
// zamanla aralığı genişletmek için serbest alan.
// -----------------------------------------------------------------------------

class RangePlaygroundPage extends ConsumerStatefulWidget {
  const RangePlaygroundPage({super.key});

  @override
  ConsumerState<RangePlaygroundPage> createState() =>
      _RangePlaygroundPageState();
}

class _RangePlaygroundPageState extends ConsumerState<RangePlaygroundPage> {
  static final int _lowMidi = Note.fromName('C', 2).midi; // 36
  static final int _highMidi = Note.fromName('C', 6).midi; // 84
  static const double _itemExtent = 58;
  static const Duration _holdTarget = Duration(milliseconds: 1000);
  static const Color _green = AppColors.success;
  static const Color _amber = Color(0xFFE0912B);

  final PitchService _pitch = PitchService();
  final NotePlayer _player = createNotePlayer();
  late final ScrollController _scroll;

  int? _selected;
  bool _micActive = false;
  bool _caught = false;
  NoteReading? _reading;
  double _hold = 0;
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    final range = ref.read(progressProvider).vocalRange;
    _selected = range?.comfortHigh ?? Note.fromName('C', 4).midi;
    // Listeyi kullanıcının rahat aralığının biraz üstünden başlat (tiz notalar
    // üstte). Kalibre değilse C5 civarı.
    final top = range == null
        ? Note.fromName('C', 5).midi
        : range.comfortHigh + 3;
    final offset = ((_highMidi - top) * _itemExtent).clamp(
      0.0,
      double.infinity,
    );
    _scroll = ScrollController(initialScrollOffset: offset);
  }

  Future<void> _hearNote(int midi) async {
    if (_micActive) await _stopMic();
    setState(() {
      _selected = midi;
      _caught = false;
      _hold = 0;
      _reading = null;
    });
    await _player.play(Note(midi));
  }

  Future<void> _toggleSing() async {
    if (_selected == null) return;
    if (_micActive) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    await _player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                en: 'Microphone permission needed.',
                tr: 'Mikrofon izni gerekli.',
              ),
            ),
          ),
        );
      }
      return;
    }
    _lastTick = null;
    if (mounted) {
      setState(() {
        _micActive = true;
        _caught = false;
        _hold = 0;
      });
    }
  }

  Future<void> _stopMic() async {
    await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
  }

  void _onReading(NoteReading? r) {
    if (!_micActive || _caught || !mounted || _selected == null) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds /
              _holdTarget.inMilliseconds;
    _lastTick = now;
    final match = r != null && r.note.midi == _selected;
    setState(() {
      _reading = r;
      _hold = (_hold + (match ? dt : -dt * 0.5)).clamp(0.0, 1.0);
    });
    if (_hold >= 1.0) _onCaught();
  }

  Future<void> _onCaught() async {
    setState(() {
      _caught = true;
      _micActive = false;
    });
    await _pitch.stop();
  }

  @override
  void dispose() {
    _pitch.dispose();
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ReachZone? _zone(int midi, VocalRange? range) =>
      range == null ? null : reachZoneFor(midi, range);

  Color _zoneColor(ReachZone? zone, ThemeData theme) => switch (zone) {
    ReachZone.comfort => _green,
    ReachZone.stretch => _amber,
    _ => theme.colorScheme.outline,
  };

  String _zoneLabel(ReachZone? zone) => switch (zone) {
    ReachZone.comfort => t(en: 'comfort', tr: 'rahat'),
    ReachZone.stretch => t(en: 'stretch', tr: 'esneme'),
    ReachZone.beyond => t(en: 'out of range', tr: 'aralık dışı'),
    null => '',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = ref.watch(progressProvider).vocalRange;
    final count = _highMidi - _lowMidi + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(en: 'Vocal Range Playground', tr: 'Ses Aralığı Oyun Alanı'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                range == null
                    ? t(
                        en:
                            'Tap a note, listen, and try singing it. '
                            'No pressure — explore your voice.',
                        tr:
                            'Bir notaya dokun, dinle ve söylemeyi dene. '
                            'Baskı yok — sesini keşfet.',
                      )
                    : t(
                        en:
                            'Green = comfort, yellow = your stretch zone. '
                            'Feel free to step outside them and grow your '
                            'range.',
                        tr:
                            'Yeşil = rahat, sarı = esneme aralığın. Dışına '
                            'çıkıp sesini genişletmeyi de deneyebilirsin.',
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemExtent: _itemExtent,
                itemCount: count,
                itemBuilder: (_, i) {
                  final midi = _highMidi - i; // tiz üstte
                  return _keyTile(theme, midi, range);
                },
              ),
            ),
            _singPanel(theme, range),
          ],
        ),
      ),
    );
  }

  Widget _keyTile(ThemeData theme, int midi, VocalRange? range) {
    final note = Note(midi);
    final zone = _zone(midi, range);
    final zoneColor = _zoneColor(zone, theme);
    final selected = midi == _selected;
    final isC = note.pitchClass == 0; // oktav sınırını hafif belli et

    return InkWell(
      onTap: () => _hearNote(midi),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : (isC
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      )
                    : null),
          border: Border(
            left: BorderSide(color: zoneColor, width: 5),
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                note.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? theme.colorScheme.onPrimaryContainer : null,
                ),
              ),
            ),
            if (zone != null && zone != ReachZone.beyond)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _zoneLabel(zone),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: zoneColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Spacer(),
            Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _singPanel(ThemeData theme, VocalRange? range) {
    final sel = _selected;
    if (sel == null) {
      return const SizedBox.shrink();
    }
    final target = Note(sel);
    final zone = _zone(sel, range);
    final exact = _reading != null && _reading!.note.midi == sel;

    final String status;
    if (_caught) {
      final aboveComfort = sel > (range?.comfortHigh ?? sel);
      status = zone == ReachZone.comfort
          ? t(en: 'You held it! ✓', tr: 'Tuttun! ✓')
          : t(
              en: "Amazing! ✓ That's ${aboveComfort ? 'above' : 'outside'} your comfort range — nice work!",
              tr: 'Harika! ✓ Bu, rahat aralığının ${aboveComfort ? 'üstünde' : 'dışında'} — güzel iş!',
            );
    } else if (!_micActive) {
      status = t(
        en: 'Listen, then try singing it',
        tr: 'Dinle, sonra söylemeyi dene',
      );
    } else if (exact) {
      status = t(en: 'spot on — hold it! 🎯', tr: 'tam — böyle tut! 🎯');
    } else if (_reading != null) {
      status = t(
        en: 'I hear: ${_reading!.note.label}',
        tr: 'duyduğum: ${_reading!.note.label}',
      );
    } else {
      status = t(en: 'let me hear you…', tr: 'sesini duyayım…');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                target.label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: (_caught || exact)
                      ? _green
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              if (zone != null)
                Text(
                  _zoneLabel(zone),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _zoneColor(zone, theme),
                  ),
                ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => _hearNote(sel),
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: t(en: 'Listen', tr: 'Dinle'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _caught ? 1 : _hold,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surface,
            valueColor: AlwaysStoppedAnimation(
              (_caught || exact) ? _green : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: (_caught || exact)
                  ? _green
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _micActive
                ? OutlinedButton.icon(
                    onPressed: _stopMic,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(t(en: 'Stop', tr: 'Durdur')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _toggleSing,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(
                      t(
                        en: 'Sing ${target.label}',
                        tr: '${target.label} söyle',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
