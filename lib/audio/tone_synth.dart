import 'dart:math' as math;
import 'dart:typed_data';

/// Saf Dart ton sentezleyici: bir veya birden çok frekanstan PCM16 WAV üretir.
///
/// Tek frekans = nota; birden çok frekans aynı anda = akor. audioplayers
/// `BytesSource` ile doğrudan çalınır; asset gerektirmez. Tık sesini önlemek için
/// giriş-çıkış zarfı uygulanır. İleride SoundFont ile değiştirilebilir.
class ToneSynth {
  final int sampleRate;
  const ToneSynth({this.sampleRate = 44100});

  /// Tek bir [frequency] için WAV üretir.
  Uint8List wavForFrequency(
    double frequency, {
    Duration duration = const Duration(milliseconds: 1200),
    double volume = 0.6,
  }) =>
      wavForFrequencies([frequency], duration: duration, volume: volume);

  /// Birden çok frekansı AYNI ANDA sentezler (akor). Frekanslar toplanıp
  /// nota sayısına göre normalize edilir (kırpılmayı önlemek için).
  Uint8List wavForFrequencies(
    List<double> frequencies, {
    Duration duration = const Duration(milliseconds: 1200),
    double volume = 0.6,
  }) {
    final totalSamples = (duration.inMilliseconds * sampleRate / 1000).round();
    final pcm = Int16List(totalSamples);

    final attack = 0.010 * sampleRate; // 10 ms yumuşak giriş
    final release = 0.180 * sampleRate; // 180 ms yumuşak çıkış
    final twoPiFs = frequencies.map((f) => 2 * math.pi * f).toList();
    // Her nota: temel + 0.18 harmonik -> 1.18; toplam nota sayısıyla normalize.
    final norm = frequencies.isEmpty ? 1.0 : frequencies.length * 1.18;

    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;

      var env = 1.0;
      if (i < attack) {
        env = i / attack;
      } else if (i > totalSamples - release) {
        env = (totalSamples - i) / release;
      }
      env *= 0.6 + 0.4 * math.exp(-1.5 * t);

      var signal = 0.0;
      for (final w in twoPiFs) {
        signal += math.sin(w * t) + 0.18 * math.sin(2 * w * t);
      }
      final value = signal / norm * env * volume;

      pcm[i] = (value * 32767).round().clamp(-32768, 32767);
    }

    return _wrapWav(pcm);
  }

  /// PCM16 örneklerini geçerli bir WAV (mono) konteynerine sarar.
  Uint8List _wrapWav(Int16List samples) {
    const bitsPerSample = 16;
    const numChannels = 1;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;
    final fileSize = 44 + dataSize;

    final bytes = Uint8List(fileSize);
    final bd = ByteData.sublistView(bytes);

    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bd.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    bd.setUint32(4, fileSize - 8, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bd.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return bytes;
  }
}
