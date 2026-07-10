import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import '../core/note.dart';

// -----------------------------------------------------------------------------
// PitchService — Mikrofon -> YIN -> NoteReading
//
// Faz 0'da (spike) kanıtlanan perde-tespiti kodunun yeniden kullanılabilir hali.
// Teşhis kolaylığı için debugPrint logları eklendi (logcat'ten izlenebilir).
// -----------------------------------------------------------------------------

class PitchService {
  static const int sampleRate = 44100;
  static const int bufferSize = 2048;
  static const int _requiredBytes = bufferSize * 2; // PCM16 = 2 bayt/örnek

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector(
    audioSampleRate: sampleRate.toDouble(),
    bufferSize: bufferSize,
  );
  final BytesBuilder _pcm = BytesBuilder();

  StreamSubscription<Uint8List>? _sub;
  bool _analyzing = false;
  bool _loggedFirst = false;
  int _frame = 0;
  void Function(NoteReading?)? _onReading;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Dinlemeye başlar; her pencerede [onReading] çağrılır (net perde yoksa null).
  Future<bool> start(void Function(NoteReading?) onReading) async {
    if (!await _recorder.hasPermission()) {
      debugPrint('[pitch] mikrofon izni yok');
      return false;
    }
    _onReading = onReading;
    _loggedFirst = false;
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    );
    try {
      final stream = await _recorder.startStream(config);
      debugPrint('[pitch] stream başladı');
      _sub = stream.listen(
        _onAudio,
        onError: (Object e) => debugPrint('[pitch] stream error: $e'),
      );
      return true;
    } catch (e) {
      debugPrint('[pitch] startStream hata: $e');
      return false;
    }
  }

  void _onAudio(Uint8List chunk) {
    if (!_loggedFirst) {
      _loggedFirst = true;
      debugPrint('[pitch] ilk parça: ${chunk.length} bayt');
    }
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
      if ((_frame++ % 15) == 0) {
        debugPrint('[pitch] hz=${result.pitch.toStringAsFixed(1)} '
            'prob=${result.probability.toStringAsFixed(2)} '
            'pitched=${result.pitched}');
      }
      final reading = (result.pitched && result.pitch > 0)
          ? NoteReading.fromFrequency(result.pitch)
          : null;
      _onReading?.call(reading);
    } catch (e) {
      debugPrint('[pitch] analyze hata: $e');
    } finally {
      _analyzing = false;
    }
  }

  /// Dinlemeyi durdurur (servis yeniden başlatılabilir).
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _pcm.clear();
    _onReading = null;
  }

  /// Servisi tamamen kapatır.
  Future<void> dispose() async {
    await _sub?.cancel();
    await _recorder.dispose();
  }

  /// PCM16 (işaretli, little-endian) -> -1..1 float.
  static List<double> _pcm16ToFloat(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    final out = List<double>.filled(count, 0.0);
    for (var i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}
