import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_inversion_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_arpeggio_page.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_quality_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_recognition_page.dart';
import 'package:hear_the_sound/features/function/function_build_page.dart';
import 'package:hear_the_sound/features/function/function_learn_page.dart';
import 'package:hear_the_sound/features/function/function_lesson.dart';
import 'package:hear_the_sound/features/function/function_recognition_page.dart';
import 'package:hear_the_sound/features/function/function_root_sing_page.dart';
import 'package:hear_the_sound/features/intervals/interval_build_page.dart';
import 'package:hear_the_sound/features/intervals/interval_direction_page.dart';
import 'package:hear_the_sound/features/intervals/interval_learn_page.dart';
import 'package:hear_the_sound/features/intervals/interval_lesson.dart';
import 'package:hear_the_sound/features/intervals/interval_melody_page.dart';
import 'package:hear_the_sound/features/intervals/interval_recognition_page.dart';
import 'package:hear_the_sound/features/progression/progression_build_page.dart';
import 'package:hear_the_sound/features/progression/progression_learn_page.dart';
import 'package:hear_the_sound/features/progression/progression_lesson.dart';
import 'package:hear_the_sound/features/progression/progression_recognition_page.dart';
import 'package:hear_the_sound/features/tonality/tonality_learn_page.dart';
import 'package:hear_the_sound/features/tonality/tonality_lesson.dart';
import 'package:hear_the_sound/features/tonality/tonality_recognition_page.dart';
import 'package:hear_the_sound/features/tonality/tonality_sing_page.dart';

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

  // Cihazdaki sistem çubuklarıyla kısalan ekranda, cevap geri bildirimi açıldıktan
  // sonra da işlev ekranlarının taşmamasını korur.
  Future<void> compactAnsweredSmoke(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    final firstOption = find.byType(InkWell).first;
    await tester.ensureVisible(firstOption);
    await tester.tap(firstOption);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.takeException(),
      isNull,
      reason: 'cevap sonrası taşma olmamalı',
    );
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

  testWidgets('A2 aralık öğren + kur + yön + uygula + tanıma çizilir', (
    t,
  ) async {
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
      IntervalBuildPage(
        pool: intervalLessons.first.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      IntervalDirectionPage(
        pool: intervalLessons.first.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      IntervalMelodyPage(
        pool: intervalLessons.first.pool,
        player: fake,
        onComplete: () {},
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

  testWidgets('A7 harmonik aralık öğren + kur + tanıma çizilir', (t) async {
    final harmonicLesson = intervalLessons.firstWhere((l) => l.harmonic);
    await smoke(
      t,
      IntervalLearnPage(
        lesson: harmonicLesson,
        player: fake,
        harmonic: true,
        onReady: () {},
      ),
    );
    await smoke(
      t,
      IntervalBuildPage(
        pool: harmonicLesson.pool,
        player: fake,
        harmonic: true,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      IntervalRecognitionPage(
        pool: harmonicLesson.pool,
        player: fake,
        harmonic: true,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A8 yeni kök akor tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordRecognitionPage(
        pool: _chordLesson('ch11').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A5 işlev öğren + kur + kök söyle + tanıma çizilir', (t) async {
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
      FunctionBuildPage(
        pool: functionLessons.first.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      FunctionRootSingPage(
        pool: functionLessons.first.pool,
        player: fake,
        onComplete: () {},
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

  testWidgets('işlev ekranları kısa yükseklikte cevap sonrası taşmaz', (
    t,
  ) async {
    await compactAnsweredSmoke(
      t,
      FunctionBuildPage(
        pool: functionLessons.last.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await compactAnsweredSmoke(
      t,
      FunctionRecognitionPage(
        pool: functionLessons.last.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('Tonalite öğren + söyle + tanıma çizilir', (t) async {
    await smoke(
      t,
      TonalityLearnPage(
        lesson: tonalityLessons.first,
        player: fake,
        onReady: () {},
      ),
    );
    await smoke(
      t,
      TonalitySingPage(
        pool: tonalityLessons.first.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      TonalityRecognitionPage(
        pool: tonalityLessons.first.pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A6 ilerleme öğren + kur + arpej + tanıma çizilir', (t) async {
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
      ProgressionBuildPage(
        pool: progressionLessons.first.pool,
        player: fake,
        onComplete: () {},
      ),
    );
    await smoke(
      t,
      ChordArpeggioPage(
        chords: progressionLessons.first.pool.first.chords.take(2).toList(),
        player: fake,
        onComplete: () {},
        title: 'İlerlemeyi Arpejle',
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
