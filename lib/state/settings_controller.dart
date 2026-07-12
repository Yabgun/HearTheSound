import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paylaşılan prefs — main'de gerçek örnekle override edilir.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider main içinde override edilmeli');
});

/// Uygulama ayarları (hatırlatma + ilk açılış onboarding durumu).
class AppSettings {
  final bool reminderEnabled;
  final int reminderHour; // 0-23, dakika :00
  final bool onboarded; // ilk açılış akışı tamamlandı mı

  const AppSettings({
    this.reminderEnabled = false,
    this.reminderHour = 19,
    this.onboarded = false,
  });

  AppSettings copyWith({
    bool? reminderEnabled,
    int? reminderHour,
    bool? onboarded,
  }) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      onboarded: onboarded ?? this.onboarded,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() => AppSettings(
        reminderEnabled: _prefs.getBool('reminder_enabled') ?? false,
        reminderHour: _prefs.getInt('reminder_hour') ?? 19,
        onboarded: _prefs.getBool('onboarded') ?? false,
      );

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool('reminder_enabled', value);
    state = state.copyWith(reminderEnabled: value);
  }

  Future<void> setHour(int hour) async {
    await _prefs.setInt('reminder_hour', hour);
    state = state.copyWith(reminderHour: hour);
  }

  Future<void> setOnboarded(bool value) async {
    await _prefs.setBool('onboarded', value);
    state = state.copyWith(onboarded: value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
