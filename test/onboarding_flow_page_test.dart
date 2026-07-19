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
  await tester.tap(find.byType(TextButton));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(FilledButton));
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
}
