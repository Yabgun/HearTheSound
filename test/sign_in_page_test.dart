import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
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

  testWidgets('seçim ekranı dört yolu da sunar', (tester) async {
    await pumpSignIn(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email code'), findsOneWidget);
    expect(find.text('Email and password'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('Google yapılandırılmamışsa düğme pasif ve açıklanır', (
    tester,
  ) async {
    await pumpSignIn(tester);

    // google_config.dart boş olduğu sürece: görünür ama basılamaz + gerekçe yazar.
    expect(isEnabled(tester, 'Continue with Google'), isFalse);
    expect(
      find.text('Google sign-in is not set up in this build yet.'),
      findsOneWidget,
    );
  });

  testWidgets('e-posta kodu yolu: geçersiz e-postayla kod istenemez', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('Continue with email code'));
    await tester.pumpAndSettle();

    // Boşken pasif.
    expect(isEnabled(tester, 'Send code'), isFalse);

    // Yarım adres — hâlâ pasif.
    await tester.enterText(find.byType(TextField).first, 'yarim@');
    await tester.pump();
    expect(isEnabled(tester, 'Send code'), isFalse);

    // Geçerli adres — aktifleşir (basmıyoruz: sunucuya gitmesin).
    await tester.enterText(find.byType(TextField).first, 'kisi@ornek.com');
    await tester.pump();
    expect(isEnabled(tester, 'Send code'), isTrue);
  });

  testWidgets('şifre yolu: kayıtta 8 karakter şartı, girişte değil', (
    tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('Email and password'));
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
    await tester.tap(find.text('Email and password'));
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
    expect(find.text('E-posta kodu ile devam et'), findsOneWidget);
    expect(find.text('E-posta ve şifre'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
  });
}
