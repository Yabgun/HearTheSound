import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/song/song_solve_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';

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
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
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
}
