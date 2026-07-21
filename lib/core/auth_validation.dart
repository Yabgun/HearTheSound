// -----------------------------------------------------------------------------
// KİMLİK DOĞRULAMA GİRDİ KONTROLLERİ (saf, testli)
//
// Amaç sunucuyu taklit etmek DEĞİL — kullanıcıya ANINDA geri bildirim vermek ve
// baştan geçersiz istekleri hiç göndermemek. Son söz her zaman sunucudadır.
//
// Bu kontroller aynı zamanda bir hata sınıfını kapatır: boş/eksik alanla
// gönderilen istekler (loglarda görülen `400: Verify requires either a token`).
// -----------------------------------------------------------------------------

/// Yeni şifreler için en az uzunluk.
///
/// Supabase varsayılanı 6; biz bilerek daha korumacıyız. Kural yalnızca şifre
/// BELİRLERKEN (kayıt / sıfırlama) uygulanır — girişte uygulanmaz, yoksa daha
/// kısa şifreyle oluşturulmuş eski bir hesap kilitlenirdi.
const int kMinPasswordLength = 8;

/// E-posta kodlarının hane sayısı (Supabase OTP).
const int kOtpCodeLength = 6;

/// Kabaca geçerli bir e-posta mı? (boşluksuz `a@b.c` biçimi)
///
/// Kasıtlı olarak gevşek: aşırı katı bir regex gerçek adresleri reddeder.
bool isValidEmail(String value) {
  final email = value.trim();
  if (email.isEmpty || email.length > 254) return false;
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}

/// Yeni şifre olarak kabul edilebilir mi? (yalnızca kayıt/sıfırlamada)
bool isAcceptableNewPassword(String value) => value.length >= kMinPasswordLength;

/// Tam olarak [kOtpCodeLength] haneli rakam mı?
bool isValidOtpCode(String value) {
  final code = value.trim();
  return code.length == kOtpCodeLength &&
      RegExp(r'^\d+$').hasMatch(code);
}
