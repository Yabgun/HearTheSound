import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// -----------------------------------------------------------------------------
// HEAR THE SOUND TASARIM SİSTEMİ — açık ve koyu tema
//
// RENKLER İKİ KOVAYA AYRILIR. Ayrımın tek ölçütü şu soru:
// "bu rengin DOĞRU değeri, arkasındaki zeminin açık mı koyu mu olduğuna bağlı mı?"
//
//  1. [AppColors] — MARKA HUE'LARI. Cevap HAYIR. Mercan mercandır; hem açık hem
//     koyu zeminde aynı kalır ve tanınır. const kalabildikleri için widget
//     ağacındaki const kırılmaz ve BAĞLAMI OLMAYAN veri (müfredat track
//     renkleri, Eko paletleri) de bunları kullanabilir.
//
//  2. [AppPalette] — EKRAN PALETİ. Cevap EVET: metin, zemin, çizgi, geri
//     bildirim renkleri. Bunlar bir ThemeExtension içinde yaşar ve temayla
//     KENDİLİĞİNDEN döner. Ekranlar context.colors.ink diye okur.
//
// NEDEN ThemeExtension: eskiden ekranlar AppColors.ink gibi SABİTLERİ doğrudan
// kullanıyordu; bu sabitler temayla dönmediği için koyu temada açık tema
// renkleri ekranda kalırdı. Global bir "aktif palet" değişkeni de çözmezdi:
// const widget'lar yeniden çizilmediği için renkleri bayat kalırdı. Tema
// uzantısı, Flutter'ın kendi mekanizması olduğu için bu iki tuzağı da kapatır.
//
// ERİŞİLEBİLİRLİK: metin/zemin çiftleri WCAG AA hedefler; oranlar
// test/contrast_test.dart ile İKİ PALET İÇİN DE kilitlidir.
// -----------------------------------------------------------------------------

/// Marka hue'ları — temadan bağımsız, const kullanılabilir ham renkler.
///
/// Buraya YALNIZCA zeminden bağımsız renkler girer. Bir renk koyu temada başka
/// bir değer istiyorsa yeri burası değil, [AppPalette]'tir.
abstract final class AppColors {
  // Aksan hue'ları (dolgu, tint, vurgu). Açık zeminde METİN olarak
  // kullanılmazlar — metin gerektiğinde paletin karşılığı vardır
  // (ör. amber yerine context.colors.amberDeep).
  static const coral = Color(0xFFFF6B5E);
  static const teal = Color(0xFF12C08E);
  static const amber = Color(0xFFFFB020);
  static const pink = Color(0xFFFF5CA8);
  static const sky = Color(0xFF39B4F0);
  static const gold = Color(0xFFFFC24B); // streak/ateş

  /// Markanın mor kimliği. Ekranlarda `context.colors.grape` tercih edilir
  /// (koyu temada okunur bir tona döner); bu sabit yalnızca tema tanımları ve
  /// bağlamsız veri içindir.
  static const grapeHue = Color(0xFF6A4DF4);

  // Kategori (track) aksanları — yol haritası ve rozetler için.
  // Bunlar VERİ: müfredat (features/home/curriculum.dart) bağlamı olmadan
  // kurulduğu için sabit olmak zorundalar. Dolgu/tint olarak kullanıldıklarından
  // her iki zeminde de çalışırlar.
  static const catNotes = grapeHue;
  static const catChords = coral;
  static const catIntervals = teal;
  static const catTonality = amber;
  static const catFunction = sky;
  static const catMelody = sky;
  static const catHarmony = pink;
  static const catProgression = pink;
}

