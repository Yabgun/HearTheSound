import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/note_player.dart';
import '../audio/soundfont_bank.dart';
import '../core/content_locale.dart';
import '../core/echo.dart';
import '../data/cloud/cloud_sync.dart';
import '../notifications/notification_service.dart';

/// Paylaşılan prefs — main'de gerçek örnekle override edilir.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider main içinde override edilmeli');
});

/// Görünen sürüm etiketi — "0.1.0 (1)" biçiminde. main() gerçek değeri
/// `PackageInfo`'dan okuyup override eder.
///
/// Varsayılan null = "bilinmiyor" ve Ayarlar satırı hiç çizilmez: yanlış bir
/// sürüm göstermek, hiç göstermemekten kötüdür (destek isteğinde kullanıcı
/// buradaki sayıyı bize okur).
final appVersionProvider = Provider<String?>((_) => null);

/// Uygulama ayarları (hatırlatma + onboarding + tını + dil).
///
/// Not: Günlük hatırlatmanın SAATİ ayar değil sabit ([NotificationService.
/// dailyReminderHour]) — kullanıcı yalnızca açık/kapalı seçer.
class AppSettings {
  final bool reminderEnabled;
  final bool onboarded; // ilk açılış akışı tamamlandı mı
  final bool tutorialSeen; // ana ekran ilk-açılış coach-mark turu görüldü mü

  /// Şarkı Çöz'ün ilk-açılış turu görüldü mü. AYRI bir bayrak: o modun kilit
  /// hareketi (ölçüye dokunup tek başına dinlemek) keşfedilebilir değil ve
  /// kullanıcı oraya ana ekran turundan aylar sonra gelebilir.
  final bool songTutorialSeen;
  final Instrument instrument; // egzersiz tınısı (piyano/sentez)
  final String localeCode; // 'en' (varsayılan) | 'tr'

  /// Açık / koyu / sisteme uy.
  ///
  /// Varsayılan AÇIK — sistem DEĞİL. Uygulamanın tasarlanmış kimliği açık tema
  /// ("Aydınlık stüdyo"); koyu tema bir TERCİH. Varsayılan "sistem" olduğunda
  /// telefonu koyu modda olan kullanıcı uygulamayı hiç seçim yapmadan koyu
  /// buluyor ve bunu "koyuya sabitlenmiş" diye okuyor (cihaz testinde tam
  /// olarak bu oldu). "Sistem" hâlâ seçenek, ama artık kullanıcının kararı.
  final ThemeMode themeMode;

  /// Eko oyununda tekrarın nasıl verileceği. Varsayılan TUŞ: her ortamda
  /// çalışır ve ilk temasta mikrofon izni istemez (sürtünmesiz başlangıç).
  final EchoInputMode echoInputMode;

  const AppSettings({
    this.reminderEnabled = false,
    this.onboarded = false,
    this.tutorialSeen = false,
    this.songTutorialSeen = false,
    this.instrument = Instrument.piano,
    this.localeCode = 'en',
    this.echoInputMode = EchoInputMode.tap,
    this.themeMode = ThemeMode.light,
  });

  AppSettings copyWith({
    bool? reminderEnabled,
    bool? onboarded,
    bool? tutorialSeen,
    bool? songTutorialSeen,
    Instrument? instrument,
    String? localeCode,
    EchoInputMode? echoInputMode,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      onboarded: onboarded ?? this.onboarded,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      songTutorialSeen: songTutorialSeen ?? this.songTutorialSeen,
      instrument: instrument ?? this.instrument,
      localeCode: localeCode ?? this.localeCode,
      echoInputMode: echoInputMode ?? this.echoInputMode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Prefs'teki dil anahtarını çözer. Varsayılan İngilizce.
String localeFromPrefs(SharedPreferences prefs) =>
    prefs.getString('locale') == 'tr' ? 'tr' : 'en';

/// Prefs'teki tema anahtarını çözer.
///
/// KAYIT YOKSA ya da tanınmıyorsa AÇIK tema: kullanıcı bir şey seçene kadar
/// uygulama kendi tasarlandığı hâlde açılır. Koyu tema ancak kullanıcı
/// isteyince gelir; sistem takibi de açıkça seçilmesi gereken bir seçenek.
ThemeMode themeModeFromPrefs(SharedPreferences prefs) =>
    switch (prefs.getString('theme_mode')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

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
    onboarded: _prefs.getBool('onboarded') ?? false,
    tutorialSeen: _prefs.getBool('tutorial_seen') ?? false,
    songTutorialSeen: _prefs.getBool('song_tutorial_seen') ?? false,
    instrument: instrumentFromPrefs(_prefs),
    localeCode: localeFromPrefs(_prefs),
    echoInputMode: _prefs.getString('echo_input_mode') == 'sing'
        ? EchoInputMode.sing
        : EchoInputMode.tap,
    themeMode: themeModeFromPrefs(_prefs),
  );

  /// Eko oyunu cevap modunu değiştirir (oyun içindeki seçiciden çağrılır).
  Future<void> setEchoInputMode(EchoInputMode mode) async {
    await _prefs.setString('echo_input_mode', mode.name);
    state = state.copyWith(echoInputMode: mode);
  }

  /// Temayı değiştirir. MaterialApp bu değeri izlediği için tüm ağaç yeni
  /// palette yeniden çizilir (renkler ThemeExtension'dan geldiği için
  /// ekranlarda tek satır değişiklik gerekmez).
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme_mode', mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool('reminder_enabled', value);
    state = state.copyWith(reminderEnabled: value);
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

  /// Şarkı Çöz turu görüldü olarak işaretle (bir kez).
  Future<void> setSongTutorialSeen(bool value) async {
    await _prefs.setBool('song_tutorial_seen', value);
    state = state.copyWith(songTutorialSeen: value);
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
      await NotificationService.instance.scheduleDaily();
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
