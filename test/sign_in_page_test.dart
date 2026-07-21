import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/data/cloud/google_config.dart';
import 'package:hear_the_sound/features/auth/sign_in_page.dart';

// -----------------------------------------------------------------------------
// GİRİŞ EKRANI — akış ve "eksik istek gönderme" koruması
//
// DİKKAT: Bu testler bilerek hiçbir SUNUCU eylemini tetiklemez (Supabase testte
// başlatılmamıştır). Yalnızca gezinme ve düğmelerin AKTİF/PASİF mantığı sınanır —
// zaten kapatmak istediğimiz hata sınıfı bu: boş alanla giden istekler
// (loglarda görülen `400: Verify requires either a token`).
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
  ///
  /// `find.byType` TAM tip eşleştirir (FilledButton/OutlinedButton ≠ soyut
  /// ButtonStyleButton) → alt sınıfları yakalamak için predicate şart.
  /// `.first`: aynı metin başlıkta da geçebilir (ör. "Sign in" hem AppBar
  /// başlığı hem düğme); düğme olmayan eşleşmeler zaten elenir.
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

  tearDown(() => ContentLocale.code = 'en');

  testWidgets('seçim ekranı ÜÇ yolu sunar — fazlası değil', (tester) async {
    await pumpSignIn(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);

    // "Her girişte kod" yolu bilerek kaldırıldı (seçim yorgunluğu + aynı
    // adreste iki hesap-oluşturma yolu çakışması). Geri sızmasın.
    expect(find.text('Continue with email code'), findsNothing);
    expect(find.text('Send code'), findsNothing);
  });

  testWidgets('Google düğmesi yapılandırma durumunu doğru yansıtır', (
    tester,
  ) async {
    await pumpSignIn(tester);

    // Sözleşme iki yönlü: client ID varsa basılabilir; YOKSA görünür ama pasif
    // ve gerekçesi yazılı kalır (sessizce çalışmayan düğme bırakmayız).
    // Duruma göre iddia ediyoruz ki `google_config.dart` doldurulunca da
    // boşaltılınca da test anlamını korusun.
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
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

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

  testWidgets('şifre yolu: kayıtta 8 karakter şartı, girişte değil', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    final email = find.byType(TextField).first;
    final password = find.byType(TextField).last;

    // GİRİŞ: kısa şifre kabul edilir (eski hesaplar kilitlenmesin).
    await tester.enterText(email, 'kisi@ornek.com');
    await tester.enterText(password, 'kisa');
    await tester.pump();
    expect(isEnabled(tester, 'Sign in'), isTrue);

    // KAYIT: aynı kısa şifre reddedilir.
    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Create account'), isFalse);

    await tester.enterText(find.byType(TextField).last, 'yeterince-uzun');
    await tester.pump();
    expect(isEnabled(tester, 'Create account'), isTrue);
  });

  testWidgets('geri tuşu önce seçim ekranına döner, ekranı kapatmaz', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Continue as guest'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Seçim ekranına döndük — ekran hâlâ açık.
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('Türkçe dilde tüm metinler çevrilir', (tester) async {
    ContentLocale.code = 'tr';
    await pumpSignIn(tester);

    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('E-posta ile devam et'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
  });
}
