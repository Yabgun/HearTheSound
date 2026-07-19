import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'audio/note_player.dart';
import 'audio/soundfont_bank.dart';
import 'core/content_locale.dart';
import 'data/cloud/cloud_sync.dart';
import 'data/cloud/supabase_config.dart';
import 'data/progress_repository.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_flow_page.dart';
import 'notifications/notification_service.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // İçerik dili: bildirim metinleri ve ders verileri bu bayrağı okur; her
  // şeyden ÖNCE ayarlanmalı. Varsayılan İngilizce, Ayarlar'dan Türkçe seçilir.
  ContentLocale.code = localeFromPrefs(prefs);

  // Tını seçimi: çalıcı fabrikasını ayarla; piyano ise SoundFont'u arkada
  // ısıt (ilk derse gelindiğinde hazır olsun — açılışı BEKLETMEZ).
  NotePlayerConfig.instrument = instrumentFromPrefs(prefs);
  if (NotePlayerConfig.instrument == Instrument.piano) {
    unawaited(SoundFontBank.instance.ensureLoaded());
  }

  // Bulut senkron (opsiyonel): supabase_config doluysa istemciyi başlat.
  // Boşsa uygulama tamamen yerel çalışır — bugünkü davranış birebir.
  if (isCloudConfigured) {
    await Supabase.initialize(
      url: kSupabaseUrl,
      // Yeni panolar "publishable" anahtar verir; eski "anon public" JWT de
      // aynı parametreyle çalışır (ikisi de istemciye gömülmek için tasarlandı).
      publishableKey: kSupabaseAnonKey,
    );
  }

  // Bildirim servisini hazırla; hatırlatma açıksa açılışta yeniden zamanla
  // (yeniden başlatma sonrası da yaşasın diye).
  await NotificationService.instance.init();
  if (prefs.getBool('reminder_enabled') ?? false) {
    await NotificationService.instance.scheduleDaily(
      hour: prefs.getInt('reminder_hour') ?? 19,
    );
  }

  // İlerleme deposu: yerel prefs + (yapılandırıldıysa) bulut itme dekoratörü.
  final localRepo = PrefsProgressRepository(prefs);
  final ProgressRepository repo = isCloudConfigured
      ? SyncedProgressRepository(localRepo)
      : localRepo;

  // Container'ı elle kuruyoruz ki açılış SONRASI arka plan bulut birleştirmesi
  // arayüzü tazeleyebilsin (progressProvider.reload).
  final container = ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      prefsProvider.overrideWithValue(prefs),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HearTheSoundApp(),
    ),
  );

  // Açılışta oturum zaten açıksa: buluttakiyle kayıpsız birleştir, UI'yı tazele.
  // Açılışı BEKLETMEZ; hata olursa sessizce yerel akış sürer.
  if (isCloudConfigured && CloudSync.instance.isSignedIn) {
    unawaited(
      CloudSync.instance.pullAndMerge(repo).then((merged) {
        if (merged != null) {
          container.read(progressProvider.notifier).reload();
        }
      }),
    );
  }
}

class HearTheSoundApp extends ConsumerWidget {
  const HearTheSoundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dil ayarını izle: değişince içerik bayrağını güncelle ve tüm ağacı yeni
    // dille yeniden kur (locale MaterialApp'e de geçer — Material bileşen
    // metinleri için).
    final localeCode = ref.watch(settingsProvider.select((s) => s.localeCode));
    ContentLocale.code = localeCode;

    return MaterialApp(
      title: 'HearTheSound',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: Locale(localeCode),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _RootGate(),
    );
  }
}

/// İlk açılışta onboarding, tamamlanınca ana ekran. `onboarded` set edilince
/// (onboarding sonu) bu widget yeniden kurulup ana ekrana geçer.
///
/// Mevcut kullanıcı (zaten ilerlemesi/kalibrasyonu olan) onboarding'i hiç
/// görmez — `onboarded` bayrağı sonradan eklendiğinden geçmişi olanı da
/// "onboarded" sayarız.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    final progress = ref.watch(progressProvider);
    final hasHistory =
        progress.xp > 0 ||
        progress.completedLessons.isNotEmpty ||
        progress.isCalibrated;
    final showOnboarding = !onboarded && !hasHistory;
    return showOnboarding ? const OnboardingFlowPage() : const HomePage();
  }
}
