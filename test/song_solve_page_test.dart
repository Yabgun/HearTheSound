import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/song/song_solve_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// ŞARKI ÇÖZ — ekranın sözleşmeleri
//
// Bu bir MOD, ders değil. En kritik iki güvence:
//   (a) Kalıbı Çöz dersi bitmeden AÇILMAZ (mekaniği önce orada öğreniyor).
//   (b) İlerlemeye XP yazar ama MÜFREDATI KİRLETMEZ — 'song_solve' bir ders
//       kimliği değildir; tamamlanan dersler listesine girerse hem "kaç ders
//       bitirdin" sayacı hem kilit zinciri bozulur.
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

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository(this.progress);
  PlayerProgress progress;

  @override
  PlayerProgress load() => progress;

  @override
  Future<void> save(PlayerProgress progress) async {
    this.progress = progress;
  }
}

void main() {
  final fake = _FakePlayer();

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool unlocked,
    double textScale = 1.0,
    bool tutorialSeen = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Tur varsayılan olarak "görüldü": çözme akışını sınayan testler
    // overlay'in arkasına dokunamaz. Turu sınayan test bunu açıkça kapatır.
    SharedPreferences.setMockInitialValues({
      'song_tutorial_seen': tutorialSeen,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        progressRepositoryProvider.overrideWithValue(
          _MemoryProgressRepository(
            PlayerProgress(
              completedLessons: unlocked ? [kSongSolveUnlockLesson] : const [],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SongSolvePage(player: fake),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Şarkıyı çalma gecikmelerini boşaltır (teardown'da bekleyen zamanlayıcı
  /// kalmasın).
  Future<void> settleAudio(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
  }

  testWidgets('Kalıbı Çöz bitmeden kilitli — zorluk kartları yok', (t) async {
    await pump(t, unlocked: false);
    expect(find.textContaining('Crack the Pattern'), findsOneWidget);
    expect(find.text('Short song'), findsNothing);
    expect(find.text('Full song'), findsNothing);
  });

  testWidgets('kilit açılınca üç zorluk sunulur', (t) async {
    await pump(t, unlocked: true);
    expect(find.text('Short song'), findsOneWidget);
    expect(find.text('Full song'), findsOneWidget);
    expect(find.text('Real thing'), findsOneWidget);
  });

  testWidgets('şarkı çözülür: ölçüler dolar, sonuç açılır, XP yazılır', (
    t,
  ) async {
    final container = await pump(t, unlocked: true);
    await t.tap(find.text('Short song'));
    await settleAudio(t);

    // Palet, ölçü ızgarasından SONRAKİ Wrap'tir. (Alt eylem düğmeleri de
    // InkWell içerdiği için "son InkWell" paleti değil "Çözdüm"ü verirdi.)
    final paletteTile = find.descendant(
      of: find.byType(Wrap).last,
      matching: find.byType(InkWell),
    );
    // Her dokunuş, üzerinde çalışılan ölçüye yazar ve imleci ilerletir.
    for (var i = 0; i < 4; i++) {
      await t.tap(paletteTile.first);
      await t.pump(const Duration(milliseconds: 300));
    }

    final check = find.widgetWithText(FilledButton, 'Check it');
    expect(check, findsOneWidget, reason: '4 ölçü dolunca kontrol açılmalı');
    await t.tap(check);
    await t.pump();

    expect(find.textContaining('bars right'), findsOneWidget);
    expect(t.takeException(), isNull);

    final progress = container.read(progressProvider);
    expect(
      progress.skillXp.containsKey(kSongSolveSkillId),
      isTrue,
      reason: 'mod ilerlemeye işlenmeli',
    );
    // MÜFREDATI KİRLETME testi: mod bir ders değildir.
    expect(progress.completedLessons, isNot(contains(kSongSolveSkillId)));
    expect(progress.reviews.containsKey(kSongSolveSkillId), isFalse);

    await settleAudio(t);
  });

  testWidgets('ölçüye dokununca o ölçü tek başına çalar (çökme yok)', (t) async {
    await pump(t, unlocked: true);
    await t.tap(find.text('Full song'));
    await settleAudio(t);

    // İlk InkWell'ler ölçülerdir; 8 ölçülük şarkıda hepsi çizilmiş olmalı.
    await t.tap(find.byType(InkWell).first);
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await settleAudio(t);
  });

  testWidgets('en yoğun şarkı 1.3x metin ölçeğinde taşmaz', (t) async {
    await pump(t, unlocked: true, textScale: 1.3);
    // "Gerçeği": 8 ölçü + iki tuzaklı palet = ekranın en kalabalık hâli.
    await t.tap(find.text('Real thing'));
    await settleAudio(t);
    expect(t.takeException(), isNull, reason: '1.3x ölçekte taşma olmamalı');
  });

  // Modun kilit hareketi ("ölçüye dokun, tek başına dinle") keşfedilebilir
  // değil — cihaz geri bildirimi: "genel kitlenin aklına gelmeyebilir".
  // Üç katmanın da yerinde olduğunu kilitleriz.
  group('ölçüye dokunma öğretilir', () {
    testWidgets('ilk şarkıda tur AÇILIR ve bir kez gösterilir', (t) async {
      final container = await pump(
        t,
        unlocked: true,
        tutorialSeen: false,
      );
      await t.tap(find.text('Short song'));
      await settleAudio(t);

      expect(
        find.textContaining('Stuck on a bar?'),
        findsOneWidget,
        reason: 'ilk şarkıda tur kendiliğinden açılmalı',
      );

      // Turu bitir → bir daha açılmasın diye işaretlenir.
      await t.tap(find.widgetWithText(TextButton, 'Skip'));
      await t.pump();
      expect(find.textContaining('Stuck on a bar?'), findsNothing);
      expect(container.read(settingsProvider).songTutorialSeen, isTrue);
      await settleAudio(t);
    });

    testWidgets('tur görülmüşse kendiliğinden açılmaz', (t) async {
      await pump(t, unlocked: true);
      await t.tap(find.text('Short song'));
      await settleAudio(t);
      expect(find.textContaining('Stuck on a bar?'), findsNothing);
    });

    testWidgets('kalıcı ipucu + başlıktaki düğme her zaman durur', (t) async {
      await pump(t, unlocked: true);
      await t.tap(find.text('Short song'));
      await settleAudio(t);

      // (a) Ekranda kalıcı tek satır ipucu.
      expect(find.text('Tap a bar to hear it on its own'), findsOneWidget);

      // (b) Turu atlayan/unutan kullanıcı için her an geri açan düğme.
      await t.tap(find.byIcon(Icons.help_outline_rounded));
      await t.pump();
      expect(find.textContaining('Stuck on a bar?'), findsOneWidget);
      await settleAudio(t);
    });
  });
}

