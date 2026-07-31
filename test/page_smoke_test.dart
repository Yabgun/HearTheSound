import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/echo.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_arpeggio_page.dart';
import 'package:hear_the_sound/features/chords/chord_inversion_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_quality_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_recognition_page.dart';
import 'package:hear_the_sound/features/intervals/interval_build_page.dart';
import 'package:hear_the_sound/features/intervals/interval_direction_page.dart';
import 'package:hear_the_sound/features/intervals/interval_learn_page.dart';
import 'package:hear_the_sound/features/intervals/interval_lesson.dart';
import 'package:hear_the_sound/features/intervals/interval_melody_page.dart';
import 'package:hear_the_sound/features/intervals/interval_recognition_page.dart';
import 'package:hear_the_sound/features/melody/echo_game_page.dart';
import 'package:hear_the_sound/features/melody/melody_lesson.dart';

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

  // Cihazdaki sistem çubuklarıyla kısalan ekranda, cevap geri bildirimi
  // açıldıktan sonra da tanıma ekranlarının taşmamasını korur. (Cihazda
  // görülen 3px "Sonraki" taşmalarının nöbetçisi.)
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
    // Ses-gecikmesi zamanlayıcılarını boşalt: müzikal CÜMLE çalan sayfalarda
    // (tek nota değil) çalma birkaç saniye sürer → 1 sn yetmez, teardown
    // "pending timer" hatası verir.
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

  testWidgets('akor arpej çizilir', (t) async {
    await smoke(
      t,
      ChordArpeggioPage(
        chords: _chordLesson('ch5').pool.take(2).toList(),
        player: fake,
        onComplete: () {},
        title: 'Arpej',
      ),
    );
  });

  // Akor tanıma ekranları kısa yükseklikte cevap sonrası taşmamalı — cihazda
  // görülen 3px taşmaların ve uzun nitelik etiketlerinin nöbetçisi.
  testWidgets('akor tanıma ekranları kısa ekranda taşmaz', (t) async {
    await compactAnsweredSmoke(
      t,
      ChordRecognitionPage(
        pool: _chordLesson('ch11').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
    await compactAnsweredSmoke(
      t,
      ChordQualityRecognitionPage(
        pool: _chordLesson('ch_quality_master').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
    await compactAnsweredSmoke(
      t,
      ChordInversionRecognitionPage(
        pool: _chordLesson('ch9').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  // EKO OYUNU — yeni yetenek track'inin çekirdek ekranı (etiketleme değil,
  // duyduğunu TEKRARLAMA). İki cevap modu da ilk çizimde güvenli olmalı.
  testWidgets('Eko oyunu tuş modunda çizilir (ilk ve son ders)', (t) async {
    for (final lesson in [melodyLessons.first, melodyLessons.last]) {
      await smoke(
        t,
        EchoGamePage(
          lesson: lesson,
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      );
    }
  });

  testWidgets('Eko oyunu söyleme modunda çizilir', (t) async {
    await smoke(
      t,
      EchoGamePage(
        lesson: melodyLessons.first,
        player: fake,
        mode: EchoInputMode.sing,
        onModeChanged: (_) {},
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('Eko oyunu kısa ekranda cevap sonrası taşmaz', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: EchoGamePage(
          lesson: melodyLessons.first, // 2 notalık ezgi
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      ),
    );
    // Ev sesi + ezgi çalınsın, cevap aşamasına geçilsin.
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    // İki notayı da gir → sonuç alanı (en taşma riskli hâl) açılır.
    for (var i = 0; i < 2; i++) {
      final pad = find.byType(InkWell).first;
      await t.ensureVisible(pad);
      await t.tap(pad);
      await t.pump(const Duration(milliseconds: 400));
    }
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(
      t.takeException(),
      isNull,
      reason: 'cevap sonrası taşma olmamalı',
    );
  });
}
