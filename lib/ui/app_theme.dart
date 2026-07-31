import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// -----------------------------------------------------------------------------
// HEAR THE SOUND TASARIM SİSTEMİ — "Aydınlık stüdyo"
//
// Ferah, enerjik açık tema: hafif mor-beyaz zemin, tek cesur mor→mercan aksan,
// canlı kategori renkleri. Ders ekranları ThemeData'yı kullandığı için bu dil
// uygulama boyunca tutarlı kalır. Renkler TEK KAYNAK burada: ekranlarda sabit
// renk kopyalamak yerine AppColors / colorScheme kullanılır.
// -----------------------------------------------------------------------------

abstract final class AppColors {
  // Zeminler ve nötrler (mora doğru hafif tonlu — "seçilmiş" nötr)
  //
  // ERİŞİLEBİLİRLİK: metin/zemin çiftleri WCAG AA hedefler; oranlar
  // test/contrast_test.dart ile KİLİTLİDİR (renk değişikliği testte görünür).
  static const paper = Color(0xFFF2F2FB); // uygulama zemini
  static const wash = Color(0xFFEAEBF8); // ince dolgu (çubuk arkası, track)
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF20233B); // ana metin
  static const muted = Color(0xFF5C6280); // ikincil metin (AA: ≥4.5 zeminde)
  static const faint = Color(0xFF82879F); // en soluk metin/ikon (≥3.0 zeminde)
  static const line = Color(0xFFE6E6F2); // kenarlık
  static const lineStrong = Color(0xFFD3D5E6);

  // Marka / aksan
  static const grape = Color(0xFF6A4DF4); // birincil (beyaz metinle AA)
  static const grapeSoft = Color(0xFFEAE4FF);
  static const coral = Color(0xFFFF6B5E);
  static const teal = Color(0xFF12C08E);
  static const amber = Color(0xFFFFB020);
  static const amberDeep = Color(0xFF9A6A00); // amber'in METİN hali (AA)
  static const pink = Color(0xFFFF5CA8);
  static const sky = Color(0xFF39B4F0);
  static const gold = Color(0xFFFFC24B); // streak/ateş

  // Anlamsal (aksan hue'sundan ayrı) — hem dolgu (beyaz metinle) hem metin
  // (açık zeminde) olarak AA geçecek koyulukta seçildi.
  static const success = Color(0xFF0A7C55); // doğru / tamam
  static const danger = Color(0xFFC93650); // yanlış / hata

  // Kategori (track) aksanları — ana ekran haritası ve rozetler için
  static const catNotes = grape;
  static const catChords = coral;
  static const catIntervals = teal;
  static const catTonality = amber;
  static const catFunction = sky;

  /// Yeni yetenek track'leri: Melodi Kulağı ve Armoni Kulağı.
  static const catMelody = sky;
  static const catHarmony = pink;
  static const catProgression = pink;
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.grape,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.grapeSoft,
      onPrimaryContainer: Color(0xFF2E1A78),
      secondary: AppColors.teal,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFD6F5EB),
      onSecondaryContainer: Color(0xFF075E45),
      tertiary: AppColors.coral,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFE1DC),
      onTertiaryContainer: Color(0xFF7A2018),
      surface: AppColors.card,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.card,
      surfaceContainerHigh: Color(0xFFF6F6FC),
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
      error: AppColors.danger,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFE0E4),
      onErrorContainer: Color(0xFF7A1030),
    );

    // Karakterli başlık fontu: Sora (geometrik, modern, "şablon" hissini kırar).
    // Tüm ölçeğe uygulanır; başlıklar ağır ve sıkı, gövde ferah.
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).black;
    final sora = GoogleFonts.soraTextTheme(base);
    final textTheme = sora.copyWith(
      headlineSmall: sora.headlineSmall?.copyWith(
        fontSize: 26,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: sora.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleMedium: sora.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: sora.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: sora.bodyMedium?.copyWith(height: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: const BorderSide(color: AppColors.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.grape.withValues(alpha: 0.14),
        height: 72,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.grape
                : AppColors.muted,
          );
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.grape,
        linearTrackColor: AppColors.wash,
        circularTrackColor: AppColors.wash,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
      ),
    );
  }
}