/// Zemine bağlı renkler — temayla döner. `context.colors` ile okunur.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // Zeminler ve nötrler
  final Color paper; // uygulama zemini
  final Color wash; // ince dolgu (çubuk arkası, ray)
  final Color card; // yüzey
  final Color ink; // ana metin
  final Color muted; // ikincil metin (AA: ≥4.5)
  final Color faint; // en soluk metin/ikon (≥3.0)
  final Color line; // kenarlık
  final Color lineStrong;

  // Marka moru — koyu temada okunabilir tona çıkar.
  final Color grape;
  final Color grapeSoft; // mor tint zemini

  /// Amber'in METİN hâli: açık temada koyu kehribar, koyu temada açık kehribar.
  /// Amber'in kendisi (dolgu) [AppColors.amber] olarak sabit kalır.
  final Color amberDeep;

  // Geri bildirim. Her biri ÇİFT gelir: renk + üstüne yazılacak metin rengi.
  // Tek renkle idare edilemez — açık temada KOYU yeşil dolgunun üstüne beyaz
  // yazılır, koyu temada ise AÇIK yeşil dolgunun üstüne koyu yazılmalıdır.
  final Color success;
  final Color onSuccess;
  final Color danger;
  final Color onDanger;

  const AppPalette({
    required this.paper,
    required this.wash,
    required this.card,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineStrong,
    required this.grape,
    required this.grapeSoft,
    required this.amberDeep,
    required this.success,
    required this.onSuccess,
    required this.danger,
    required this.onDanger,
  });

  /// "Aydınlık stüdyo" — ferah, mora doğru tonlu nötrler.
  static const light = AppPalette(
    paper: Color(0xFFF2F2FB),
    wash: Color(0xFFEAEBF8),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF20233B),
    muted: Color(0xFF5C6280),
    faint: Color(0xFF82879F),
    line: Color(0xFFE6E6F2),
    lineStrong: Color(0xFFD3D5E6),
    grape: Color(0xFF6A4DF4),
    grapeSoft: Color(0xFFEAE4FF),
    amberDeep: Color(0xFF8E6100),
    success: Color(0xFF0A7C55),
    onSuccess: Color(0xFFFFFFFF),
    danger: Color(0xFFC93650),
    onDanger: Color(0xFFFFFFFF),
  );

  /// "Gece stüdyosu" — aynı mor tonlaması, ters çevrilmiş parlaklık.
  /// Zemin saf siyah DEĞİL: OLED siyahı üzerinde beyaz metin gece gözü yorar ve
  /// kart ile zemin ayrımı kaybolur.
  static const dark = AppPalette(
    paper: Color(0xFF12131F),
    wash: Color(0xFF262940),
    card: Color(0xFF1C1E2E),
    ink: Color(0xFFE9EAF4),
    muted: Color(0xFFA5ABC6),
    faint: Color(0xFF7E85A2),
    line: Color(0xFF2A2D42),
    lineStrong: Color(0xFF3A3E58),
    grape: Color(0xFFA48FFF),
    grapeSoft: Color(0xFF2E2B55),
    amberDeep: Color(0xFFFFC24B),
    success: Color(0xFF35C99A),
    onSuccess: Color(0xFF04241A),
    danger: Color(0xFFFF8095),
    onDanger: Color(0xFF33000C),
  );

  @override
  AppPalette copyWith({
    Color? paper,
    Color? wash,
    Color? card,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? lineStrong,
    Color? grape,
    Color? grapeSoft,
    Color? amberDeep,
    Color? success,
    Color? onSuccess,
    Color? danger,
    Color? onDanger,
  }) {
    return AppPalette(
      paper: paper ?? this.paper,
      wash: wash ?? this.wash,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      grape: grape ?? this.grape,
      grapeSoft: grapeSoft ?? this.grapeSoft,
      amberDeep: amberDeep ?? this.amberDeep,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double v) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, v)!;
    return AppPalette(
      paper: c(paper, other.paper),
      wash: c(wash, other.wash),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      grape: c(grape, other.grape),
      grapeSoft: c(grapeSoft, other.grapeSoft),
      amberDeep: c(amberDeep, other.amberDeep),
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
    );
  }
}

