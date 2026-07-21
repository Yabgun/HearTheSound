// -----------------------------------------------------------------------------
// GOOGLE SIGN-IN YAPILANDIRMASI
//
// "Google ile devam" düğmesi yalnızca aşağıdaki değer DOLUYKEN çalışır; boşken
// düğme görünür ama pasiftir (supabase_config.dart ile aynı desen — eksik
// yapılandırma uygulamayı çökertmez, özelliği kapatır).
//
// Kurulum (Google Cloud Console → APIs & Services → Credentials):
//   1) OAuth client ID · type = **Web application**  → buradaki ID aşağıya
//   2) OAuth client ID · type = **Android** (package name + SHA-1) → koda GİRİLMEZ,
//      Google tarafında imzayı eşleştirir
//   3) Supabase → Authentication → Providers → Google: Web client ID + secret
//
// NEDEN WEB CLIENT ID: Android'de oturum açılsa bile Supabase'e sunulan ID
// token'ın 'aud' (audience) alanı WEB client ID'sine eşit olmalıdır — Supabase
// kendi kaydettiği değerle bunu karşılaştırır. Android client ID'yi buraya
// yazmak "audience mismatch" hatası verir.
// -----------------------------------------------------------------------------

/// Google Cloud Console'daki **Web application** OAuth client ID'si.
/// Proje: `hearthesound` · client adı: "HearTheSound Web".
const String kGoogleWebClientId =
    '757029080067-lquf41ftpq1gfp320n0bgqlevd1ad98h.apps.googleusercontent.com';

/// Google ile giriş kullanılabilir mi?
bool get isGoogleSignInConfigured => kGoogleWebClientId.isNotEmpty;
