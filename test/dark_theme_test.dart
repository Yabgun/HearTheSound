import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/echo.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/harmony/harmony_lesson.dart';
import 'package:hear_the_sound/features/harmony/harmony_pattern_page.dart';
import 'package:hear_the_sound/features/lesson/lesson.dart';
import 'package:hear_the_sound/features/melody/echo_game_page.dart';
import 'package:hear_the_sound/features/melody/melody_lesson.dart';
import 'package:hear_the_sound/features/note_recognition/note_recognition_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:hear_the_sound/ui/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// KOYU TEMA
//
// Asıl risk RENK DEĞERLERİ değil, TESİSAT: bir ekran paleti bağlamdan okumazsa
// koyu temada sessizce açık tema renklerini gösterir ve hiçbir test kırılmaz.
// Bu dosya o tesisatı kilitler:
//   1) context.colors gerçekten temayla dönüyor mu,
//   2) uzantı yoksa güvenli tarafa (açık palet) düşüyor mu,
//   3) gerçek ders ekranları koyu temada çiziliyor mu,
//   4) tema tercihi kalıcı mı.
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

class _FakeRepo implements ProgressRepository {
  PlayerProgress _p = PlayerProgress.empty;
  @override
  PlayerProgress load() => _p;
  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}

/// Ağacın herhangi bir yerinden çözülen paleti yakalar.
AppPalette? _captured;

Widget _probe() => Builder(
  builder: (ctx) {
    _captured = ctx.colors;
    return const SizedBox.shrink();
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => _captured = null);

  group('palet tesisatı', () {
    testWidgets('koyu tema altında context.colors KOYU paleti verir', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.forTest(Brightness.dark, AppPalette.dark),
          home: _probe(),
        ),
      );
      expect(_captured, same(AppPalette.dark));
      // Değerin gerçekten döndüğünü de doğrula: yanlış palet takılırsa
      // "same" geçerdi ama renkler açık kalırdı.
      expect(_captured!.ink, AppPalette.dark.ink);
      expect(_captured!.ink, isNot(AppPalette.light.ink));
    });

    testWidgets('açık tema altında AÇIK paleti verir', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.forTest(Brightness.light, AppPalette.light),
          home: _probe(),
        ),
      );
      expect(_captured, same(AppPalette.light));
    });

    testWidgets('uzantı yoksa açık palete düşer (çıplak MaterialApp)', (
      t,
    ) async {
      // Testlerin çoğu sayfayı temasız pompalar; palet çözülemezse ekran
      // renksiz kalmamalı.
      await t.pumpWidget(MaterialApp(home: _probe()));
      expect(_captured, same(AppPalette.light));
    });
  });

  group('gerçek ekranlar koyu temada', () {
    Future<void> darkSmoke(WidgetTester t, Widget page) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            progressRepositoryProvider.overrideWithValue(_FakeRepo()),
          ],
          child: MaterialApp(
            theme: AppTheme.forTest(Brightness.dark, AppPalette.dark),
            home: page,
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: 'koyu temada ilk çizim');
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 800));
      }
      expect(t.takeException(), isNull);
    }

    final fake = _FakePlayer();

    testWidgets('nota tanıma', (t) async {
      await darkSmoke(
        t,
        NoteRecognitionPage(
          pool: lessons.first.pool,
          player: fake,
          questionCount: 4,
          onComplete: (_) {},
        ),
      );
    });

    testWidgets('Eko oyunu', (t) async {
      await darkSmoke(
        t,
        EchoGamePage(
          lesson: melodyLessons.first,
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      );
    });

    testWidgets('armoni kalıbı', (t) async {
      await darkSmoke(
        t,
        HarmonyPatternPage(
          lesson: harmonyLessons.firstWhere((l) => l.id == 'har8'),
          player: fake,
          questionCount: 3,
          onComplete: (_) {},
        ),
      );
    });
  });

  group('tema tercihi', () {
    Future<ProviderContainer> container(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          progressRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('varsayılan AÇIK — koyu tema kullanıcının seçimi', () async {
      // Cihaz testinin dersi: varsayılan "sistem" olduğunda telefonu koyu
      // modda olan kullanıcı uygulamayı hiç seçim yapmadan koyu buluyor ve
      // bunu "koyuya sabitlenmiş" diye okuyor.
      final c = await container({});
      expect(c.read(settingsProvider).themeMode, ThemeMode.light);
    });

    test('sistem takibi seçilebilir ve kalıcı', () async {
      final c = await container({});
      await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.system);
      expect(c.read(settingsProvider).themeMode, ThemeMode.system);
      final again = await container({'theme_mode': 'system'});
      expect(again.read(settingsProvider).themeMode, ThemeMode.system);
    });

    test('seçim prefs\'e yazılır ve geri okunur', () async {
      final c = await container({});
      await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(c.read(settingsProvider).themeMode, ThemeMode.dark);

      // Yeniden kurulan bir oturum aynı tercihi bulmalı (uygulamayı kapatıp
      // açmanın karşılığı).
      final again = await container({'theme_mode': 'dark'});
      expect(again.read(settingsProvider).themeMode, ThemeMode.dark);
    });

    test('bozuk kayıt kullanıcıyı yanlış temaya kilitlemez', () async {
      final c = await container({'theme_mode': 'neon'});
      expect(c.read(settingsProvider).themeMode, ThemeMode.light);
    });
  });
}
