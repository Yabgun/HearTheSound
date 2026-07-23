import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/note_player.dart';
import '../audio/soundfont_bank.dart';
import '../core/content_locale.dart';
import '../data/cloud/cloud_sync.dart';
import '../notifications/notification_service.dart';

/// Paylaşılan prefs — main'de gerçek örnekle override edilir.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider main içinde override edilmeli');
});

/// Uygulama ayarları (hatırlatma + onboarding + tını + dil).
class AppSettings {
  final bool reminderEnabled;
  final int reminderHour; // 0-23, dakika :00
  final bool onboarded; // ilk açılış akışı tamamlandı mı
  final bool tutorialSeen; // ana ekran ilk-açılış coach-mark turu görüldü mü
  final Instrument instrument; // egzersiz tınısı (piyano/sentez)
  final String localeCode; // 'en' (varsayılan) | 'tr'

  const AppSettings({
    this.reminderEnabled = false,
    this.reminderHour = 19,
    this.onboarded = false,
    this.tutorialSeen = false,
    this.instrument = Instrument.piano,
    this.localeCode = 'en',
  });

  AppSettings copyWith({
    bool? reminderEnabled,
    int? reminderHour,
    bool? onboarded,
    bool? tutorialSeen,
    Instrument? instrument,
    String? localeCode,
  }) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      onboarded: onboarded ?? this.onboarded,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      instrument: instrument ?? this.instrument,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}

/// Prefs'teki dil anahtarını çözer. Varsayılan İngilizce.
String localeFromPrefs(SharedPreferences prefs) =>
    prefs.getString('locale') == 'tr' ? 'tr' : 'en';

/// Prefs'teki tını anahtarını çözer. Varsayılan piyano (gerçek tını).
Instrument instrumentFromPrefs(SharedPreferences prefs) =>
    prefs.getString('instrument') == 'synth'
    ? Instrument.synth
    : Instrument.piano;

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() => AppSettings(
    reminderEnabled: _prefs.getBool('reminder_enabled') ?? false,
    reminderHour: _prefs.getInt('reminder_hour') ?? 19,
    onboarded: _prefs.getBool('onboarded') ?? false,
    tutorialSeen: _prefs.getBool('tutorial_seen') ?? false,
    instrument: instrumentFromPrefs(_prefs),
    localeCode: localeFromPrefs(_prefs),
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

  /// Ana ekran ilk-açılış coach-mark turu görüldü olarak işaretle (bir kez).
  Future<void> setTutorialSeen(bool value) async {
    await _prefs.setBool('tutorial_seen', value);
    state = state.copyWith(tutorialSeen: value);
  }

  /// Tınıyı değiştirir: prefs'e yazar, global çalıcı fabrikasını günceller ve
  /// piyano seçildiyse SoundFont'u arkada ısıtır.
  Future<void> setInstrument(Instrument value) async {
    await _prefs.setString('instrument', value.name);
    NotePlayerConfig.instrument = value;
    if (value == Instrument.piano) {
      unawaited(SoundFontBank.instance.ensureLoaded());
    }
    state = state.copyWith(instrument: value);
  }

  /// Dili değiştirir: prefs + global içerik dili + (açıksa) hatırlatmayı yeni
  /// dilin metinleriyle yeniden kurar. MaterialApp state'i izlediği için tüm
  /// ağaç yeni dille yeniden çizilir.
  Future<void> setLocale(String code) async {
    await _prefs.setString('locale', code);
    ContentLocale.code = code;
    if (state.reminderEnabled) {
      await NotificationService.instance.scheduleDaily(
        hour: state.reminderHour,
      );
    }
    // Sunucu push'u da yeni dilde gelsin: token'ın kayıtlı locale'ini güncelle
    // (oturum yoksa sessizce atlanır). Ateşle-unut — dil değişimini bekletmez.
    unawaited(CloudSync.instance.registerDeviceToken());
    state = state.copyWith(localeCode: code);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
