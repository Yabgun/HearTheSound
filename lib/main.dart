import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/progress_repository.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_flow_page.dart';
import 'notifications/notification_service.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Bildirim servisini hazırla; hatırlatma açıksa açılışta yeniden zamanla
  // (yeniden başlatma sonrası da yaşasın diye).
  await NotificationService.instance.init();
  if (prefs.getBool('reminder_enabled') ?? false) {
    await NotificationService.instance
        .scheduleDaily(hour: prefs.getInt('reminder_hour') ?? 19);
  }

  runApp(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          PrefsProgressRepository(prefs),
        ),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const HearTheSoundApp(),
    ),
  );
}

class HearTheSoundApp extends StatelessWidget {
  const HearTheSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Marka rengi (amber/altın) çekirdekli koyu tema.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE0912B),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'HearTheSound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
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
    final hasHistory = progress.xp > 0 ||
        progress.completedLessons.isNotEmpty ||
        progress.isCalibrated;
    final showOnboarding = !onboarded && !hasHistory;
    return showOnboarding ? const OnboardingFlowPage() : const HomePage();
  }
}
