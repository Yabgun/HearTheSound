import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/settings/settings_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// AYARLAR EKRANI
//
// İki şeyi kilitler:
//  1) HESAP EYLEMİ AppBar'ın SAĞINDA — gövdedeki büyük hesap bloğu geri gelirse
//     (ya da giriş düğmesi yeniden gövdeye kayarsa) test kırmızı yanar.
//  2) SÜRÜM SATIRI — okunamadığında YOK, okunduğunda "Sürüm x.y.z (n)".
//     Yanlış sürüm göstermektense hiç göstermemek doğrudur.
//
// Not: oturum AÇIK hâli burada test edilemiyor — `CloudSync` bir singleton ve
// gerçek Supabase istemcisine bağlı (testte kullanıcı hep null). Bu yüzden
// testler girişsiz görünümü kilitliyor.
// -----------------------------------------------------------------------------

class _FakeRepo implements ProgressRepository {
  PlayerProgress _p = PlayerProgress.empty;
  @override
  PlayerProgress load() => _p;
  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}

Future<Widget> _wrap({
  String? version,
  double textScale = 1.0,
  String locale = 'en',
}) async {
  SharedPreferences.setMockInitialValues({'locale': locale});
  final prefs = await SharedPreferences.getInstance();
  ContentLocale.code = locale;
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      progressRepositoryProvider.overrideWithValue(_FakeRepo()),
      appVersionProvider.overrideWithValue(version),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const SettingsPage(),
    ),
  );
}

void main() {
  // Dil global bir bayrak; her testten sonra varsayılana dönmeli ki sıradaki
  // test dosyası İngilizce bulsun.
  tearDown(() => ContentLocale.code = 'en');

  Future<void> pumpSettings(
    WidgetTester tester, {
    String? version,
    double textScale = 1.0,
    String locale = 'en',
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      await _wrap(version: version, textScale: textScale, locale: locale),
    );
    await tester.pump();
  }

  testWidgets('ayarlar ekranı hatasız çizilir', (t) async {
    await pumpSettings(t, version: '0.1.0 (1)');
    expect(t.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
  });

  testWidgets('giriş eylemi AppBar\'da, gövdede DEĞİL', (t) async {
    await pumpSettings(t);
    final signIn = find.text('Sign in');
    expect(signIn, findsOneWidget);
    // AppBar'ın içinde olmalı: gövdeye kayarsa liste yine "Sign in" gösterirdi
    // ama bu eşleşme başarısız olur.
    expect(
      find.descendant(of: find.byType(AppBar), matching: signIn),
      findsOneWidget,
    );
  });

  testWidgets('girişsizken gövdede hesap bloğu yok', (t) async {
    await pumpSettings(t);
    // Oturum kapalıyken yapılacak tek iş AppBar'daki giriş; eşitleme/silme
    // satırlarının hesabı olmayan kullanıcıya gösterilmesi anlamsızdı.
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Delete account & data'), findsNothing);
  });

  testWidgets('nota adları satırı kartı açar', (t) async {
    await pumpSettings(t);
    await t.tap(find.text('Note names'));
    await t.pumpAndSettle();
    // Ders ekranlarındaki ℹ️ ile AYNI kart — içerik tek yerde yaşıyor.
    expect(find.text('Do'), findsOneWidget);
    expect(find.text('Si'), findsOneWidget);
  });

  testWidgets('sürüm satırı bilindiğinde görünür', (t) async {
    await pumpSettings(t, version: '0.1.0 (1)');
    await t.scrollUntilVisible(find.text('Version 0.1.0 (1)'), 200);
    expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
  });

  testWidgets('sürüm okunamadıysa satır hiç çizilmez', (t) async {
    await pumpSettings(t); // appVersionProvider = null
    expect(find.textContaining('Version'), findsNothing);
  });

  testWidgets('TR: giriş ve sürüm çevrilir', (t) async {
    await pumpSettings(t, version: '0.1.0 (1)', locale: 'tr');
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Sürüm 0.1.0 (1)'), 200);
    expect(find.text('Sürüm 0.1.0 (1)'), findsOneWidget);
  });

  testWidgets('1.3x metin ölçeğinde taşma yok', (t) async {
    await pumpSettings(t, version: '0.1.0 (1)', textScale: 1.3);
    expect(t.takeException(), isNull, reason: '1.3x ilk çizim taşmamalı');
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(t.takeException(), isNull, reason: '1.3x sonraki kareler');
  });
}
