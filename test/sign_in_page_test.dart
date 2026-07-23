import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/data/cloud/google_config.dart';
import 'package:hear_the_sound/features/auth/sign_in_page.dart';

// -----------------------------------------------------------------------------
// GİRİŞ EKRANI — form-öncelikli akış + "eksik istek gönderme" koruması
//
// DİKKAT: Bu testler bilerek hiçbir SUNUCU eylemini tetiklemez (Supabase testte
// başlatılmamıştır). Yalnızca gezinme ve düğmelerin AKTİF/PASİF mantığı sınanır —
// zaten kapatmak istediğimiz hata sınıfı bu: boş alanla giden istekler.
// -----------------------------------------------------------------------------

void main() {
  Future<void> pumpSignIn(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInPage())),
    );
    await tester.pump();
  }

  /// Etiketine göre düğmeyi bulur ve etkin olup olmadığını söyler.
  bool isEnabled(WidgetTester tester, String label) {
    final button = tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first,
    );
    return button.onPressed != null;
  }

  /// Giriş ↔ kayıt geçişi (Text.rich olduğundan key ile).
  Future<void> toggleToSignUp(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('auth_mode_toggle')));
    await tester.pumpAndSettle();
  }

  tearDown(() => ContentLocale.code = 'en');

  testWidgets('açılışta giriş formu görünür (form-öncelikli, chooser yok)', (
    tester,
  ) async {
    await pumpSignIn(tester);

    // E-posta + şifre alanı hemen görünür (2 alan: giriş modu).
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(isEnabled(tester, 'Sign in'), isFalse); // boş form → pasif

    // Eski "chooser" ve OTP kalıntıları geri sızmasın.
    expect(find.text('Continue with email'), findsNothing);
    expect(find.text('Continue with email code'), findsNothing);
  });

  testWidgets('Google düğmesi yapılandırma durumunu doğru yansıtır', (
    tester,
  ) async {
    await pumpSignIn(tester);
    final explanation = find.text(
      'Google sign-in is not set up in this build yet.',
    );
    if (isGoogleSignInConfigured) {
      expect(isEnabled(tester, 'Continue with Google'), isTrue);
      expect(explanation, findsNothing);
    } else {
      expect(isEnabled(tester, 'Continue with Google'), isFalse);
      expect(explanation, findsOneWidget);
    }
  });

  testWidgets('geçersiz e-postayla giriş denenemez', (tester) async {
    await pumpSignIn(tester);
    final email = find.byType(TextField).first;
    final password = find.byType(TextField).last;
    await tester.enterText(password, 'birsifre');

    // Yarım adres — pasif.
    await tester.enterText(email, 'yarim@');
    await tester.pump();
    expect(isEnabled(tester, 'Sign in'), isFalse);

    // Geçerli adres — aktifleşir (basmıyoruz: sunucuya gitmesin).
    await tester.enterText(email, 'kisi@ornek.com');
    await tester.pump();
    expect(isEnabled(tester, 'Sign in'), isTrue);
  });

  testWidgets('kayıtta 8 karakter + şifre tekrarı şartı, girişte yok', (
    tester,
  ) async {
    await pumpSignIn(tester);
    final email = find.byType(TextField).first;

    // GİRİŞ: kısa şifre kabul (eski hesaplar kilitlenmesin).
    await tester.enterText(email, 'kisi@ornek.com');
    await tester.enterText(find.byType(TextField).last, 'kisa');
    await tester.pump();
    expect(isEnabled(tester, 'Sign in'), isTrue);
    expect(find.byType(TextField), findsNWidgets(2)); // tekrar alanı yok

    // KAYIT moduna geç: 3 alan + kısa şifre reddedilir.
    await toggleToSignUp(tester);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(isEnabled(tester, 'Create account'), isFalse);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'kisi@ornek.com');
    await tester.enterText(fields.at(1), 'yeterince-uzun');
    await tester.enterText(fields.at(2), 'yeterince-uzun');
    await tester.pump();
    expect(isEnabled(tester, 'Create account'), isTrue);
  });

  testWidgets('kayıtta şifre tekrarı eşleşmezse hesap açılamaz', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await toggleToSignUp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'kisi@ornek.com');
    await tester.enterText(fields.at(1), 'dogru-sifre');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);
    expect(isEnabled(tester, 'Create account'), isFalse);

    // Yazım hatası: uyarı + düğme kapalı.
    await tester.enterText(fields.at(2), 'dogru-sifr');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(isEnabled(tester, 'Create account'), isFalse);

    // Düzeltilince açılır.
    await tester.enterText(fields.at(2), 'dogru-sifre');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);
    expect(isEnabled(tester, 'Create account'), isTrue);
  });

  testWidgets('şifremi unuttum → alt adım → geri giriş formuna döner', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // Sıfırlama adımı: giriş formu öğeleri kayboldu.
    expect(find.text('Continue as guest'), findsNothing);
    expect(find.text('Send reset code'), findsOneWidget);

    // Geri tuşu giriş formuna döndürür (ekranı kapatmaz).
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('Türkçe dilde tüm metinler çevrilir', (tester) async {
    ContentLocale.code = 'tr';
    await pumpSignIn(tester);

    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget); // birincil düğme
  });
}
