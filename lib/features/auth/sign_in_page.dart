import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_validation.dart';
import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../data/cloud/google_auth.dart';
import '../../data/cloud/google_config.dart';
import '../../state/progress_controller.dart';

// -----------------------------------------------------------------------------
// GİRİŞ EKRANI — kimliğin tek adresi
//
// Ayarlar'ın içine gömülü küçük bir form yerine kendi ekranı: çok kullanıcılı
// yayında giriş, uygulamanın birinci sınıf bir akışıdır.
//
// ÜÇ yol, tek varış: Google · e-posta+şifre · misafir.
// Hangi yoldan gelinirse gelinsin oturum açılınca [_afterSignIn] çalışır →
// buluttaki ilerleme YERELLE KAYIPSIZ birleşir (mergeProgress). "Misafir olarak
// oynadım, sonra giriş yaptım" senaryosunda hiçbir emek kaybolmaz.
//
// NEDEN "her girişte e-posta kodu" YOK: iki e-posta yolunu (kod + şifre) yan
// yana sunmak hem seçim yorgunluğu yaratıyor hem de aynı adreste iki farklı
// hesap-oluşturma yolu doğurup çakışmaya yol açıyordu. Kod mekanizması duruyor —
// yalnızca kayıt onayı ve şifre sıfırlamada kullanılıyor.
//
// Ekran, akış sayfalarındaki desenle aynı: tek bir [_Step] durumu, iç içe
// Navigator yok — geri tuşu adım adım geri alır.
// -----------------------------------------------------------------------------

/// Ekranın hangi adımda olduğu.
enum _Step {
  /// Yol seçimi (Google · e-posta+şifre · misafir).
  chooser,

  /// E-posta + şifre (giriş veya kayıt).
  password,

  /// Kayıt sonrası e-posta onay kodu (Supabase'te "Confirm email" açıksa).
  confirmSignUp,

  /// Şifremi unuttum: e-posta iste.
  forgotRequest,

