import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/home/curriculum.dart';
import 'package:hear_the_sound/features/onboarding/onboarding_flow_page.dart';
import 'package:hear_the_sound/features/placement/placement_test_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryProgressRepository implements ProgressRepository {
  PlayerProgress progress = PlayerProgress.empty;

  @override
  PlayerProgress load() => progress;

  @override
  Future<void> save(PlayerProgress progress) async {
    this.progress = progress;
  }
}

Future<ProviderContainer> _pumpOnboarding(WidgetTester tester) async {
  // Uzun form/karşılama ekranları default 800×600'e sığmaz; yüksek bir yüzey
  // ver ki alttaki düğmeler (misafir/atla) tıklanabilir olsun.
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      progressRepositoryProvider.overrideWithValue(_MemoryProgressRepository()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OnboardingFlowPage()),
    ),
  );
  await tester.pumpAndSettle();

  // Akış artık karşılama → giriş → ad → avatar ile BAŞLIYOR. Bu testler
  // karşılama sonrası adımları (kalibrasyon/başlangıç noktası) sınadığından,
  // ilk dört adımı atlayıp welcome'a ilerliyoruz.
  await tester.tap(find.text("Let's begin")); // intro → signIn
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue as guest')); // signIn → nameSetup
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Skip for now')); // ad atla
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Skip for now')); // avatar atla
  await tester.pumpAndSettle();
  return container;
}

/// welcome → başlangıç noktası ekranı.
Future<void> _toStartPoint(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, "I'll calibrate later"));
  await tester.pumpAndSettle();
}

Future<void> _openPlacement(WidgetTester tester) async {
  await _toStartPoint(tester);
  await tester.tap(find.text('I already know some music'));
  await tester.pumpAndSettle();
  expect(find.byType(PlacementTestPage), findsOneWidget);
}

void main() {
  testWidgets('başlangıç noktası ekranı iki yol sunar (dört seviye kartı YOK)', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await _toStartPoint(tester);

    expect(find.text("I'm new to music"), findsOneWidget);
    expect(find.text('I already know some music'), findsOneWidget);
    // Kullanıcıya kendini etiketleten eski kartlar geri gelmesin: onların
    // sorunu, kullanıcının kendi seviyesini bilememesiydi.
    expect(find.text('I can name notes'), findsNothing);
    expect(find.text('I know my chords by ear'), findsNothing);
  });

  testWidgets('"müziğe yeniyim" testi HİÇ göstermez ve hemen bitirir', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _toStartPoint(tester);

    await tester.tap(find.text("I'm new to music"));
    await tester.pumpAndSettle();

    expect(find.byType(PlacementTestPage), findsNothing);
    expect(container.read(settingsProvider).onboarded, isTrue);
    // Sıfırdan başlayan hiçbir dersi "biliyor" saymaz.
    expect(container.read(progressProvider).completedLessons, isEmpty);
  });

  testWidgets('merdiven testinden geri dönmek onboarding’i bitirmez', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _openPlacement(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(PlacementTestPage), findsNothing);
    expect(container.read(settingsProvider).onboarded, isFalse);
  });

  testWidgets('testin içinden "sıfırdan başla" onboarding’i bitirir', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _openPlacement(tester);

    await tester.tap(find.text('Start from scratch instead'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboarded, isTrue);
    expect(container.read(progressProvider).completedLessons, isEmpty);
  });

  testWidgets('onboarding sonrası her hâlükârda açık bir ders var', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _toStartPoint(tester);
    await tester.tap(find.text("I'm new to music"));
    await tester.pumpAndSettle();

    // "Devam Et" hedefi boş kalırsa ana ekran ölü uçla açılır.
    expect(nextLesson(container.read(progressProvider)), isNotNull);
  });
}
