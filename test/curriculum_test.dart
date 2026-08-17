import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/features/home/curriculum.dart';

// Müfredat tek SIRALI zincir: Notalar → Melodi Kulağı → Akorlar → Armoni
// Kulağı. Her track bir öncekinin son dersi bitince açılır.
//
// SIRA GEREKÇESİ: doğal öğrenme yolu tek ses → zamanda çok ses (ezgi) → aynı
// anda çok ses (akor) → akorların birbirine göre hareketi (armoni). İnsan önce
// şarkı söyler, sonra akor duyar — bu yüzden Melodi Kulağı, Akorlar'dan ÖNCE
// gelir; akorun rengini tanımadan da ilerlemesi duyulamayacağı için Armoni
// Kulağı en sondadır.

void main() {
  test('track sırası doğru (Melodi Kulağı, Akorlar\'dan ÖNCE)', () {
    final firstIds = [for (final tr in curriculum) tr.items.first.id];
    expect(firstIds[0], 'first_notes'); // Notalar
    expect(firstIds[1], 'mel1'); // Melodi Kulağı
    expect(firstIds[2], 'ch_bright'); // Akorlar
    expect(firstIds[3], 'har1'); // Armoni Kulağı
    expect(firstIds[4], 'rhy1'); // Ritim Kulağı
  });

  test('Ritim Kulağı zincirin SONUNDA — Armoni bitmeden açılmaz', () {
    final tracks = curriculum;
    // Armoni'ye kadar her şey tamam → Ritim hâlâ kapalı.
    final beforeHarmony = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(3),
    );
    expect(itemUnlocked(tracks[4], 0, beforeHarmony), isFalse);

    // Armoni de bitince açılır ve "Devam Et" oraya gider.
    final harmonyDone = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(4),
    );
    expect(itemUnlocked(tracks[4], 0, harmonyDone), isTrue);
    expect(nextLesson(harmonyDone)?.item.id, 'rhy1');
  });

  test('Armoni Kulağı Akorlar bitmeden açılmaz', () {
    final tracks = curriculum;
    // İlk 2 track tamam (Notalar + Melodi) → Akorlar açık, Armoni hâlâ kapalı.
    final chordsOpen = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(2),
    );
    expect(itemUnlocked(tracks[2], 0, chordsOpen), isTrue);
    expect(itemUnlocked(tracks[3], 0, chordsOpen), isFalse);

    // Akorlar da bitince Armoni açılır ve "Devam Et" oraya gider.
    final chordsDone = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(3),
    );
    expect(itemUnlocked(tracks[3], 0, chordsDone), isTrue);
    expect(nextLesson(chordsDone)?.item.id, 'har1');
  });

  test('sıfırdan hesap: yalnızca Notalar açık; next = first_notes', () {
    const p = PlayerProgress();
    final tracks = curriculum;
    expect(itemUnlocked(tracks[0], 0, p), isTrue); // Notalar
    expect(itemUnlocked(tracks[1], 0, p), isFalse); // Melodi Kulağı kilitli
    expect(itemUnlocked(tracks[2], 0, p), isFalse); // Akorlar kilitli
    expect(nextLesson(p)?.item.id, 'first_notes');
  });

  test('Notalar bitince Melodi açılır; Akorlar hâlâ kilitli; next = mel1', () {
    final tracks = curriculum;
    final notesDone = PlayerProgress(
      completedLessons: [for (final it in tracks[0].items) it.id],
    );
    expect(itemUnlocked(tracks[1], 0, notesDone), isTrue); // Melodi açık
    expect(itemUnlocked(tracks[2], 0, notesDone), isFalse); // Akorlar kilitli
    expect(nextLesson(notesDone)?.item.id, 'mel1');
  });

  // Geliştirici "Tüm dersleri aç" düğmesinin (features/dev/dev_tools_tile.dart)
  // dayandığı sözleşme: tüm id'ler tamam sayılınca müfredatta kilitli ders
  // kalmamalı. Yeni bir track eklenip kilit zinciri farklı kurulursa düğme
  // sessizce yarım iş yapardı — bu test onu yakalar.
  test('tüm ders id\'leri tamam sayılınca hiçbir ders kilitli kalmaz', () {
    final everything = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(curriculum.length),
    );
    for (final track in curriculum) {
      for (var i = 0; i < track.items.length; i++) {
        expect(
          itemUnlocked(track, i, everything),
          isTrue,
          reason: '${track.items[i].id} kilitli kaldı',
        );
      }
    }
  });

  test('lessonIdsInFirstTracks seviye seçimini doğru besler', () {
    // "Notaları biliyorum" (1 track) = tam olarak Notalar dersleri.
    final notesIds = lessonIdsInFirstTracks(1);
    expect(notesIds, [for (final it in curriculum[0].items) it.id]);

    // Bu id'ler tamam sayılınca zincir Melodi Kulağı'nı açar → next mel1.
    final notesKnown = PlayerProgress(completedLessons: notesIds);
    expect(itemUnlocked(curriculum[1], 0, notesKnown), isTrue);
    expect(nextLesson(notesKnown)?.item.id, 'mel1');

    // 0 track → sıfırdan (boş).
    expect(lessonIdsInFirstTracks(0), isEmpty);

    // İlk 2 track tamam → 3. track (Akorlar) açılır. Sabit id yerine sıraya
    // bağlanır ki müfredat yeniden düzenlenince kilit MANTIĞI test edilsin.
    final melodyKnown = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(2),
    );
    expect(itemUnlocked(curriculum[2], 0, melodyKnown), isTrue);
    expect(nextLesson(melodyKnown)?.item.id, curriculum[2].items.first.id);
  });
}
