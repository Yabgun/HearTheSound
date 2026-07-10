import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../core/note.dart';
import 'tone_synth.dart';

/// Nota çalma soyutlaması.
///
/// Bugün sentezlenmiş tonlarla ([SynthNotePlayer]); ileride SoundFont / gerçek
/// enstrüman tınılarıyla aynı arayüz ardında değiştirilebilir. Egzersiz kodu
/// hep bu arayüzü konuşur, altyapıyı bilmez.
abstract class NotePlayer {
  Future<void> play(Note note);
  Future<void> stop();
  Future<void> dispose();
}

/// Sentezlenmiş ton tabanlı çalıcı — asset gerektirmez.
/// Üretilen WAV'ları MIDI numarasına göre önbelleğe alır (her nota bir kez üretilir).
class SynthNotePlayer implements NotePlayer {
  SynthNotePlayer({ToneSynth? synth, Duration noteDuration = const Duration(milliseconds: 1200)})
      : _synth = synth ?? const ToneSynth(),
        _duration = noteDuration;

  final ToneSynth _synth;
  final Duration _duration;
  final AudioPlayer _player = AudioPlayer();
  final Map<int, Uint8List> _cache = {};

  @override
  Future<void> play(Note note) async {
    final wav = _cache.putIfAbsent(
      note.midi,
      () => _synth.wavForFrequency(note.frequency, duration: _duration),
    );
    // Aynı çalıcıyı yeniden kullan; her çağrıda baştan çal.
    await _player.stop();
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