/// Ekranların paleti okuma yolu: `context.colors.ink`.
///
/// Uzantı bulunamazsa açık palete düşer — bir ekran tema kurulmadan (testte,
/// çıplak bir MaterialApp içinde) çizilse bile renksiz kalmaz.
extension AppPaletteContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  /// Testler için AYNI temayı web yazı tipi olmadan kurar.
  ///
  /// GoogleFonts, tema kurulurken fontu ağdan çekmeye çalışır ve test
  /// ortamında bu istek başarısız olup ASENKRON bir hata fırlatır — testi
  /// bittikten sonra kırar. Renk sınayan bir testin yazı tipi indirmesine
  /// ihtiyacı yok; bu kapı o gürültüyü kesip aynı kurulum yolunu (uzantı,
  /// şema, bileşen biçimleri) sınamayı sürdürür.
  @visibleForTesting
  static ThemeData forTest(Brightness brightness, AppPalette palette) =>
      _build(brightness, palette, webFont: false);

  /// İki tema TEK gövdeden üretilir: bileşen biçimleri (köşe yarıçapı, düğme
  /// yükseklikleri, tipografi) ortak, yalnızca palet değişir. Ayrı ayrı
  /// yazılsalardı biri güncellenip diğeri unutulurdu.
  static ThemeData _build(
    Brightness brightness,
    AppPalette p, {
    bool webFont = true,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.grape,
      onPrimary: isDark ? const Color(0xFF1A0B4D) : const Color(0xFFFFFFFF),
      primaryContainer: p.grapeSoft,
      onPrimaryContainer: isDark
          ? const Color(0xFFDCD4FF)
          : const Color(0xFF2E1A78),
      secondary: isDark ? const Color(0xFF3FD9AC) : AppColors.teal,
      onSecondary: isDark ? const Color(0xFF00281C) : const Color(0xFFFFFFFF),
      secondaryContainer: isDark
          ? const Color(0xFF10493A)
          : const Color(0xFFD6F5EB),
      onSecondaryContainer: isDark
          ? const Color(0xFFB6F2DF)
          : const Color(0xFF075E45),
      tertiary: isDark ? const Color(0xFFFF8F84) : AppColors.coral,
      onTertiary: isDark ? const Color(0xFF4A0F0A) : const Color(0xFFFFFFFF),
      tertiaryContainer: isDark
          ? const Color(0xFF5C231D)
          : const Color(0xFFFFE1DC),
      onTertiaryContainer: isDark
          ? const Color(0xFFFFD9D4)
          : const Color(0xFF7A2018),
      surface: p.card,
      onSurface: p.ink,
      // Şık düğmelerinin zemini: koyu temada yüzeyden BİR TIK açık olmalı,
      // yoksa kart ile düğme aynı renge düşer ve dokunulacak yer görünmez.
      surfaceContainerHighest: isDark ? p.wash : p.card,
      surfaceContainerHigh: isDark
          ? const Color(0xFF22243A)
          : const Color(0xFFF6F6FC),
      onSurfaceVariant: p.muted,
      outline: p.lineStrong,
      outlineVariant: p.line,
      error: p.danger,
      onError: p.onDanger,
      errorContainer: isDark
          ? const Color(0xFF5C1225)
          : const Color(0xFFFFE0E4),
      onErrorContainer: isDark
          ? const Color(0xFFFFD9DE)
          : const Color(0xFF7A1030),
    );

    // Karakterli başlık fontu: Sora (geometrik, modern, "şablon" hissini kırar).
    // Tüm ölçeğe uygulanır; başlıklar ağır ve sıkı, gövde ferah.
    final base = Typography.material2021(platform: TargetPlatform.android);
    final plain = isDark ? base.white : base.black;
    final sora = webFont ? GoogleFonts.soraTextTheme(plain) : plain;
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
      brightness: brightness,
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(color: p.line),
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
          side: BorderSide(color: p.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        indicatorColor: p.grape.withValues(alpha: 0.14),
        height: 72,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? p.grape : p.muted,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.grape,
        linearTrackColor: p.wash,
        circularTrackColor: p.wash,
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
