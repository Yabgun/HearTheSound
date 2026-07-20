import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
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
  return container;
}

Future<void> _openPlacementFromOffer(WidgetTester tester) async {
  // Welcome ekranındaki dil seçici (EN/TR) de TextButton içerir → spesifik ol.
  await tester.tap(find.widgetWithText(TextButton, "I'll calibrate later"));
  await tester.pumpAndSettle();

  // Seviye seçici → "kısa test" linki yerleştirme testine götürür.
  await tester.tap(
    find.widgetWithText(TextButton, 'Not sure? Take a quick test'),
  );
  await tester.pumpAndSettle();

  expect(find.byType(PlacementTestPage), findsOneWidget);
}

void main() {
  testWidgets('placement sayfasından geri dönmek onboarding’i bitirmez', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _openPlacementFromOffer(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(PlacementTestPage), findsNothing);
    expect(container.read(settingsProvider).onboarded, isFalse);
  });

  testWidgets('placement içinde sıfırdan başla seçimi onboarding’i bitirir', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    await _openPlacementFromOffer(tester);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboarded, isTrue);
  });

  testWidgets('seviye seçimi onboarding’i bitirir ve doğru dersleri açar', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);
    // Welcome → seviye seçici
    await tester.tap(find.widgetWithText(TextButton, "I'll calibrate later"));
    await tester.pumpAndSettle();
    // "Notaları biliyorum" → Notalar tamam sayılır, Aralıklardan başlar.
    await tester.tap(find.text('I can name notes'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboarded, isTrue);
    final p = container.read(progressProvider);
    expect(p.isLessonCompleted('first_notes'), isTrue); // Notalar tamam
    expect(p.isLessonCompleted('iv1'), isFalse); // Aralıklar değil
  });
}
