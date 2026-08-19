import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../notifications/notification_service.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../../ui/app_theme.dart';
import '../../ui/note_names_sheet.dart';
import '../auth/sign_in_page.dart';
import '../dev/dev_tools_tile.dart';
import '../profile/profile_identity.dart';

// -----------------------------------------------------------------------------
// AYARLAR — dil + hesap + günlük hatırlatma + veri + sürüm
//
// HESAP YERLEŞİMİ: giriş/çıkış AppBar'ın SAĞINDA tek dokunuşluk bir EYLEM
// (`_AccountAction`); gövdede kalan hesap satırları yalnızca oturum açıkken
// görünür. Eskiden hesap bloğu listenin en büyük ve en karmaşık parçasıydı
// (girişsizken koca bir tanıtım paragrafı + tam genişlik düğme) — oysa
// kullanıcının orada yapacağı iş tek bir dokunuştan ibaret.
// -----------------------------------------------------------------------------

/// AppBar'ın sağındaki hesap eylemi.
///
/// Oturum KAPALIYSA: "Sign in" metin düğmesi → adanmış giriş ekranı.
/// Oturum AÇIKSA: kırmızı kapı ikonu → onay diyaloğu → çıkış.
///
/// Bulut yapılandırılmamışsa (supabase_config boş) hiç çizilmez — uygulama o
/// hâlde tamamen yereldir, hesap kavramı yoktur.
class _AccountAction extends ConsumerStatefulWidget {
  const _AccountAction();

  @override
  ConsumerState<_AccountAction> createState() => _AccountActionState();
}

class _AccountActionState extends ConsumerState<_AccountAction> {
  bool _busy = false;

  /// Adanmış giriş ekranını açar. Ekran `true` ile dönerse oturum açılmış ve
  /// ilerleme çoktan birleştirilmiştir (bkz. `SignInPage._afterSignIn`) —
  /// burada yalnızca yeniden çizip kullanıcıya haber veriyoruz.
  Future<void> _openSignIn() async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const SignInPage()),
    );
    if (!mounted) return;
    setState(() {});
    if (signedIn == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              en: 'Signed in — progress synced. ✓',
              tr: 'Giriş yapıldı — ilerleme eşitlendi. ✓',
            ),
          ),
        ),
      );
    }
  }

  /// Çıkış — onaylı. İkon sözsüz olduğu için niyet diyalogda yazıyla kurulur;
  /// ayrıca ilerlemenin cihazda KALDIĞI söyleniyor: kırmızı bir kapı ikonu
  /// "her şeyi sileceğim" gibi okunabilir, oysa çıkış veri silmez.
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(en: 'Sign out?', tr: 'Çıkış yapılsın mı?')),
        content: Text(
          t(
            en: 'Are you sure you want to sign out of your account? Your '
                'progress stays on this device.',
            tr: 'Hesaptan çıkmak istediğinize emin misiniz? İlerlemeniz bu '
                'cihazda kalır.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(en: 'Cancel', tr: 'Vazgeç')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(en: 'Sign out', tr: 'Çıkış yap')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await CloudSync.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                en: 'Could not sign out. Check your connection and try again.',
                tr: 'Çıkış yapılamadı. Bağlantını kontrol edip tekrar dene.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudSync.instance.isConfigured) return const SizedBox.shrink();

    if (CloudSync.instance.user == null) {
      return TextButton(
        onPressed: _busy ? null : _openSignIn,
        child: Text(t(en: 'Sign in', tr: 'Giriş yap')),
      );
    }

    // Sözsüz düğme → etiket ZORUNLU: ekran okuyucu "düğme" değil "çıkış yap"
    // demeli. `tooltip` hem uzun basışta yazıyı gösterir hem Semantics etiketini
    // kurar, yani tek yerde iki iş.
    return IconButton(
      onPressed: _busy ? null : _confirmSignOut,
      tooltip: t(en: 'Sign out', tr: 'Çıkış yap'),
      icon: Icon(Icons.logout_rounded, color: context.colors.danger),
    );
  }
}

