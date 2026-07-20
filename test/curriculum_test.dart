import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/features/home/curriculum.dart';

// Müfredat artık tek SIRALI zincir: Notalar → Aralıklar → Akorlar → Tonalite →
// İşlev → İlerlemeler → Yolculuk. Her track bir öncekinin son dersi bitince açılır.
// Onboarding seviye seçimi bu zinciri `lessonIdsInFirstTracks` ile besler.

void main() {
  test('track sırası doğru (Aralıklar, Akorlar\'dan ÖNCE)', () {
    final firstIds = [for (final tr in curriculum) tr.items.first.id];
    expect(firstIds[0], 'first_notes'); // Notalar
    expect(firstIds[1], 'iv1'); // Aralıklar
    expect(firstIds[2], 'ch1'); // Akorlar
    expect(firstIds[3], 'tn1'); // Tonalite
    expect(firstIds[4], 'fn1'); // İşlev
    expect(firstIds[5], 'pr1'); // İlerlemeler
    expect(firstIds[6], startsWith('fn_j_')); // Tonalite Yolculuğu
  });

  test('sıfırdan hesap: yalnızca Notalar açık; next = first_notes', () {
    const p = PlayerProgress();
    final tracks = curriculum;
    expect(itemUnlocked(tracks[0], 0, p), isTrue); // Notalar
    expect(itemUnlocked(tracks[1], 0, p), isFalse); // Aralıklar kilitli
    expect(itemUnlocked(tracks[2], 0, p), isFalse); // Akorlar kilitli
    expect(itemUnlocked(tracks[4], 0, p), isFalse); // İşlev kilitli
    expect(nextLesson(p)?.item.id, 'first_notes');
  });

  test('Notalar bitince Aralıklar açılır; Akorlar hâlâ kilitli; next = iv1', () {
    final tracks = curriculum;
    final notesDone = PlayerProgress(
      completedLessons: [for (final it in tracks[0].items) it.id],
    );
    expect(itemUnlocked(tracks[1], 0, notesDone), isTrue); // Aralıklar açık
    expect(itemUnlocked(tracks[2], 0, notesDone), isFalse); // Akorlar kilitli
    expect(nextLesson(notesDone)?.item.id, 'iv1');
  });

  test('lessonIdsInFirstTracks seviye seçimini doğru besler', () {
    // "Notaları biliyorum" (1 track) = tam olarak Notalar dersleri.
    final notesIds = lessonIdsInFirstTracks(1);
    expect(notesIds, [for (final it in curriculum[0].items) it.id]);

    // Bu id'ler tamam sayılınca zincir Aralıklar'ı açar → next iv1.
    final notesKnown = PlayerProgress(completedLessons: notesIds);
    expect(itemUnlocked(curriculum[1], 0, notesKnown), isTrue);
    expect(nextLesson(notesKnown)?.item.id, 'iv1');

    // 0 track → sıfırdan (boş).
    expect(lessonIdsInFirstTracks(0), isEmpty);

    // 4 track (Nota+Aralık+Akor+Tonalite) tamam → İşlev açılır → next fn1.
    final theoryKnown = PlayerProgress(
      completedLessons: lessonIdsInFirstTracks(4),
    );
    expect(itemUnlocked(curriculum[4], 0, theoryKnown), isTrue);
    expect(nextLesson(theoryKnown)?.item.id, 'fn1');
  });
}
