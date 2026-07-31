import 'dart:async';

import '../core/musical_phrase.dart';
import 'note_player.dart';

// -----------------------------------------------------------------------------
// CÜMLE ÇALICI — bir [MusicalPhrase]'i sırayla seslendirir
//
// [NotePlayer] tek nota/akor çalar; cümleyi zamanda dizmek bu katmanın işi.
// Ayrıca hangi olayın çaldığını bildirir (onEvent) — kullanıcı sesi GÖRSEL
// olarak da takip edebilsin diye: "şu an neredeyiz" sorusu okumadan cevaplanır.
//
// İPTAL: kullanıcı sayfadan çıkarsa ya da yeni bir çalma başlatırsa eski dizi
// kendiliğinden susmalı. Bunu "nesil" (generation) sayacıyla yapıyoruz — çalma
// döngüsü her adımda kendi neslinin hâlâ güncel olup olmadığına bakar.
// -----------------------------------------------------------------------------

class PhrasePlayer {
  PhrasePlayer(this._player);

  final NotePlayer _player;

  /// Her yeni çalma/iptal bunu artırır; eski döngüler bunu görüp çekilir.
  int _generation = 0;
  bool _playing = false;

  bool get isPlaying => _playing;

  /// Cümleyi baştan sona çalar. Önceki çalma varsa iptal edilir.
  ///
  /// [beat] tek birimlik olayın süresi; olayın kendi `beats` değeriyle çarpılır.
  /// [onEvent] çalan olayın indisini verir, cümle bitince/iptalde `null` gelir.
  Future<void> play(
    MusicalPhrase phrase, {
    Duration beat = const Duration(milliseconds: 420),
    void Function(int? index)? onEvent,
  }) async {
    final generation = ++_generation;
    _playing = true;

    for (var i = 0; i < phrase.events.length; i++) {
      if (generation != _generation) return; // iptal edildi
      final event = phrase.events[i];
      onEvent?.call(i);

      if (event.isChord) {
        await _player.playChord(event.notes);
      } else {
        await _player.play(event.notes.first);
      }
      await Future<void>.delayed(beat * event.beats);
    }

    if (generation != _generation) return;
    _playing = false;
    onEvent?.call(null);
  }

  /// Çalmayı durdurur (sayfa kapanışı, yeni soruya geçiş...).
  Future<void> cancel() async {
    _generation++;
    _playing = false;
    await _player.stop();
  }
}
