import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/cloud/cloud_sync.dart';
import '../data/cloud/supabase_config.dart';
import 'notification_service.dart';

// -----------------------------------------------------------------------------
// PUSH SERVICE — sunucu bildirimleri (FCM) — §21
//
// Sorumluluğu SADECE: Firebase'i başlat, izin al, cihaz token'ını ÜRET ve
// CloudSync'e ver. Token'ı buluta yazma/silme işini CloudSync yapar (giriş/çıkış
// oradan yönetiliyor) — bu ayrım sayesinde push katmanı Supabase'i bilmez.
//
// FAIL-SAFE: Firebase/izin/ağ hataları yutulur — bildirim, uygulama akışını
// asla bozmaz. Bulut kapalıysa (supabase_config boş) hiç devreye girmez.
//
// NOT: iOS eklenmediğinden Firebase.initializeApp() parametresizdir; Android'de
// google-services.json'dan yapılandırmayı native katman sağlar.
// -----------------------------------------------------------------------------

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;

  /// Uygulama açılışında bir kez çağrılır (main). Açılışı BEKLETMEZ; hata olursa
  /// sessizce yerel akış sürer.
  Future<void> init() async {
    if (_started || !isCloudConfigured) return;
    _started = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      // Bildirim izni (Android 13+ zaten sistem izni istiyor; FCM'e de sorar).
      await messaging.requestPermission();

      // Token'ı al → CloudSync'e ver → (oturum varsa) buluta yaz.
      final token = await messaging.getToken();
      CloudSync.instance.setDeviceToken(token);
      unawaited(CloudSync.instance.registerDeviceToken());

      // Token yenilenince güncelle (Google zaman zaman döndürür).
      messaging.onTokenRefresh.listen((t) {
        CloudSync.instance.setDeviceToken(t);
        unawaited(CloudSync.instance.registerDeviceToken());
      });

      // Uygulama ÖN PLANDAYKEN gelen mesajı elle göster (Android aksi halde
      // ön planda göstermez). Arka plan/kapalı durumda sistem kendi gösterir.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        unawaited(
          NotificationService.instance.showRemote(
            id: message.hashCode,
            title: n.title,
            body: n.body,
          ),
        );
      });
    } catch (_) {
      // Firebase yok / izin reddedildi / ağ yok — sessizce geç.
    }
  }
}
