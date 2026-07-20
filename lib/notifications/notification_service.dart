import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/content_locale.dart';

// -----------------------------------------------------------------------------
// NotificationService — yerel bildirimler (günlük hatırlatma + test)
//
// Singleton; main'de init() edilir. Günlük hatırlatma "inexact" modda zamanlanır
// (SCHEDULE_EXACT_ALARM özel izni gerekmez) ve her uygulama açılışında (main)
// yeniden kurulur, böylece yeniden başlatmadan sonra da yaşar.
// -----------------------------------------------------------------------------

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _dailyId = 1;
  static const int _testId = 2;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Yerel saat dilimi alınamazsa varsayılan (UTC) ile devam.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    _ready = true;
  }

  /// Android 13+ bildirim iznini ister; verildiyse true.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true; // eski sürümlerde izin gerekmez
  }

  NotificationDetails _details() => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      t(en: 'Daily Reminder', tr: 'Günlük Hatırlatma'),
      channelDescription: t(
        en: 'Daily practice reminders',
        tr: 'Günlük pratik hatırlatmaları',
      ),
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Hemen bir test bildirimi gösterir (doğrulama için).
  Future<void> showTestNow() async {
    await _plugin.show(
      id: _testId,
      title: 'HearTheSound',
      body: t(
        en: 'Notifications are working! This is how I\'ll remind you.',
        tr: 'Bildirimler çalışıyor! Seni böyle hatırlatacağım.',
      ),
      notificationDetails: _details(),
    );
  }

  /// Her gün [hour]:[minute] için tekrarlayan hatırlatma kurar.
  /// Metinler kurulum ANINDAKİ dille yazılır; dil değişince Ayarlar yeniden
  /// zamanlar (SettingsController.setLocale).
  Future<void> scheduleDaily({required int hour, int minute = 0}) async {
    await _plugin.cancel(id: _dailyId);
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: t(en: 'Keep your streak!', tr: 'Serini koru!'),
      body: t(
        en: 'Do today\'s lesson and sharpen your ear.',
        tr: 'Bugünkü dersini yap, kulağını geliştir.',
      ),
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // her gün aynı saat
    );
  }

  Future<void> cancelDaily() => _plugin.cancel(id: _dailyId);

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