/// Oturum AÇIKKEN gövdede görünen hesap satırları: kimlik + elle eşitle +
/// hesap silme. Girişsizken hiçbir şey çizmez (o durumda yapılacak tek iş
/// AppBar'daki "Sign in").
///
/// "Hesabımı ve verimi sil" burada KALIR — Play Store zorunluluğu.
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      setState(
        () => _error = t(
          en: 'Something went wrong. Check your connection and try again.',
          tr: 'Bir şeyler ters gitti. Bağlantını kontrol edip tekrar dene.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() => _run(() async {
    final repo = ref.read(progressRepositoryProvider);
    await CloudSync.instance.pullAndMerge(repo);
    if (!mounted) return;
    ref.read(progressProvider.notifier).reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(en: 'Synced. ✓', tr: 'Eşitlendi. ✓'))),
    );
  });

  /// Hesap silme — Play Store "veri silme" zorunluluğu. Çift onaylı, geri alınamaz.
  Future<void> _deleteAccount() async {
    final first = await _confirmDelete(
      title: t(en: 'Delete account & data?', tr: 'Hesabı ve veriyi sil?'),
      body: t(
        en:
            'This permanently deletes your account and all synced progress from '
            'the server, and clears it from this device.',
        tr:
            'Bu, hesabını ve sunucudaki tüm eşitlenmiş ilerlemeni kalıcı olarak '
            'siler; bu cihazdan da temizler.',
      ),
      confirm: t(en: 'Continue', tr: 'Devam et'),
    );
    if (first != true || !mounted) return;
    final second = await _confirmDelete(
      title: t(en: 'This cannot be undone', tr: 'Bu geri alınamaz'),
      body: t(
        en: 'Are you sure you want to permanently delete your account?',
        tr: 'Hesabını kalıcı olarak silmek istediğine emin misin?',
      ),
      confirm: t(en: 'Delete', tr: 'Sil'),
    );
    if (second != true || !mounted) return;
    await _run(() async {
      await CloudSync.instance.deleteAccount(
        ref.read(progressRepositoryProvider),
      );
      if (!mounted) return;
      ref.read(progressProvider.notifier).reload(); // yerel temizlendi → tazele
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(en: 'Account deleted.', tr: 'Hesap silindi.')),
        ),
      );
    });
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String body,
    required String confirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(en: 'Cancel', tr: 'Vazgeç')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = CloudSync.instance.user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_rounded),
          title: Text(t(en: 'Account', tr: 'Hesap')),
          subtitle: Text(user.email ?? ''),
        ),
        // Eşitleme zaten otomatik (kayıt sonrası debounce'lu itme); bu satır
        // "şimdi olsun" diyebilmek için — bir düğme sırası yerine liste satırı,
        // ayarların geri kalanıyla aynı ritimde.
        ListTile(
          leading: const Icon(Icons.sync_rounded),
          title: Text(t(en: 'Sync now', tr: 'Şimdi eşitle')),
          enabled: !_busy,
          onTap: _busy ? null : _syncNow,
        ),
        // Eşitleme/silme hataları burada görünür (sessizce yutulmaz).
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_rounded,
            color: context.colors.danger,
          ),
          title: Text(
            t(en: 'Delete account & data', tr: 'Hesabımı ve verimi sil'),
            style: TextStyle(color: context.colors.danger),
          ),
          enabled: !_busy,
          onTap: _busy ? null : _deleteAccount,
        ),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _fmt(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Settings', tr: 'Ayarlar')),
        actions: const [_AccountAction(), SizedBox(width: 4)],
      ),
      body: ListView(
        children: [
          // Dil — varsayılan İngilizce; içerik ve arayüz birlikte değişir.
          // Seçici KENDİ satırında (ListTile trailing DEĞİL): "Language"/"Dil"
          // başlığı dar segmentli düğmenin yanına sığmayıp alt satıra kayıyordu.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.language_rounded),
                const SizedBox(width: 16),
                Text(
                  t(en: 'Language', tr: 'Dil'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
              ],
              selected: {settings.localeCode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ctrl.setLocale(selection.first),
            ),
          ),
          const Divider(),
          // Hesap satırları — yalnızca bulut yapılandırılmış VE oturum açıkken
          // görünür (girişsizken tek iş AppBar'daki "Sign in").
          if (CloudSync.instance.isConfigured &&
              CloudSync.instance.user != null) ...[
            const _AccountSection(),
            const Divider(),
          ],
          // TEMA — dil seçicisiyle aynı desen: başlık kendi satırında, seçici
          // altında. Varsayılan AÇIK; koyu tema ve sistem takibi kullanıcının
          // seçimi (bkz. AppSettings.themeMode).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  settings.themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
                const SizedBox(width: 16),
                Text(
                  t(en: 'Theme', tr: 'Tema'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(t(en: 'Light', tr: 'Açık')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(t(en: 'Dark', tr: 'Koyu')),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(t(en: 'System', tr: 'Sistem')),
                ),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => ctrl.setThemeMode(s.first),
            ),
          ),
          const Divider(),
          // Nota adları başvuru kartı — ders ekranlarındaki ℹ️ ile AYNI kart.
          // Ayarlar'da da olması şart: kullanıcı ders ortasında değilken de
          // "C ne demekti?" diye bakabilmeli.
          ListTile(
            leading: const Icon(Icons.music_note_rounded),
            title: Text(t(en: 'Note names', tr: 'Nota adları')),
            subtitle: Text(t(en: 'C = Do, D = Re…', tr: 'C = Do, D = Re…')),
            onTap: () => showNoteNamesSheet(context),
          ),
          const Divider(),
          // Not: "Ses aralığı" ve "Oyun alanı" Pratik sekmesinde yaşıyor (Ayarlar'da
          // kopyaları kaldırıldı). "Piyano tınısı" anahtarı da kaldırıldı — v1
          // her zaman gerçek piyano; başka enstrümanlar ileride gelir.
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(t(en: 'Daily reminder', tr: 'Günlük hatırlatma')),
            subtitle: Text(
              settings.reminderEnabled
                  ? t(
                      en:
                          'Every day around ${_fmt(NotificationService.dailyReminderHour)}',
                      tr:
                          'Her gün ${_fmt(NotificationService.dailyReminderHour)} civarı',
                    )
                  : t(en: 'Off', tr: 'Kapalı'),
            ),
            value: settings.reminderEnabled,
            onChanged: (value) async {
              if (value) {
                final granted = await NotificationService.instance
                    .requestPermission();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t(
                            en: 'Notification permission was not granted.',
                            tr: 'Bildirim izni verilmedi.',
                          ),
                        ),
                      ),
                    );
                  }
                  return;
                }
                await NotificationService.instance.scheduleDaily();
                await ctrl.setEnabled(true);
              } else {
                await NotificationService.instance.cancelDaily();
                await ctrl.setEnabled(false);
              }
            },
          ),
          const Divider(),
          // Veri taşınabilirliği (Play zorunluluğu) — §19. Profil'den buraya
          // taşındı: veri/gizlilik işlemleri Ayarlar altında toplanıyor.
          const ExportDataTile(),
          // GEÇİCİ geliştirici bölümü — release'de kendini gizler. Kaldırma
          // talimatı: dev_tools_tile.dart dosyasını ve bu satırı sil.
          const DevToolsSection(),
          // Sürüm — destek isteğinde kullanıcının bize okuyacağı sayı; ayrıca
          // "güncelledim mi?" sorusunun tek cevabı. PackageInfo okunamadıysa
          // (bkz. appVersionProvider) satır hiç çizilmez.
          if (version != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Center(
                child: Text(
                  t(en: 'Version $version', tr: 'Sürüm $version'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
