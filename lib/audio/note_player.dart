import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../core/note.dart';
import 'soundfont_bank.dart';
import 'tone_synth.dart';

/// Nota çalma soyutlaması.
///
/// İki uygulama var: [SynthNotePlayer] (saf sentez ton, asset'siz) ve
/// [SoundFontNotePlayer] (gerçek piyano, GeneralUser GS). Egzersiz kodu hep bu
/// arayüzü konuşur, altyapıyı bilmez — çalıcıyı [createNotePlayer] üretir.
abstract class NotePlayer {
  Future<void> play(Note note);
  Future<void> playChord(List<Note> notes);
  Future<void> stop();
  Future<void> dispose();
}

/// Seçilebilir enstrümanlar (Ayarlar'daki "tını" seçimi).
enum Instrument { piano, synth }

/// Uygulama genelinde aktif enstrüman — tek yazar main()/Ayarlar'dır.
///
/// Varsayılan bilinçli olarak `synth`: widget testleri 30 MB'lık SoundFont'a
/// hiç dokunmasın. Gerçek uygulamada main() açılışta ayarlardan `piano` basar.
abstract final class NotePlayerConfig {
  static Instrument instrument = Instrument.synth;
}

/// Aktif enstrümana uygun çalıcıyı üretir. Ders/akış sayfaları çalıcıyı hep
/// buradan alır; böylece tını Ayarlar'dan tek dokunuşla uygulama geneli değişir.
NotePlayer createNotePlayer() => switch (NotePlayerConfig.instrument) {
  Instrument.piano => SoundFontNotePlayer(),
  Instrument.synth => SynthNotePlayer(),
};

/// Sentezlenmiş ton tabanlı çalıcı — asset gerektirmez.
/// Üretilen WAV'ları MIDI numarasına göre önbelleğe alır (her nota bir kez üretilir).
class SynthNotePlayer implements NotePlayer {
  SynthNotePlayer({
    ToneSynth? synth,
    Duration noteDuration = const Duration(milliseconds: 1200),
  }) : _synth = synth ?? const ToneSynth(),
       _duration = noteDuration;

  final ToneSynth _synth;
  final Duration _duration;
  final AudioPlayer _player = AudioPlayer();
  final Map<int, Uint8List> _cache = {};
  final Map<String, Uint8List> _chordCache = {};

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
  Future<void> playChord(List<Note> notes) async {
    final key = (notes.map((n) => n.midi).toList()..sort()).join(',');
    final wav = _chordCache.putIfAbsent(
      key,
      () => _synth.wavForFrequencies(
        notes.map((n) => n.frequency).toList(),
        duration: _duration,
      ),
    );
    await _player.stop();
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Gerçek piyano tınılı çalıcı — [SoundFontBank] (isolate) render eder.
///
/// Dayanıklılık kuralları:
/// - Banka henüz yükleniyorsa bu çağrı SENTEZ tona düşer (uygulama bekletmez,
///   asla sessiz kalmaz); yükleme arkada sürer, sonraki çalışlar piyanodur.
/// - Yükleme kalıcı başarısızsa (asset yok/bozuk) hep sentez çalınır.
/// - Render edilen WAV'lar sınıf-genelinde önbelleğe alınır (aynı nota/akor
///   bir kez render edilir); önbellek FIFO ile ~[_cacheCap] girdide tutulur.
class SoundFontNotePlayer implements NotePlayer {
  final AudioPlayer _player = AudioPlayer();
  final SynthNotePlayer _fallback = SynthNotePlayer();

  /// Tüm sayfalar aynı önbelleği paylaşır (ders geçişinde yeniden render yok).
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static const int _cacheCap = 64; // ~160 KB/girdi → en çok ~10 MB

  Future<void> _playMidis(List<Note> notes) async {
    final bank = SoundFontBank.instance;

    if (bank.failed) return _playFallback(notes);
    if (!bank.isReady) {
      unawaited(bank.ensureLoaded()); // arkada yüklensin
      return _playFallback(notes); // bu çağrı sentezle çıksın
    }

    final midis = notes.map((n) => n.midi).toList();
    final key = (List<int>.from(midis)..sort()).join(',');
    var wav = _cache[key];
    if (wav == null) {
      wav = await bank.renderWav(midis);
      if (wav == null) return _playFallback(notes);
      _cache[key] = wav;
      if (_cache.length > _cacheCap) _cache.remove(_cache.keys.first);
    }

    await _player.stop();
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  Future<void> _playFallback(List<Note> notes) => notes.length == 1
      ? _fallback.play(notes.first)
      : _fallback.playChord(notes);

  @override
  Future<void> play(Note note) => _playMidis([note]);

  @override
  Future<void> playChord(List<Note> notes) => _playMidis(notes);

  @override
  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _fallback.dispose();
  }
}
