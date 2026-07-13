import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_inversion_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_quality_recognition_page.dart';
import 'package:hear_the_sound/features/function/function_learn_page.dart';
import 'package:hear_the_sound/features/function/function_lesson.dart';
import 'package:hear_the_sound/features/function/function_recognition_page.dart';
import 'package:hear_the_sound/features/intervals/interval_learn_page.dart';
import 'package:hear_the_sound/features/intervals/interval_lesson.dart';
import 'package:hear_the_sound/features/intervals/interval_recognition_page.dart';
import 'package:hear_the_sound/features/progression/progression_learn_page.dart';
import 'package:hear_the_sound/features/progression/progression_lesson.dart';
import 'package:hear_the_sound/features/progression/progression_recognition_page.dart';

// Ses eklentisi çağırmayan sahte oynatıcı — testte plugin hatası olmasın.
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

ChordLesson _chordLesson(String id) =>
    chordLessons.firstWhere((l) => l.id == id);

void main() {
  final fake = _FakePlayer();

  // İlk çizimde exception fırlamadığını doğrular; sonra ses-gecikmesi
  // zamanlayıcılarını boşaltır (pending-timer teardown hatası olmasın).
  // Yüzey uzun bir telefon boyutuna ayarlanır — varsayılan 800×600 test
  // penceresi kısa olduğundan gerçekçi olmayan layout taşmaları vermesin.
  Future<void> smoke(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: page));
    expect(tester.takeException(), isNull, reason: 'ilk çizimde hata olmamalı');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('A1/A4 nitelik tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordQualityRecognitionPage(
        pool: _chordLesson('ch5').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A3 çevrim tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordInversionRecognitionPage(
        pool: _chordLesson('ch9').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A2 aralık öğren + tanıma çizilir', (t) async {
    await smoke(
      t,
      IntervalLearnPage(
        lesson: intervalLessons.first,
        player: fake,
        onReady: () {},
      ),
    );
    await smoke(
      t,
      IntervalRecognitionPage(
        pool: intervalLessons.first.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A5 işlev öğren + tanıma çizilir', (t) async {
    await smoke(
      t,
      FunctionLearnPage(
        lesson: functionLessons.first,
        player: fake,
        onReady: () {},
      ),
    );
    await smoke(
      t,
      FunctionRecognitionPage(
        pool: functionLessons.first.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A6 ilerleme öğren + tanıma çizilir', (t) async {
    await smoke(
      t,
      ProgressionLearnPage(
        lesson: progressionLessons.first,
        player: fake,
        onReady: () {},
      ),
    );
    await smoke(
      t,
      ProgressionRecognitionPage(
        pool: progressionLessons.first.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });
}
