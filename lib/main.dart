import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import 'features/update/update_gate.dart';
import 'notifications/notification_service.dart';
import 'notifications/push_service.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';
import 'state/update_gate_controller.dart';
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
    await NotificationService.instance.scheduleDaily();
  }

  // İlerleme deposu: yerel prefs + (yapılandırıldıysa) bulut itme dekoratörü.
  final localRepo = PrefsProgressRepository(prefs);
  final ProgressRepository repo = isCloudConfigured
      ? SyncedProgressRepository(localRepo)
      : localRepo;

  // Build numarası (pubspec `+N`) — zorunlu güncelleme kapısı bu sayıyı
  // sunucudaki eşiklerle karşılaştırır. Okunamazsa 0 kalır → kapı fail-open.
  var currentBuild = 0;
  try {
    currentBuild = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  } catch (_) {}

  // Container'ı elle kuruyoruz ki açılış SONRASI arka plan bulut birleştirmesi
  // arayüzü tazeleyebilsin (progressProvider.reload).
  final container = ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      prefsProvider.overrideWithValue(prefs),
      currentBuildProvider.overrideWithValue(currentBuild),
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

  // Sunucu push (§21): Firebase'i başlat, token'ı al/kaydet. Açılışı BEKLETMEZ;
  // bulut kapalıysa ya da Firebase yoksa sessizce atlanır.
  unawaited(PushService.instance.init());
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
      // Güncelleme kapısı EN DIŞTA (§20): sürüm artık desteklenmiyorsa
      // onboarding/ana ekran hiç kurulmaz, kaçışsız güncelleme ekranı gelir.
      home: const UpdateGate(child: _RootGate()),
    );
  }
}

/// İlk açılışta onboarding, tamamlanınca ana ekran. `onboarded` set edilince
/// (onboarding sonu) bu widget yeniden kurulup ana ekrana geçer.
///
/// Mevcut kullanıcı (zaten ilerlemesi/kalibrasyonu olan) onboarding'i hiç
/// görmez — `onboarded` bayrağı sonradan eklendiğinden geçmişi olanı da
/// "onboarded" sayarız.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  // "Zaten geçmişi olan kullanıcı" kararı AÇILIŞTA BİR KEZ verilir (snapshot).
  // Aksi halde bu gate ilerlemeyi CANLI izler ve onboarding SIRASINDA kalibrasyon
  // (isCalibrated) ya da seviye seçimi (completedLessons) ilerlemeyi değiştirince
  // kullanıcıyı ana ekrana atardı → "vokal aralığını bulunca seviye seçme adımı
  // atlanıyor" hatası. Snapshot ile onboarding kesintisiz akar; ana ekrana yalnızca
  // 'onboarded' set edilince (akışın sonu) geçilir.
  late final bool _legacyUser;

  @override
  void initState() {
    super.initState();
    final p = ref.read(progressProvider);
    // isCalibrated DAHİL DEĞİL: kalibrasyon onboarding'in İÇİNDE yapılır; onu
    // "geçmiş" saymak kullanıcıyı akıştan atardı. Gerçek geçmiş = öğrenme
    // ilerlemesi (XP / tamamlanmış ders).
    _legacyUser = p.xp > 0 || p.completedLessons.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    final showOnboarding = !onboarded && !_legacyUser;
    return showOnboarding ? const OnboardingFlowPage() : const HomePage();
  }
}
