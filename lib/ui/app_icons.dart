import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// APP ICONS — emoji yerine tutarlı ikon seti (tek kaynak)
//
// Emojiler uygulamanın tasarım diline uymuyordu; onların yerine Material "Rounded"
// ikonlar kullanıyoruz (uygulamanın yuvarlak diline uyar, ek paket gerekmez).
// Tüm ekranlar ikonları BURADAN çeker → ileride ikon dilini değiştirmek tek
// dosyalık iş olur. (Eko maskotu emoji değil, kendi çizimimiz → yerinde kalır.)
// -----------------------------------------------------------------------------

abstract final class AppIcons {
  /// Günlük seri (🔥).
  static const streak = Icons.local_fire_department_rounded;

  /// Ustalık/taç rozeti (👑).
  static const crown = Icons.workspace_premium_rounded;

  /// Söyleme: "tam — böyle tut" hedefte (🎯).
  static const onTarget = Icons.adjust_rounded;

  /// Kalibrasyon: rahat (😌) / zorlandım (😬).
  static const comfortable = Icons.sentiment_satisfied_rounded;
  static const strained = Icons.sentiment_dissatisfied_rounded;

  /// Kutlama (🎉).
  static const celebrate = Icons.celebration_rounded;

  /// Müzikal cümle evine döndü — "bitti, tamamlandı".
  /// Ev ikonu bilinçli: metafor ("ev") ile simge birebir örtüşsün, kullanıcı
  /// cevabı okumadan da anlasın.
  static const phraseHome = Icons.home_rounded;

  /// Müzikal cümle askıda kaldı — "devamı bekleniyor".
  /// Üç nokta evrensel olarak "sürüyor" demektir.
  static const phraseHanging = Icons.more_horiz_rounded;

  /// Dersin kazanımı ("bu dersten sonra şunu yapabileceksin").
  static const promise = Icons.emoji_events_rounded;

  // Onboarding başlangıç noktası kartları: "müziğe yeniyim" · "biraz biliyorum".
  // (Eskiden dört seviye kartı vardı; kullanıcıya kendini etiketletmek yerine
  // gerçek derslerle sınayan merdiven testine geçildi → iki ikon yetiyor.)
  static const levelBeginner = Icons.eco_rounded;
  static const levelChords = Icons.piano_rounded;
}
