import 'dart:typed_data';

// -----------------------------------------------------------------------------
// WAV YAZICI — PCM16 örnekleri geçerli bir mono WAV konteynerine sarar.
//
// Hem sentez ton (ToneSynth) hem SoundFont render'ı aynı sarmalayıcıyı kullanır;
// böylece "ses → audioplayers BytesSource" boru hattı tek yerde tanımlıdır.
// -----------------------------------------------------------------------------

/// [samples] (PCM16) örneklerini mono WAV dosyası baytlarına çevirir.
/// Örnekler dosyaya açıkça little-endian yazılır (WAV standardı).
Uint8List pcm16ToWav(Int16List samples, {int sampleRate = 44100}) {
  final dataSize = samples.length * 2;
  final bytes = Uint8List(44 + dataSize);
  final bd = ByteData.sublistView(bytes);
  _writeWavHeader(bd, dataSize: dataSize, sampleRate: sampleRate);
  for (var i = 0; i < samples.length; i++) {
    bd.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes;
}

/// Zaten little-endian PCM16 olan ham baytları (ör. SoundFont render çıktısı)
/// kopyalayarak WAV'a sarar — örnek örnek dönüşüme gerek kalmaz.
Uint8List pcm16LeBytesToWav(Uint8List pcmLeBytes, {int sampleRate = 44100}) {
  final dataSize = pcmLeBytes.length;
  final bytes = Uint8List(44 + dataSize);
  _writeWavHeader(
    ByteData.sublistView(bytes),
    dataSize: dataSize,
    sampleRate: sampleRate,
  );
  bytes.setRange(44, 44 + dataSize, pcmLeBytes);
  return bytes;
}

void _writeWavHeader(
  ByteData bd, {
  required int dataSize,
  required int sampleRate,
}) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final fileSize = 44 + dataSize;

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
}
