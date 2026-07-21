import 'package:google_sign_in/google_sign_in.dart';

import 'google_config.dart';

// -----------------------------------------------------------------------------
// GOOGLE KİMLİK — yalnızca "ID token al" işi
//
// Supabase'e özgü hiçbir şey bilmez; CloudSync aldığı token'ı Supabase'e sunar.
// Bu ayrım sayesinde veri katmanı (cloud_sync.dart) tek bir sağlayıcıya
// bağlanmaz ve Google'a özgü tuhaflıklar tek dosyada kalır.
// -----------------------------------------------------------------------------

/// Kullanıcı Google penceresini kapattığında fırlatılır.
///
/// Bu bir HATA DEĞİLDİR — arayüz kırmızı uyarı göstermemeli, sessizce
/// seçim ekranına dönmelidir.
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

/// `initialize()` süreç başına bir kez çağrılmalı (google_sign_in v7 kuralı).
bool _initialized = false;

/// Google hesabıyla kimlik doğrular ve Supabase'in beklediği ID token'ı döndürür.
///
/// Fırlatabilir: [GoogleSignInCancelled] (kullanıcı vazgeçti) · [StateError]
/// (yapılandırma/platform eksik) · [GoogleSignInException] (Google tarafı hata).
Future<String> obtainGoogleIdToken() async {
  if (!isGoogleSignInConfigured) {
    throw StateError(
      'Google client ID is empty — fill lib/data/cloud/google_config.dart.',
    );
  }

  final signIn = GoogleSignIn.instance;
  if (!_initialized) {
    // serverClientId = WEB client ID (bkz. google_config.dart'taki açıklama):
    // token'ın "aud" alanı buna eşit olmalı ki Supabase kabul etsin.
    await signIn.initialize(serverClientId: kGoogleWebClientId);
    _initialized = true;
  }

  if (!signIn.supportsAuthenticate()) {
    throw StateError('This platform does not support Google sign-in.');
  }

  final GoogleSignInAccount account;
  try {
    account = await signIn.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw const GoogleSignInCancelled();
    }
    rethrow;
  }

  final idToken = account.authentication.idToken;
  if (idToken == null) {
    // serverClientId yanlış/eksikse Google idToken vermez — en sık kurulum hatası.
    throw StateError(
      'No Google ID token returned. Is the Web client ID correct, and does the '
      'Android client SHA-1 match this build?',
    );
  }
  return idToken;
}

/// Google oturumunu da kapatır (uygulama çıkışıyla birlikte çağrılır ki bir
/// sonraki girişte hesap seçme ekranı gelsin).
Future<void> signOutGoogle() async {
  if (!_initialized) return;
  await GoogleSignIn.instance.signOut();
}
