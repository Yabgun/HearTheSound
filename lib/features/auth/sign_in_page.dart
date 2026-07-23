import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_validation.dart';
import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../data/cloud/google_auth.dart';
import '../../data/cloud/google_config.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../mascot/eko_mascot.dart';

// -----------------------------------------------------------------------------
// GİRİŞ EKRANI — kimliğin tek adresi
//
// FORM-ÖNCELİKLİ: ekran doğrudan giriş formuyla açılır (e-posta + şifre), Google
// düğmesi hemen altında, "hesabın yok mu → Kaydol" ve "Misafir devam" en altta.
// İçerik dikey ORTALANMIŞTIR (Center + kaydırılabilir) — cezbedici bir karşılama.
//
// Yollar: Google · e-posta+şifre · misafir. Hepsi aynı yere varır: oturum
// açılınca [_afterSignIn] → buluttaki ilerleme YERELLE KAYIPSIZ birleşir.
//
// Kod mekanizması yalnızca kayıt onayı (confirmSignUp) ve şifre sıfırlamada
// kullanılır. Ekran tek bir [_Step] durumu tutar — iç içe Navigator yok.
// -----------------------------------------------------------------------------

/// Ekranın hangi adımda olduğu. İlk (ve ana) adım [signIn]: giriş/kayıt formu.
enum _Step {
  /// E-posta + şifre formu (giriş veya kayıt — `_creatingAccount` ayırır) +
  /// Google + misafir. Ekranın açılış adımı.
  signIn,

  /// Kayıt sonrası e-posta onay kodu (Supabase'te "Confirm email" açıksa).
  confirmSignUp,

  /// Şifremi unuttum: e-posta iste.
  forgotRequest,

