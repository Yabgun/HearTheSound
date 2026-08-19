import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import '../../core/note.dart';
import '../../ui/app_theme.dart';

// -----------------------------------------------------------------------------
// GELİŞTİRİCİ EKRANI — Mikrofon -> YIN -> Nota (perde tespiti spike'ı)
//
// Faz 0'da kanıtlanan kod. Üretim/söyleme egzersizleri bunun üstüne kurulacak.
// Şimdilik ana akışta değil; tanıma ekranındaki mikrofon simgesinden açılır.
// -----------------------------------------------------------------------------

/// PCM16 (işaretli, little-endian) baytlarını -1..1 float örneklere çevirir.
/// NOT: pitch_detector_dart 0.0.7'nin `getPitchFromIntBuffer` yolu hatalı
/// (yüksek baytı atıp big-endian okuyor), o yüzden dönüşümü biz yapıyoruz.
List<double> _pcm16ToFloat(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final count = bytes.length ~/ 2;
  final out = List<double>.filled(count, 0.0);
  for (var i = 0; i < count; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

class PitchSpikePage extends StatefulWidget {
  const PitchSpikePage({super.key});

  @override
  State<PitchSpikePage> createState() => _PitchSpikePageState();
}

class _PitchSpikePageState extends State<PitchSpikePage> {
  static const int _sampleRate = 44100;
  static const int _bufferSize = 2048;
  static const int _requiredBytes = _bufferSize * 2;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector(
    audioSampleRate: _sampleRate.toDouble(),
    bufferSize: _bufferSize,
  );
  final BytesBuilder _pcm = BytesBuilder();

  StreamSubscription<Uint8List>? _sub;
  bool _listening = false;
  bool _analyzing = false;
  bool _permissionDenied = false;

  NoteReading? _reading;
  double _probability = 0;
  bool _pitched = false;

  Future<void> _toggle() async {
    if (_listening) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    final ok = await _recorder.hasPermission();
    if (!ok) {
      setState(() => _permissionDenied = true);
      return;
    }
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    );
    final stream = await _recorder.startStream(config);
    _sub = stream.listen(
      _onAudio,
      onError: (Object e) => debugPrint('[audio] stream error: $e'),
    );
    setState(() {
      _permissionDenied = false;
      _listening = true;
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _pcm.clear();
    setState(() {
      _listening = false;
      _pitched = false;
    });
  }

  void _onAudio(Uint8List chunk) {
    _pcm.add(chunk);
    if (_pcm.length < _requiredBytes) return;
    final all = _pcm.takeBytes();
    final window = Uint8List.sublistView(all, all.length - _requiredBytes);
    _analyze(window);
  }

  Future<void> _analyze(Uint8List pcm16) async {
    if (_analyzing) return;
    _analyzing = true;
    try {
      final samples = _pcm16ToFloat(pcm16);
      final result = await _detector.getPitchFromFloatBuffer(samples);
      if (!mounted) return;
      setState(() {
        _probability = result.probability;
        _pitched = result.pitched && result.pitch > 0;
        if (_pitched) {
          _reading = NoteReading.fromFrequency(result.pitch);
        }
      });
    } catch (e) {
      debugPrint('[pitch] analyze error: $e');
    } finally {
      _analyzing = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = _reading;
    final active = _listening && _pitched;

    Color accent;
    if (!active || reading == null) {
      accent = theme.colorScheme.outline;
    } else if (reading.cents.abs() < 5) {
      accent = context.colors.success;
    } else if (reading.cents.abs() < 20) {
      accent = const Color(0xFFE0912B);
    } else {
      accent = context.colors.danger;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perde Tespiti (geliştirici)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'DUYDUĞUM NOTA',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: active ? 1 : 0.35,
                child: Text(
                  reading?.label ?? '—',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 104,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                active && reading != null
                    ? '${reading.frequency.toStringAsFixed(1)} Hz'
                    : (_listening ? 'ses bekleniyor…' : 'başlamak için dinle'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              _TuningMeter(
                cents: reading?.cents ?? 0,
                active: active,
                accent: accent,
              ),
              const SizedBox(height: 10),
              Text(
                active && reading != null
                    ? '${reading.cents >= 0 ? '+' : ''}${reading.cents.toStringAsFixed(0)} cent'
                    : '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'güven: ${(_probability * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              if (_permissionDenied)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Mikrofon izni gerekli. Lütfen izin verip tekrar deneyin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  label: Text(_listening ? 'Durdur' : 'Dinle'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: _listening
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primary,
                    foregroundColor: _listening
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Basit akort göstergesi: −50…0…+50 cent aralığında hareket eden iğne.
class _TuningMeter extends StatelessWidget {
  const _TuningMeter({
    required this.cents,
    required this.active,
    required this.accent,
  });

  final double cents;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final clamped = cents.clamp(-50.0, 50.0);
    final t = (clamped + 50) / 100;
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          Container(width: 2, height: 26, color: theme.colorScheme.outline),
          Align(
            alignment: Alignment(2 * t - 1, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: active ? accent : theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
