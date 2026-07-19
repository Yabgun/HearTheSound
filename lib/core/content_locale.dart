// -----------------------------------------------------------------------------
// İÇERİK DİLİ — uygulama genelindeki aktif dil (varsayılan İngilizce).
//
// Neden Flutter'ın Localizations'ı değil de global bir bayrak?
// Ders verileri (başlıklar, kavram kartları, derece adları...) BuildContext'i
// olmayan saf Dart sabitlerinde yaşar. Bu bayrak hem o veriye hem UI metin
// kataloğuna (lib/l10n/strings.dart) tek kaynaktan dil seçtirir. MaterialApp
// yine flutter_localizations delegelerini kullanır (Material bileşen metinleri
// için); bu bayrakla aynı ayar (Ayarlar → Dil) tarafından beslenirler.
//
// Yazarlar: main() (açılışta prefs'ten) ve SettingsController.setLocale().
// -----------------------------------------------------------------------------

abstract final class ContentLocale {
  /// Aktif dil kodu: 'en' (varsayılan) veya 'tr'.
  static String code = 'en';

  static bool get isTr => code == 'tr';

  /// Desteklenen diller (Ayarlar'daki seçici ve MaterialApp bunları kullanır).
  static const List<String> supported = ['en', 'tr'];
}

/// Kısa seçici: aktif dile göre metin döndürür. İçerik kurucularında ve
/// UI kataloğunda okunabilirlik için (`t(en: ..., tr: ...)`).
String t({required String en, required String tr}) =>
    ContentLocale.isTr ? tr : en;
