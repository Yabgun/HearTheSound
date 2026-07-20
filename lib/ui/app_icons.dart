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

  // Onboarding seviye kartları (🌱 🎵 🎹 🎼).
  static const levelBeginner = Icons.eco_rounded;
  static const levelNotes = Icons.music_note_rounded;
  static const levelChords = Icons.piano_rounded;
  static const levelTheory = Icons.graphic_eq_rounded;
}
