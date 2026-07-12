import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/note.dart';
import '../../core/vocal_range.dart';
import '../calibration/reach_badge.dart';

// -----------------------------------------------------------------------------
// SÖYLE AŞAMASI — mikrofonla nota üretimi
//
// Akış: notaya girince referans OTOMATIK çalar (kullanıcı duyar). Mikrofon
// KENDİLİĞİNDEN başlamaz — kullanıcı "Söyle" butonuna basınca izin istenir ve
// dinleme başlar (çalma önce durdurulur ki ses çakışmasın). TAM oktavı
// (E4 = E4; E2/E3 kabul edilmez) sürdürdükçe halka dolar; dolunca sonrakine
// geçilir. Havuz akış sayfasında kullanıcının aralığına transpoze edilmiş gelir.
// -----------------------------------------------------------------------------

class SingNotesPage extends StatefulWidget {
  const SingNotesPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
    this.range,
  });

  final List<Note> pool;
  final NotePlayer player;
  final VoidCallback onComplete;

  /// Kullanıcının ses aralığı — rahat aralığı aşan hedeflerde rozet göstermek
  /// için. null ise (kalibre edilmemiş) rozet çıkmaz.
  final VocalRange? range;

  @override
  State<SingNotesPage> createState() => _SingNotesPageState();
}

class _SingNotesPageState extends State<SingNotesPage> {
  // Doğru notayı kesintisiz bu kadar süre tutunca halka dolar (istenirse ayarlanır).
  static const Duration _holdTarget = Duration(seconds: 3);

  final PitchService _pitch = PitchService();

  int _index = 0;
  double _hold = 0; // 0..1 doğru perdeyi tutma
  NoteReading? _reading;
  bool _micActive = false;
  bool _celebrating = false;
  bool _permissionDenied = false;
  DateTime? _lastTick; // zaman-temelli dolum için son okuma anı

  // Büyük havuzlarda tüm notaları söyletmek yorucu; rastgele bir alt küme seç (en çok 5).
  late final List<Note> _toSing = _pickToSing();

  List<Note> _pickToSing() {
    final shuffled = List<Note>.from(widget.pool)..shuffle();
    final count = widget.pool.length <= 5 ? widget.pool.length : 5;
    return shuffled.take(count).toList();
  }

  Note get _target => _toSing[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginNote());
  }

  /// Notaya girişte referansı duyur — mikrofon başlamaz.
  Future<void> _beginNote() async {
    setState(() {
      _micActive = false;
      _celebrating = false;
      _hold = 0;
      _reading = null;
    });
    await widget.player.play(_target);
  }

  Future<void> _replay() async {
    if (_micActive) await _stopListening();
    await widget.player.play(_target);
  }

  /// "Söyle" — izin iste, çalmayı durdur, mikrofonu başlat.
  Future<void> _startListening() async {
    await widget.player.stop(); // referans çalmasını kes (ses çakışmasın)
    await Future<void>.delayed(const Duration(milliseconds: 200)); // ses sistemi otursun
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    if (mounted) {
      _lastTick = null;
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
    // Zaman-temelli dolum: okuma hızından bağımsız, geçen süreye göre ilerler.
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds / _holdTarget.inMilliseconds;
    _lastTick = now;
    // Tam oktav eşleşmesi (E4 = E4; E2/E3 kabul edilmez).
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
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _advance();
  }

  void _advance() {
    if (!mounted) return;
    if (_index + 1 >= _toSing.length) {
      widget.onComplete();
    } else {
      setState(() => _index++);
      _beginNote();
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
        appBar: AppBar(title: const Text('Söyle')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bu adım için mikrofon izni gerekli.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _permissionDenied = false);
                    _startListening();
                  },
                  child: const Text('İzin ver ve tekrar dene'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onComplete,
                  child: const Text('Bu adımı atla'),
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
    const green = Color(0xFF56C271);
    final ringColor = (_celebrating || exact) ? green : theme.colorScheme.primary;

    final String status;
    if (_celebrating) {
      status = 'Doğru! ✓';
    } else if (!_micActive) {
      status = 'Notayı dinledin. Şimdi sen söyle 👇';
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
        title: Text('Söyle · ${_index + 1}/${_toSing.length}'),
        actions: [
          TextButton(onPressed: _skip, child: const Text('Geç')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'BU NOTAYI SÖYLE',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _target.label,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 76,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _replay,
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Tekrar dinle'),
              ),
              const SizedBox(height: 12),
              ReachBadge(target: _target, range: widget.range),
              const Spacer(),
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: CircularProgressIndicator(
                        value: _hold,
                        strokeWidth: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    Icon(
                      _celebrating ? Icons.check_rounded : Icons.mic_rounded,
                      size: 60,
                      color: _celebrating
                          ? green
                          : (_micActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              // Ana eylem: Söyle / Durdur
              SizedBox(
                width: double.infinity,
                child: _micActive
                    ? OutlinedButton.icon(
                        onPressed: _celebrating ? null : _stopListening,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Durdur'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _celebrating ? null : _startListening,
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text('Söyle'),
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
