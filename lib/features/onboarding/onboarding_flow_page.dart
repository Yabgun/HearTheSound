import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_icons.dart';
import '../../ui/app_theme.dart';
import '../auth/sign_in_page.dart';
import '../calibration/calibration_page.dart';
import '../home/curriculum.dart';
import '../mascot/eko_mascot.dart';
import '../placement/placement_test_page.dart';

// -----------------------------------------------------------------------------
// ONBOARDING — ilk açılış akışı
//
// Sıra: Karşılama (Eko tanıtır) → Giriş → Adın → Avatarın → Sesini tanıyalım
// (kalibrasyon) → Başlangıç noktası. Bitince 'onboarded' bayrağı set edilir; kök
// geçiş (main) otomatik ana ekrana döner. HER adım atlanabilir (giriş: misafir;
// ad/avatar: "şimdilik atla"; kalibrasyon: "sonra").
//
// SON ADIM İKİ YOL: "müziğe yeniyim" → hiç test yok, ilk dersten başlar ·
// "biraz müzik biliyorum" → merdiven testi (features/placement/).
// -----------------------------------------------------------------------------

enum _Step { intro, signIn, nameSetup, avatarSetup, welcome, startPoint }

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  // Zaten giriş yapmış bir kullanıcı (nadir: oturum açık ama onboarding
  // bitmemiş) karşılama + giriş adımlarını atlar; ilk açılışta oturum yok →
  // intro'dan başlar.
  late _Step _step = CloudSync.instance.isSignedIn
      ? _Step.nameSetup
      : _Step.intro;

  final _name = TextEditingController();
  String? _avatarId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _goCalibration() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CalibrationPage()));
    if (mounted) setState(() => _step = _Step.startPoint);
  }

  Future<void> _goPlacement() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PlacementTestPage()),
    );
    if (mounted && completed != null) _finish();
  }

  /// Onboarding'i tamamla — kök geçiş bunu görünce ana ekrana geçer.
  void _finish() => ref.read(settingsProvider.notifier).setOnboarded(true);

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.intro => _buildIntro(context),
      _Step.signIn => SignInPage(
        // Giriş VEYA misafir sonrası: profil kurulumuna geç.
        onCompleted: () => setState(() => _step = _Step.nameSetup),
      ),
      _Step.nameSetup => _buildNameSetup(context),
      _Step.avatarSetup => _buildAvatarSetup(context),
      _Step.welcome => _buildWelcome(context),
      _Step.startPoint => _buildStartPoint(context),
    };
  }

  /// Kompakt dil seçici (EN/TR) — karşılama ekranının üst köşesinde. İngilizce
  /// bilmeyen kullanıcı en baştan Türkçe'ye geçebilsin.
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

  // --- Karşılama (Eko uygulamayı tanıtır → girişe yönlendirir) ----------------

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: _langToggle()),
              const Spacer(flex: 2),
              const EkoMascot(size: 128),
              const SizedBox(height: 24),
              Text(
                'HearTheSound',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  en: "Hi, I'm Eko! 👋\nHear a sound, understand it, then sing it "
                      'back — I\'ll grow your musical ear and theory, step by step.',
                  tr: 'Selam, ben Eko! 👋\nBir sesi duy, ne olduğunu anla, sonra '
                      'sesinle söyle — müzik kulağını ve teori bilgini adım adım '
                      'geliştireceğiz.',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _loopRow(theme),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _step = _Step.signIn),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(t(en: "Let's begin", tr: 'Hadi başlayalım')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Profil kurulumu (login sonrası, tane tane, atlanabilir) ----------------

  /// İçeriği ekran yüksekliğinde tutar ama klavye açılınca kaydırılabilir yapar.
  /// Böylece Spacer'lı dikey denge klavye kapalıyken korunur, klavye açılınca
  /// alan kaydırılır ve alttaki buton/"atla" satırı taşmaz (aksi halde Spacer'lar
  /// sıkışamayıp overflow veriyordu).
  Widget _fullHeightScroll({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }

  /// "Adın ne?" adımı. Boş bırakılıp atlanabilir (anonim kalır).
  Widget _buildNameSetup(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: _fullHeightScroll(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: EkoMascot(size: 96)),
                const SizedBox(height: 24),
                Text(
                  t(
                    en: "Let's set up your profile",
                    tr: 'Hadi profilini kuralım',
                  ),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    en: 'What should I call you?',
                    tr: 'Sana nasıl hitap edeyim?',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 24,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: t(en: 'Your name', tr: 'Adın'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveNameAndNext(),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saveNameAndNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(t(en: 'Continue', tr: 'Devam')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _step = _Step.avatarSetup),
                  child: Text(t(en: 'Skip for now', tr: 'Şimdilik atla')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveNameAndNext() {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      ref.read(progressProvider.notifier).setDisplayName(name);
    }
    setState(() => _step = _Step.avatarSetup);
  }

  /// "Eko'nu seç" adımı. Seçilmezse atlanınca varsayılan Eko kalır.
  Widget _buildAvatarSetup(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ekoPaletteFor(_avatarId);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              // Seçilen renkte canlı önizleme.
              EkoMascot(size: 120, palette: selected),
              const SizedBox(height: 20),
              Text(
                t(en: 'Pick your Eko', tr: 'Eko\'nu seç'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  en: 'Choose a color — this is your companion.',
                  tr: 'Bir renk seç — bu senin yol arkadaşın.',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in kEkoPalettes)
                    _avatarChoice(
                      palette: p,
                      selected: selected.id == p.id,
                      onTap: () => setState(() => _avatarId = p.id),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saveAvatarAndNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(t(en: 'Continue', tr: 'Devam')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _step = _Step.welcome),
                child: Text(t(en: 'Skip for now', tr: 'Şimdilik atla')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAvatarAndNext() {
    if (_avatarId != null) {
      ref.read(progressProvider.notifier).setAvatar(_avatarId!);
    }
    setState(() => _step = _Step.welcome);
  }

  Widget _avatarChoice({
    required EkoPalette palette,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(44),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.from.withValues(alpha: 0.16),
            border: Border.all(
              color: selected ? AppColors.ink : Colors.transparent,
              width: 3,
            ),
          ),
          alignment: Alignment.center,
          child: EkoMascot(size: 52, palette: palette),
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // Dil seçimi artık giriş adımında (signIn) yapılıyor — burada yok.
              const Spacer(flex: 2),
              const EkoMascot(size: 118),
              const SizedBox(height: 24),
              Text(
                'HearTheSound',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  en: "Hear it · get it · sing it back.\nLet's grow your musical ear step by step.",
                  tr: 'Duy · anla · sesinle söyle.\nMüzik kulağını adım adım geliştirelim.',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              // Çekirdek döngüyü görselleştir: Duy → Anla → Söyle.
              _loopRow(theme),
              const Spacer(),
              Text(
                t(
                  en: "Let's meet your voice first so I can tailor the lessons to you.",
                  tr: 'Önce sesini tanıyalım ki dersleri tam sana göre hazırlayayım.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goCalibration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(t(en: "Let's start", tr: 'Başlayalım')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _step = _Step.startPoint),
                child: Text(
                  t(
                    en: "I'll calibrate later",
                    tr: 'Kalibrasyonu sonra yaparım',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Çekirdek döngü rozeti: Duy → Anla → Söyle (onboarding karşılamasında).
  Widget _loopRow(ThemeData theme) {
    Widget chip(IconData icon, String label, Color color) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    Widget arrow() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(Icons.headphones_rounded, t(en: 'Hear', tr: 'Duy'), AppColors.coral),
        arrow(),
        chip(
          Icons.lightbulb_rounded,
          t(en: 'Get it', tr: 'Anla'),
          AppColors.grape,
        ),
        arrow(),
        chip(Icons.mic_rounded, t(en: 'Sing', tr: 'Söyle'), AppColors.teal),
      ],
    );
  }

  /// Seçilen seviye: müfredatın ilk [precompleteTracks] track'ini "tamam"
  /// işaretle (o track'ler açık başlar → zincir bir sonrakini açar), sonra bitir.
  void _chooseLevel(int precompleteTracks) {
    ref
        .read(progressProvider.notifier)
        .applyPlacement(lessonIdsInFirstTracks(precompleteTracks));
    _finish();
  }

  /// BAŞLANGIÇ NOKTASI — iki yol.
  ///
  /// Eskiden burada dört "seviye kartı" vardı ve kullanıcıdan kendini
  /// etiketlemesi isteniyordu ("Ezgileri kulakla takip edebiliyorum" — bunun
  /// ne demek olduğunu bilen zaten bilir, bilmeyen tahmin eder). İki sebeple
  /// kaldırıldı: (a) kullanıcı kendi seviyesini bilemez, (b) yanlış seçim
  /// sessizce ya sıkıcı ya da imkânsız bir müfredat verir.
  ///
  /// Yerine: sıfırdan başlayan hiçbir test görmez (tek dokunuş, hemen başlar);
  /// bir şeyler bilen ise GERÇEK derslerle sınanır (merdiven testi).
  Widget _buildStartPoint(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Where should we start?', tr: 'Nereden başlayalım?')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              t(
                en: 'Two ways in. If music is new to you, we begin at the very '
                    'first lesson. If you already play or sing, I can test you '
                    'and skip the parts you know.',
                tr: 'İki yol var. Müzik sana yeniyse en baştan başlarız. Zaten '
                    'çalıyor ya da söylüyorsan seni sınayıp bildiğin bölümleri '
                    'atlayabilirim.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _levelCard(
              theme,
              icon: AppIcons.levelBeginner,
              title: t(en: "I'm new to music", tr: 'Müziğe yeniyim'),
              subtitle: t(
                en: 'Start at the first lesson',
                tr: 'İlk dersten başla',
              ),
              color: AppColors.catNotes,
              onTap: () => _chooseLevel(0),
            ),
            _levelCard(
              theme,
              icon: AppIcons.levelChords,
              title: t(
                en: 'I already know some music',
                tr: 'Biraz müzik biliyorum',
              ),
              subtitle: t(
                en: 'Take a short test — skip what you know',
                tr: 'Kısa bir test yap — bildiğini atla',
              ),
              color: AppColors.catHarmony,
              onTap: _goPlacement,
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 26, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