  /// Şifremi unuttum: kod + yeni şifre.
  forgotConfirm,
}

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.chooser;
  bool _busy = false;
  String? _error;

  /// Şifre yolunda: kayıt mı, giriş mi?
  bool _creatingAccount = false;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Düğmelerin aktif/pasifliği alanlara BAĞLI (boş alanla istek gitmesin) —
    // her tuşta yeniden çizmemiz gerekiyor.
    for (final c in [_email, _code, _password]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_email, _code, _password]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  String get _emailText => _email.text.trim();

  // --- Ortak yardımcılar ------------------------------------------------------

  /// Bir kimlik işlemini çalıştırır: meşgul bayrağı + tek noktadan hata mesajı.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleSignInCancelled {
      // Kullanıcı vazgeçti — hata değil, sessizce dur.
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sunucu hatalarını kullanıcının anlayacağı dile çevirir.
  /// (Ham Supabase mesajları İngilizce ve teknik — Türkçe kullanıcıya yardımcı olmaz.)
  String _friendlyError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('invalid login credentials')) {
      return t(
        en: 'Wrong email or password.',
        tr: 'E-posta veya şifre hatalı.',
      );
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return t(
        en: 'This email already has an account. Sign in instead.',
        tr: 'Bu e-postayla zaten hesap var. Giriş yapmayı dene.',
      );
    }
    if (raw.contains('token has expired') || raw.contains('expired')) {
      return t(
        en: 'That code expired. Request a new one.',
        tr: 'Kodun süresi doldu. Yeni kod iste.',
      );
    }
    if (raw.contains('invalid') && raw.contains('token')) {
      return t(
        en: 'That code is not correct. Check and try again.',
        tr: 'Kod doğru değil. Kontrol edip tekrar dene.',
      );
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return t(
        en: 'Too many attempts. Wait a minute and try again.',
        tr: 'Çok fazla deneme. Bir dakika bekleyip tekrar dene.',
      );
    }
    return t(
      en: 'Something went wrong. Check your connection and try again.',
      tr: 'Bir şeyler ters gitti. Bağlantını kontrol edip tekrar dene.',
    );
  }

  /// Oturum açıldıktan sonraki ORTAK son adım — hangi yoldan gelinirse gelinsin.
  Future<void> _afterSignIn() async {
    final repo = ref.read(progressRepositoryProvider);
    await CloudSync.instance.pullAndMerge(repo); // kayıpsız birleştirme
    if (!mounted) return;
    ref.read(progressProvider.notifier).reload();
    Navigator.of(context).pop(true);
  }

  void _goTo(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  // --- Eylemler ---------------------------------------------------------------

  Future<void> _google() => _run(() async {
    await CloudSync.instance.signInWithGoogle();
    await _afterSignIn();
  });

  Future<void> _passwordSubmit() => _run(() async {
    if (_creatingAccount) {
      final bool needsConfirmation;
      try {
        needsConfirmation = await CloudSync.instance.signUpWithPassword(
          email: _emailText,
          password: _password.text,
        );
      } on EmailAlreadyRegistered {
        // Kullanıcıyı gelmeyecek bir kodla bekletmek yerine doğrudan GİRİŞ
        // moduna al — zaten yapmak istediği buydu.
        setState(() {
          _creatingAccount = false;
          _error = t(
            en:
                'This email already has an account. Enter your password to '
                'sign in, or use "Forgot password?".',
            tr:
                'Bu e-postayla zaten hesap var. Giriş için şifreni gir ya da '
                '"Şifremi unuttum"u kullan.',
          );
        });
        return;
      }
      if (needsConfirmation) {
        // Supabase'te "Confirm email" açık → koda geç.
        _code.clear();
        _goTo(_Step.confirmSignUp);
        return;
      }
    } else {
      await CloudSync.instance.signInWithPassword(
        email: _emailText,
        password: _password.text,
      );
    }
    await _afterSignIn();
  });

  Future<void> _confirmSignUp() => _run(() async {
    await CloudSync.instance.confirmSignUp(
      email: _emailText,
      code: _code.text.trim(),
    );
    await _afterSignIn();
  });

  Future<void> _sendResetCode() => _run(() async {
    await CloudSync.instance.sendPasswordResetCode(_emailText);
    _code.clear();
    _password.clear();
    _goTo(_Step.forgotConfirm);
  });

  Future<void> _confirmReset() => _run(() async {
    await CloudSync.instance.confirmPasswordReset(
      email: _emailText,
      code: _code.text.trim(),
      newPassword: _password.text,
    );
    await _afterSignIn();
  });

  // --- Çizim ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Sign in', tr: 'Giriş yap')),
        leading: BackButton(
          onPressed: _busy
              ? null
              : () {
                  // Alt adımdaysak önce seçim ekranına dön, sonra ekrandan çık.
                  if (_step == _Step.chooser) {
                    Navigator.of(context).pop(false);
                  } else {
                    _goTo(_Step.chooser);
                  }
                },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _header(context),
            const SizedBox(height: 20),
            ..._stepBody(context),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBox(context, _error!),
            ],
            if (_busy) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, String subtitle) = switch (_step) {
      _Step.chooser => (
        t(en: 'Save your progress', tr: 'İlerlemeni kaydet'),
        t(
          en:
              'Sign in to back up your progress and continue on any device. '
              'Everything you have done so far comes with you.',
          tr:
              'İlerlemeni yedeklemek ve her cihazda devam etmek için giriş yap. '
              'Şimdiye kadar yaptığın her şey seninle gelir.',
        ),
      ),
      _Step.password => (
        _creatingAccount
            ? t(en: 'Create account', tr: 'Hesap oluştur')
            : t(en: 'Sign in with password', tr: 'Şifreyle giriş yap'),
        _creatingAccount
            ? t(
                en: 'Pick a password of at least 8 characters.',
                tr: 'En az 8 karakterli bir şifre seç.',
              )
            : t(
                en: 'Enter the email and password for your account.',
                tr: 'Hesabının e-postasını ve şifresini gir.',
              ),
      ),
      _Step.confirmSignUp => (
        t(en: 'Confirm your email', tr: 'E-postanı doğrula'),
        t(
          en: 'We sent a 6-digit code to your email to finish setting up.',
          tr: 'Kurulumu bitirmek için e-postana 6 haneli bir kod gönderdik.',
        ),
      ),
      _Step.forgotRequest => (
        t(en: 'Reset password', tr: 'Şifreyi sıfırla'),
        t(
          en: 'Enter your email and we will send a reset code.',
          tr: 'E-postanı gir, sana sıfırlama kodu gönderelim.',
        ),
      ),
      _Step.forgotConfirm => (
        t(en: 'Choose a new password', tr: 'Yeni şifre belirle'),
        t(
          en: 'Enter the code from your email and your new password.',
          tr: 'E-postandaki kodu ve yeni şifreni gir.',
        ),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _stepBody(BuildContext context) => switch (_step) {
    _Step.chooser => _chooserBody(context),
    _Step.password => _passwordBody(),
    _Step.confirmSignUp => _confirmSignUpBody(),
    _Step.forgotRequest => _forgotRequestBody(),
    _Step.forgotConfirm => _forgotConfirmBody(),
  };

  // Yol seçimi ----------------------------------------------------------------

  List<Widget> _chooserBody(BuildContext context) {
    final googleReady = isGoogleSignInConfigured;
    return [
      FilledButton.icon(
        // Yapılandırma yoksa düğme görünür ama pasif (bkz. google_config.dart).
        onPressed: (_busy || !googleReady) ? null : _google,
        icon: const Icon(Icons.account_circle_rounded),
        label: Text(t(en: 'Continue with Google', tr: 'Google ile devam et')),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      if (!googleReady) ...[
        const SizedBox(height: 6),
        Text(
          t(
            en: 'Google sign-in is not set up in this build yet.',
            tr: 'Google ile giriş bu derlemede henüz ayarlanmadı.',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () {
                _creatingAccount = false;
                _goTo(_Step.password);
              },
        icon: const Icon(Icons.mail_outline_rounded),
        label: Text(
          t(en: 'Continue with email', tr: 'E-posta ile devam et'),
        ),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 20),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(
            t(en: 'Continue as guest', tr: 'Misafir olarak devam et'),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          t(
            en: 'You can sign in later — your progress stays on this device.',
            tr: 'Sonra da giriş yapabilirsin — ilerlemen bu cihazda kalır.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }

  // E-posta + şifre yolu -------------------------------------------------------

  List<Widget> _passwordBody() => [
    _emailField(),
    const SizedBox(height: 12),
    _passwordField(
      label: t(en: 'Password', tr: 'Şifre'),
      helper: _creatingAccount
          ? t(
              en: 'At least $kMinPasswordLength characters',
              tr: 'En az $kMinPasswordLength karakter',
            )
          : null,
    ),
    const SizedBox(height: 16),
    _primaryButton(
      label: _creatingAccount
          ? t(en: 'Create account', tr: 'Hesap oluştur')
          : t(en: 'Sign in', tr: 'Giriş yap'),
      onPressed: _passwordFormReady ? _passwordSubmit : null,
    ),
    const SizedBox(height: 10),
    Center(
      child: TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _creatingAccount = !_creatingAccount;
                _error = null;
              }),
        child: Text(
          _creatingAccount
              ? t(
                  en: 'I already have an account',
                  tr: 'Zaten hesabım var',
                )
              : t(en: 'Create a new account', tr: 'Yeni hesap oluştur'),
        ),
      ),
    ),
    if (!_creatingAccount)
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => _goTo(_Step.forgotRequest),
          child: Text(t(en: 'Forgot password?', tr: 'Şifremi unuttum')),
        ),
      ),
  ];

  /// Kayıtta şifre kuralı uygulanır; girişte YALNIZCA boş olmaması yeter
  /// (daha kısa şifreyle oluşturulmuş eski hesap kilitlenmesin).
  bool get _passwordFormReady {
    if (!isValidEmail(_emailText)) return false;
    return _creatingAccount
        ? isAcceptableNewPassword(_password.text)
        : _password.text.isNotEmpty;
  }

  // Kayıt onayı ---------------------------------------------------------------

  List<Widget> _confirmSignUpBody() => [
    _codeField(),
    const SizedBox(height: 16),
    _primaryButton(
      label: t(en: 'Confirm and sign in', tr: 'Doğrula ve giriş yap'),
      onPressed: isValidOtpCode(_code.text) ? _confirmSignUp : null,
    ),
  ];

  // Şifre sıfırlama -----------------------------------------------------------

  List<Widget> _forgotRequestBody() => [
    _emailField(),
    const SizedBox(height: 16),
    _primaryButton(
      label: t(en: 'Send reset code', tr: 'Sıfırlama kodu gönder'),
      onPressed: isValidEmail(_emailText) ? _sendResetCode : null,
    ),
  ];

  List<Widget> _forgotConfirmBody() => [
    _codeField(),
    const SizedBox(height: 12),
    _passwordField(
      label: t(en: 'New password', tr: 'Yeni şifre'),
      helper: t(
        en: 'At least $kMinPasswordLength characters',
        tr: 'En az $kMinPasswordLength karakter',
      ),
    ),
    const SizedBox(height: 16),
    _primaryButton(
      label: t(en: 'Save and sign in', tr: 'Kaydet ve giriş yap'),
      onPressed:
          isValidOtpCode(_code.text) && isAcceptableNewPassword(_password.text)
          ? _confirmReset
          : null,
    ),
  ];

  // Ortak parçalar -------------------------------------------------------------

  Widget _emailField({bool enabled = true}) => TextField(
    controller: _email,
    enabled: enabled && !_busy,
    keyboardType: TextInputType.emailAddress,
    autocorrect: false,
    textCapitalization: TextCapitalization.none,
    decoration: InputDecoration(
      labelText: t(en: 'Email', tr: 'E-posta'),
      prefixIcon: const Icon(Icons.alternate_email_rounded),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _codeField() => TextField(
    controller: _code,
    enabled: !_busy,
    keyboardType: TextInputType.number,
    autofocus: true,
    decoration: InputDecoration(
      labelText: t(
        en: '$kOtpCodeLength-digit code',
        tr: '$kOtpCodeLength haneli kod',
      ),
      prefixIcon: const Icon(Icons.pin_rounded),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _passwordField({required String label, String? helper}) => TextField(
    controller: _password,
    enabled: !_busy,
    obscureText: _obscurePassword,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
        ),
        tooltip: _obscurePassword
            ? t(en: 'Show password', tr: 'Şifreyi göster')
            : t(en: 'Hide password', tr: 'Şifreyi gizle'),
      ),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) => FilledButton(
    onPressed: _busy ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    child: Text(label),
  );

  Widget _errorBox(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
