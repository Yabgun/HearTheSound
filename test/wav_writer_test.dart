import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/audio/wav_writer.dart';

// WAV sarmalayıcı: hem sentez ton hem SoundFont render'ı bu boru hattından
// geçtiği için başlık alanlarının doğruluğu iki tınının da çalınabilirliği demek.
void main() {
  test('pcm16ToWav geçerli mono WAV başlığı üretir', () {
    final samples = Int16List.fromList([0, 1000, -1000, 32767, -32768]);
    final wav = pcm16ToWav(samples, sampleRate: 44100);

    expect(wav.length, 44 + samples.length * 2);
    // 'RIFF' + 'WAVE' sihirli baytları
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');

    final bd = ByteData.sublistView(wav);
    expect(bd.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(bd.getUint32(24, Endian.little), 44100, reason: 'örnekleme hızı');
    expect(bd.getUint16(34, Endian.little), 16, reason: 'bit derinliği');
    expect(
      bd.getUint32(40, Endian.little),
      samples.length * 2,
      reason: 'veri boyutu',
    );
    // İlk örnek little-endian geri okunabilmeli.
    expect(bd.getInt16(44 + 2, Endian.little), 1000);
  });

  test('pcm16LeBytesToWav ham baytları veri bölümüne birebir kopyalar', () {
    final pcm = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
    final wav = pcm16LeBytesToWav(pcm, sampleRate: 22050);

    expect(wav.sublist(44), pcm);
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 22050);
  });

  test('testlerde varsayılan enstrüman synth kalır (SoundFont yüklenmez)', () {
    // Widget/smoke testleri createNotePlayer() üzerinden çalıcı kurar; varsayılan
    // synth olmalı ki 30 MB'lık sf2 asset'i test ortamında hiç açılmasın.
    // (Çalıcıyı burada gerçekten KURMUYORUZ: AudioPlayer platform binding ister.)
    expect(NotePlayerConfig.instrument, Instrument.synth);
  });
}
