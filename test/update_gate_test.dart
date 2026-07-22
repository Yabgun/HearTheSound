import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/version_gate.dart';
import 'package:hear_the_sound/features/update/update_gate.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:hear_the_sound/state/update_gate_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// §20 GÜNCELLEME KAPISI — uçtan uca davranış:
// önbellekten senkron engelleme · taze config ile canlı kill-switch ·
// fail-open · önerinin sürüm-başına susturulması.
// -----------------------------------------------------------------------------

void main() {
  Future<Widget> app({
    required int currentBuild,
    Map<String, Object> prefsSeed = const {},
    Future<AppConfig?> Function()? fetcher,
  }) async {
    SharedPreferences.setMockInitialValues(prefsSeed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        currentBuildProvider.overrideWithValue(currentBuild),
        appConfigFetcherProvider.overrideWithValue(fetcher ?? () async => null),
      ],
      child: const MaterialApp(
        home: UpdateGate(child: Scaffold(body: Text('APP CONTENT'))),
      ),
    );
  }

  testWidgets('config yokken uygulama normal açılır (fail-open)', (t) async {
    await t.pumpWidget(await app(currentBuild: 1));
    await t.pump(); // microtask'taki refresh otursun
    expect(find.text('APP CONTENT'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('önbellekteki force config uygulamayı AÇILIŞTA engeller '
      '(uçak moduyla atlatılamaz)', (t) async {
    await t.pumpWidget(
      await app(
        currentBuild: 1,
        prefsSeed: {
          'app_config_cache_v1':
              const AppConfig(minSupportedBuild: 5, latestBuild: 5).toJson(),
        },
        fetcher: () async => null, // çevrimdışı — yine de kilitli
      ),
    );
    await t.pump();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('APP CONTENT'), findsNothing);
    // Play düğmesi var.
    expect(find.text('Update on Play Store'), findsOneWidget);
  });

  testWidgets('taze force config oturum ORTASINDA ekranı kapıya çevirir '
      '(kill-switch)', (t) async {
    await t.pumpWidget(
      await app(
        currentBuild: 2,
        fetcher: () async =>
            const AppConfig(minSupportedBuild: 9, latestBuild: 9),
      ),
    );
    // İlk kare: önbellek boş → içerik görünür.
    expect(find.text('APP CONTENT'), findsOneWidget);

    // refresh microtask'ı tamamlanınca kapı iner.
    await t.pump();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('APP CONTENT'), findsNothing);
  });

  testWidgets('panel mesajı varsa varsayılan metin yerine o görünür', (t) async {
    await t.pumpWidget(
      await app(
        currentBuild: 1,
        prefsSeed: {
          'app_config_cache_v1': const AppConfig(
            minSupportedBuild: 5,
            messageEn: 'Custom maintenance note',
          ).toJson(),
        },
      ),
    );
    await t.pump();
    expect(find.text('Custom maintenance note'), findsOneWidget);
  });

  testWidgets('öneri kartı: göster → kapat → aynı sürüm için bir daha çıkmaz',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final overrides = [
      prefsProvider.overrideWithValue(prefs),
      currentBuildProvider.overrideWithValue(3),
      appConfigFetcherProvider.overrideWithValue(
        () async => const AppConfig(minSupportedBuild: 1, latestBuild: 7),
      ),
    ];

    await t.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(body: UpdateSuggestCard()),
        ),
      ),
    );
    await t.pump(); // refresh → suggest
    expect(find.text('A new version is available on Play Store.'),
        findsOneWidget);

    await t.tap(find.byTooltip('Dismiss'));
    await t.pump();
    expect(find.text('A new version is available on Play Store.'), findsNothing);
    // Susturma sürüm-başına kalıcı yazıldı.
    expect(prefs.getInt('update_suggest_dismissed_build'), 7);
  });

  testWidgets('force sırasında geri tuşu kapıyı kapatamaz', (t) async {
    await t.pumpWidget(
      await app(
        currentBuild: 1,
        prefsSeed: {
          'app_config_cache_v1':
              const AppConfig(minSupportedBuild: 5).toJson(),
        },
      ),
    );
    await t.pump();

    final popScope = t.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
