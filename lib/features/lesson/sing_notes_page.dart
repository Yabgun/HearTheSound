import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/vocal_range.dart';
import '../../ui/app_theme.dart';
import '../../ui/note_names_sheet.dart';
import '../../ui/pitch_meter.dart';
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

  // Ders içi oktav kaydırıcı (keşif/konfor): kullanıcı bu söyleme adımını
  // ±oktav nudge edebilir. Efektif hedef = temel nota + kaydırma. Oturum boyu
  // korunur (bir kez rahat oktavı seçince tüm notalar öyle gelir).
  int _octaveShift = 0;
  Note get _target => Note(_toSing[_index].midi + _octaveShift);

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

  /// Bu adımın oktavını kaydır (±12). Efektif hedefi makul aralıkta tutar.
  Future<void> _shiftOctave(int delta) async {
    final base = _toSing[_index].midi;
    final next = _octaveShift + delta;
    if (base + next < 24 || base + next > 96) return; // güvenli sınır
    if (_micActive) await _stopListening();
    setState(() => _octaveShift = next);
    _beginNote(); // yeni oktavda referansı duyur, tutmayı sıfırla
  }

  /// "Söyle" — izin iste, çalmayı durdur, mikrofonu başlat.
  Future<void> _startListening() async {
    await widget.player.stop(); // referans çalmasını kes (ses çakışmasın)
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    ); // ses sistemi otursun
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
        : now.difference(_lastTick!).inMilliseconds /
              _holdTarget.inMilliseconds;
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
        appBar: AppBar(
          title: Text(t(en: 'Sing', tr: 'Söyle')),
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
    const green = AppColors.success;
    final ringColor = (_celebrating || exact)
        ? green
        : theme.colorScheme.primary;

    final String status;
    if (_celebrating) {
      status = t(en: 'Correct! ✓', tr: 'Doğru! ✓');
    } else if (!_micActive) {
      status = t(
        en: 'You heard the note. Now you sing it 👇',
        tr: 'Notayı dinledin. Şimdi sen söyle 👇',
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
            en: 'Sing · ${_index + 1}/${_toSing.length}',
            tr: 'Söyle · ${_index + 1}/${_toSing.length}',
          ),
        ),
        actions: [
          const NoteNamesButton(),
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
                t(en: 'SING THIS NOTE', tr: 'BU NOTAYI SÖYLE'),
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
                label: Text(t(en: 'Listen again', tr: 'Tekrar dinle')),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: () => _shiftOctave(-12),
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
                    onPressed: () => _shiftOctave(12),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    tooltip: t(en: 'One octave higher', tr: 'Bir oktav tiz'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
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
              const SizedBox(height: 12),
              // Canlı perde ibresi: sesin hedefe göre tam nerede olduğunu gösterir.
              PitchMeter(
                target: _target,
                reading: _reading,
                active: _micActive,
              ),
              const Spacer(flex: 2),
              // Ana eylem: Söyle / Durdur
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
                        onPressed: _celebrating ? null : _startListening,
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