  /// Şifremi unuttum: kod + yeni şifre.
  forgotConfirm,
}

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.onCompleted});

  /// Onboarding modu: verilirse giriş VEYA misafir sonrası `Navigator.pop`
  /// yerine bu çağrılır (akış bir sonraki adıma geçer). null = bağımsız ekran
  /// (Ayarlar'dan açılmış) → eski pop davranışı. Onboarding modunda ayrıca ilk
  /// adımda geri düğmesi gizlenir ve üstte dil seçici gösterilir.
  final VoidCallback? onCompleted;

  bool get _embedded => onCompleted != null;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  /// Şifre BELİRLERKEN (kayıt / sıfırlama) ikinci giriş — yazım hatasıyla
  /// erişilemez hesap açılmasını önler. Girişte kullanılmaz.
  final _passwordConfirm = TextEditingController();

  _Step _step = _Step.signIn;
  bool _busy = false;
  String? _error;

  /// signIn adımında: kayıt mı (true), giriş mi (false)?
  bool _creatingAccount = false;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Düğmelerin aktif/pasifliği alanlara BAĞLI (boş alanla istek gitmesin) —
    // her tuşta yeniden çizmemiz gerekiyor.
    for (final c in [_email, _code, _password, _passwordConfirm]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _passwordConfirm]) {
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
      return t(en: 'Wrong email or password.', tr: 'E-posta veya şifre hatalı.');
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
    _leave(true);
  }

  /// Ekrandan ayrıl: onboarding modunda akışı ilerletir, bağımsızsa geri döner.
  void _leave(bool signedIn) {
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).pop(signedIn);
    }
  }

  /// Onboarding modunda üstte gösterilen kompakt dil seçici (EN/TR). İngilizce
  /// bilmeyen kullanıcı giriş ekranını da Türkçe görebilsin.
  Widget _langToggle() {
    final code = ref.watch(settingsProvider).localeCode;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'en', label: Text('EN')),
        ButtonSegment(value: 'tr', label: Text('TR')),
      ],
      selected: {code},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(settingsProvider.notifier).setLocale(s.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _goTo(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  /// Alt adımdan (onay/sıfırlama) giriş formuna dön.
  void _backToSignIn() => setState(() {
    _step = _Step.signIn;
    _creatingAccount = false;
    _error = null;
    _passwordConfirm.clear();
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
    _passwordConfirm.clear();
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
    // Ana adımda (signIn) geri düğmesi: onboarding modunda gizli (misafir zaten
    // var), bağımsızda ekranı kapatır. Alt adımlarda giriş formuna döner.
    final onSignIn = _step == _Step.signIn;
    final hideBack = widget._embedded && onSignIn;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: hideBack
            ? null
            : BackButton(
                onPressed: _busy
                    ? null
                    : () => onSignIn ? _leave(false) : _backToSignIn(),
              ),
        actions: widget._embedded
            ? [_langToggle(), const SizedBox(width: 12)]
            : null,
      ),
      // ORTALANMIŞ + kaydırılabilir: kısa ekranda/klavye açıkken taşmaz.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 24),
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
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, String subtitle) = switch (_step) {
      _Step.signIn => _creatingAccount
          ? (
              t(en: 'Create your account', tr: 'Hesabını oluştur'),
              t(
                en: 'Pick a password of at least 8 characters.',
                tr: 'En az 8 karakterli bir şifre seç.',
              ),
            )
          : (
              t(en: 'Welcome back', tr: 'Tekrar hoş geldin'),
              t(
                en: 'Sign in to sync your progress across devices.',
                tr: 'İlerlemeni cihazlar arası eşitlemek için giriş yap.',
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
      children: [
        const EkoMascot(size: 76),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Widget> _stepBody(BuildContext context) => switch (_step) {
    _Step.signIn => _signInBody(context),
    _Step.confirmSignUp => _confirmSignUpBody(),
    _Step.forgotRequest => _forgotRequestBody(),
    _Step.forgotConfirm => _forgotConfirmBody(),
  };

  // Giriş / kayıt formu (ana adım) --------------------------------------------

  List<Widget> _signInBody(BuildContext context) {
    final theme = Theme.of(context);
    return [
      _emailField(),
      const SizedBox(height: 12),
      _passwordField(
        controller: _password,
        label: t(en: 'Password', tr: 'Şifre'),
        helper: _creatingAccount
            ? t(
                en: 'At least $kMinPasswordLength characters',
                tr: 'En az $kMinPasswordLength karakter',
              )
            : null,
      ),
      // Yalnızca KAYITTA: şifreyi ikinci kez iste (yazım hatası koruması).
      if (_creatingAccount) ...[
        const SizedBox(height: 12),
        _passwordField(
          controller: _passwordConfirm,
          label: t(en: 'Re-enter password', tr: 'Şifreyi tekrar gir'),
          errorText: _confirmError,
        ),
      ],
      // Şifremi unuttum yalnızca GİRİŞTE, sağa hizalı.
      if (!_creatingAccount)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _goTo(_Step.forgotRequest),
            child: Text(t(en: 'Forgot password?', tr: 'Şifremi unuttum')),
          ),
        )
      else
        const SizedBox(height: 16),
      _primaryButton(
        label: _creatingAccount
            ? t(en: 'Create account', tr: 'Hesap oluştur')
            : t(en: 'Sign in', tr: 'Giriş yap'),
        onPressed: _passwordFormReady ? _passwordSubmit : null,
      ),
      const SizedBox(height: 18),
      _orDivider(theme),
      const SizedBox(height: 18),
      // Google — yapılandırma yoksa görünür ama pasif (bkz. google_config.dart).
      OutlinedButton.icon(
        onPressed: (_busy || !isGoogleSignInConfigured) ? null : _google,
        icon: const Icon(Icons.account_circle_rounded),
        label: Text(t(en: 'Continue with Google', tr: 'Google ile devam et')),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      if (!isGoogleSignInConfigured) ...[
        const SizedBox(height: 6),
        Text(
          t(
            en: 'Google sign-in is not set up in this build yet.',
            tr: 'Google ile giriş bu derlemede henüz ayarlanmadı.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 20),
      // Giriş ↔ kayıt geçişi.
      Center(
        child: TextButton(
          key: const Key('auth_mode_toggle'),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _creatingAccount = !_creatingAccount;
                  _error = null;
                  _passwordConfirm.clear();
                }),
          child: Text.rich(
            TextSpan(
              text: _creatingAccount
                  ? t(en: 'Already have an account? ', tr: 'Zaten hesabın var mı? ')
                  : t(en: "Don't have an account? ", tr: 'Hesabın yok mu? '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: _creatingAccount
                      ? t(en: 'Sign in', tr: 'Giriş yap')
                      : t(en: 'Sign up', tr: 'Kaydol'),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Misafir — en altta, düşük vurgulu.
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => _leave(false),
          child: Text(
            t(en: 'Continue as guest', tr: 'Misafir olarak devam et'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    ];
  }

  Widget _orDivider(ThemeData theme) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          t(en: 'or', tr: 'veya'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );

  /// Kayıtta şifre kuralı + tekrar eşleşmesi aranır; girişte YALNIZCA boş
  /// olmaması yeter (daha kısa şifreyle oluşturulmuş eski hesap kilitlenmesin).
  bool get _passwordFormReady {
    if (!isValidEmail(_emailText)) return false;
    return _creatingAccount
        ? isAcceptableNewPassword(_password.text) && _passwordsMatch
        : _password.text.isNotEmpty;
  }

  bool get _passwordsMatch => _passwordConfirm.text == _password.text;

  /// Tekrar alanının hata metni. İlk harfte değil, alan doluyken gösterilir.
  String? get _confirmError =>
      _passwordConfirm.text.isEmpty || _passwordsMatch
      ? null
      : t(en: 'Passwords do not match', tr: 'Şifreler eşleşmiyor');

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
      controller: _password,
      label: t(en: 'New password', tr: 'Yeni şifre'),
      helper: t(
        en: 'At least $kMinPasswordLength characters',
        tr: 'En az $kMinPasswordLength karakter',
      ),
    ),
    // Sıfırlamada da tekrar iste: yazım hatası kullanıcıyı yeni şifreyle kilitler.
    const SizedBox(height: 12),
    _passwordField(
      controller: _passwordConfirm,
      label: t(en: 'Re-enter password', tr: 'Şifreyi tekrar gir'),
      errorText: _confirmError,
    ),
    const SizedBox(height: 16),
    _primaryButton(
      label: t(en: 'Save and sign in', tr: 'Kaydet ve giriş yap'),
      onPressed:
          isValidOtpCode(_code.text) &&
              isAcceptableNewPassword(_password.text) &&
              _passwordsMatch
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? errorText,
  }) => TextField(
    controller: controller,
    enabled: !_busy,
    obscureText: _obscurePassword,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      helperText: helper,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
