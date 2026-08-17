import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_arpeggio_page.dart';
import 'package:hear_the_sound/features/lesson/lesson.dart';
import 'package:hear_the_sound/features/lesson/sing_notes_page.dart';
import 'package:hear_the_sound/features/note_recognition/note_recognition_page.dart';
import 'package:hear_the_sound/core/echo.dart';
import 'package:hear_the_sound/features/harmony/harmony_choice_page.dart';
import 'package:hear_the_sound/features/harmony/harmony_find_page.dart';
import 'package:hear_the_sound/features/harmony/harmony_lesson.dart';
import 'package:hear_the_sound/features/harmony/harmony_pattern_page.dart';
import 'package:hear_the_sound/features/melody/echo_game_page.dart';
import 'package:hear_the_sound/features/melody/melody_lesson.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_echo_page.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_lesson.dart';

// -----------------------------------------------------------------------------
// ERİŞİLEBİLİRLİK — BÜYÜK METİN ÖLÇEĞİ (1.3x)
//
// Kullanıcı sistem yazı boyutunu büyüttüğünde egzersiz ekranları taşmamalı.
// Telefon boyutunda (420×960) 1.3x ölçekle ilk çizim + birkaç kare pompalanır;
// RenderFlex taşması exception olarak yakalanır.
// -----------------------------------------------------------------------------

class _FakePlayer implements NotePlayer {
  @override
  Future<void> play(Note note) async {}
  @override
  Future<void> playChord(List<Note> notes) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  final fake = _FakePlayer();

  Future<void> scaledSmoke(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: page,
      ),
    );
    expect(tester.takeException(), isNull, reason: '1.3x ilk çizim taşmamalı');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(tester.takeException(), isNull, reason: '1.3x sonraki kareler');
  }

  testWidgets('nota tanıma 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      NoteRecognitionPage(
        pool: lessons.first.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('nota söyleme 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      SingNotesPage(pool: lessons.first.pool, player: fake, onComplete: () {}),
    );
  });

  testWidgets('akor arpej 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      ChordArpeggioPage(
        chords: [Chord(Note.fromName('C', 4), ChordQuality.major)],
        player: fake,
        onComplete: () {},
        title: 'Arpej',
      ),
    );
  });

  // NOT: aralık tanıma testi kaldırıldı — "Aralıklar" track'i dağıtıldı.

  testWidgets('Eko oyunu 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      EchoGamePage(
        lesson: melodyLessons.last, // en çok nota + en geniş tuş sırası
        player: fake,
        mode: EchoInputMode.tap,
        onModeChanged: (_) {},
        onComplete: (_) {},
      ),
    );
  });

  // Armoni ekranlarında taşma riski en yüksek örnekler seçildi: en uzun şık
  // metni, en geniş tuş sırası + çok yuvalı bas hattı, en kalabalık palet.
  testWidgets('armoni algı ekranı 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      HarmonyChoicePage(
        lesson: harmonyLessons.firstWhere((l) => l.id == 'har2'),
        player: fake,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('armoni bas hattı ekranı 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      HarmonyFindPage(
        lesson: harmonyLessons.firstWhere((l) => l.id == 'har_bassline'),
        player: fake,
        mode: EchoInputMode.tap,
        onModeChanged: (_) {},
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('armoni tuzaklı kalıp ekranı 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      HarmonyPatternPage(
        lesson: harmonyLessons.firstWhere((l) => l.id == 'har_decoys'),
        player: fake,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('ritim eko oyunu 1.3x ölçekte taşmaz', (t) async {
    await scaledSmoke(
      t,
      RhythmEchoPage(
        lesson: rhythmLessons.last, // en uzun kalıp + en çok vuruş
        player: fake,
        onComplete: (_) {},
      ),
    );
  });
}
