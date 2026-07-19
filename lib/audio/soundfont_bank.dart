import 'dart:async';
import 'dart:isolate';

// Not: dart:typed_data ayrıca gerekmiyor — barrel zaten dışa aktarıyor.
import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'wav_writer.dart';

// -----------------------------------------------------------------------------
// SOUNDFONT BANKASI — gerçek piyano tınısı (GeneralUser GS, assets/sf2/)
//
// 30 MB'lık .sf2 dosyasının ayrıştırılması ve nota render'ı CPU-yoğun işlerdir;
// ana thread'de yapılsa kare düşürür. Bu yüzden UZUN ÖMÜRLÜ BİR ISOLATE kurulur:
// isolate açılışta sentezleyiciyi bir kez inşa eder, sonra her istek için
// (MIDI listesi → WAV baytları) döner. Baytlar TransferableTypedData ile
// kopyasız taşınır.
//
// Yükleme başarısız olursa (asset yok/bozuk) [failed] işaretlenir; çağıran
// (SoundFontNotePlayer) sentez tona geri düşer — uygulama asla sessiz kalmaz.
// -----------------------------------------------------------------------------

class SoundFontBank {
  SoundFontBank._();

  static final SoundFontBank instance = SoundFontBank._();

  static const String _assetPath = 'assets/sf2/GeneralUser-GS.sf2';
  static const int sampleRate = 44100;

  SendPort? _worker;
  Future<bool>? _loading;
  bool _failed = false;

  /// Isolate hazır ve istek alabilir mi?
  bool get isReady => _worker != null;

  /// Yükleme kalıcı olarak başarısız oldu mu? (asset eksik/bozuk)
  bool get failed => _failed;

  int _nextRequestId = 0;
  final Map<int, Completer<Uint8List?>> _pending = {};

  /// Bankayı yüklemeye başlar (idempotent). Uygulama açılışında çağrılırsa
  /// ilk derse gelindiğinde piyano çoktan hazır olur.
  Future<bool> ensureLoaded() => _loading ??= _load();

  Future<bool> _load() async {
    try {
      final data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      final fromWorker = ReceivePort();
      final ready = Completer<bool>();

      fromWorker.listen((message) {
        if (message is SendPort) {
          // Worker kuruldu — istek kanalı bu port.
          _worker = message;
          if (!ready.isCompleted) ready.complete(true);
        } else if (message == 'load_failed') {
          if (!ready.isCompleted) ready.complete(false);
        } else if (message is List && message.length == 2) {
          // Render cevabı: [istekId, TransferableTypedData? wav]
          final completer = _pending.remove(message[0] as int);
          final payload = message[1];
          completer?.complete(
            payload is TransferableTypedData
                ? payload.materialize().asUint8List()
                : null,
          );
        }
      });

      await Isolate.spawn(_soundFontWorker, [
        fromWorker.sendPort,
        TransferableTypedData.fromList([bytes]),
      ], debugName: 'soundfont-render');

      final ok = await ready.future;
      if (!ok) _failed = true;
      return ok;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  /// [midis] notalarını AYNI ANDA çalıp doğal sönümüyle birlikte mono WAV
  /// baytları döndürür. Banka hazır değilse önce yüklenir; başarısızlıkta null.
  Future<Uint8List?> renderWav(
    List<int> midis, {
    int sustainMs = 1200,
    int releaseMs = 700,
  }) async {
    final ok = await ensureLoaded();
    final worker = _worker;
    if (!ok || worker == null) return null;

    final id = _nextRequestId++;
    final completer = Completer<Uint8List?>();
    _pending[id] = completer;
    worker.send([id, midis, sustainMs, releaseMs]);
    return completer.future;
  }
}

/// Isolate giriş noktası: sentezleyiciyi bir kez kurar, istekleri render eder.
/// boot = [cevap portu, sf2 baytları (transferable)].
void _soundFontWorker(List<Object> boot) {
  final replyTo = boot[0] as SendPort;
  final sf2Bytes = (boot[1] as TransferableTypedData)
      .materialize()
      .asUint8List();

  final Synthesizer synth;
  var pianoPresetIndex = 0;
  try {
    synth = Synthesizer.loadByteData(
      ByteData.sublistView(sf2Bytes),
      SynthesizerSettings(
        sampleRate: SoundFontBank.sampleRate,
        maximumPolyphony: 32,
        // Kulak eğitimi için kuru/temiz tını: reverb perdeyi bulanıklaştırır.
        enableReverbAndChorus: false,
      ),
    );
    // Akustik piyano preset'ini bul (GM: bank 0, program 0). selectPreset
    // LİSTE İNDEKSİ ister, program numarası değil — o yüzden arıyoruz.
    final presets = synth.soundFont.presets;
    for (var i = 0; i < presets.length; i++) {
      if (presets[i].bankNumber == 0 && presets[i].patchNumber == 0) {
        pianoPresetIndex = i;
        break;
      }
    }
  } catch (_) {
    replyTo.send('load_failed');
    return;
  }

  final requests = ReceivePort();
  replyTo.send(requests.sendPort);

  requests.listen((message) {
    final request = message as List;
    final id = request[0] as int;
    try {
      final midis = (request[1] as List).cast<int>();
      final sustainSamples =
          (request[2] as int) * SoundFontBank.sampleRate ~/ 1000;
      final releaseSamples =
          (request[3] as int) * SoundFontBank.sampleRate ~/ 1000;

      // Her render temiz bir sayfada başlar (önceki notalardan iz kalmasın).
      synth.reset();
      synth.selectPreset(channel: 0, preset: pianoPresetIndex);
      for (final midi in midis) {
        synth.noteOn(channel: 0, key: midi, velocity: 100);
      }

      final buffer = ArrayInt16.zeros(
        numShorts: sustainSamples + releaseSamples,
      );
      // Basılı kısım + tuş bırakılınca doğal sönüm kuyruğu.
      synth.renderMonoInt16(buffer, offset: 0, length: sustainSamples);
      synth.noteOffAll();
      synth.renderMonoInt16(
        buffer,
        offset: sustainSamples,
        length: releaseSamples,
      );

      // ArrayInt16 içi zaten little-endian PCM16 → doğrudan WAV'a sar.
      final pcm = buffer.bytes.buffer.asUint8List(
        buffer.bytes.offsetInBytes,
        buffer.bytes.lengthInBytes,
      );
      final wav = pcm16LeBytesToWav(pcm, sampleRate: SoundFontBank.sampleRate);
      replyTo.send([
        id,
        TransferableTypedData.fromList([wav]),
      ]);
    } catch (_) {
      replyTo.send([id, null]);
    }
  });
}
