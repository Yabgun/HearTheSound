import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paylaşılan prefs — main'de gerçek örnekle override edilir.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider main içinde override edilmeli');
});

/// Uygulama ayarları (şimdilik yalnızca hatırlatma).
class AppSettings {
  final bool reminderEnabled;
  final int reminderHour; // 0-23, dakika :00

  const AppSettings({this.reminderEnabled = false, this.reminderHour = 19});

  AppSettings copyWith({bool? reminderEnabled, int? reminderHour}) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() => AppSettings(
        reminderEnabled: _prefs.getBool('reminder_enabled') ?? false,
        reminderHour: _prefs.getInt('reminder_hour') ?? 19,
      );

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool('reminder_enabled', value);
    state = state.copyWith(reminderEnabled: value);
  }

  Future<void> setHour(int hour) async {
    await _prefs.setInt('reminder_hour', hour);
    state = state.copyWith(reminderHour: hour);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
