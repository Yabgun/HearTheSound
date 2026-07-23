import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../notifications/notification_service.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../auth/sign_in_page.dart';

// -----------------------------------------------------------------------------
// AYARLAR — ses aralığı kalibrasyonu + günlük hatırlatma bildirimi
// -----------------------------------------------------------------------------

/// Hesap & bulut senkron bölümü.
///
/// Oturum KAPALIYKEN: adanmış giriş ekranına (`SignInPage`) götüren tek düğme.
/// Oturum AÇIKKEN: e-posta + şimdi eşitle / çıkış / hesap silme.
/// Giriş akışının kendisi burada değil — kimlik, Ayarlar'ın bir satırı değil
/// birinci sınıf bir akıştır (bkz. `features/auth/sign_in_page.dart`).
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

  /// Adanmış giriş ekranını açar. Ekran `true` ile dönerse oturum açılmış ve
  /// ilerleme çoktan birleştirilmiştir (bkz. `SignInPage._afterSignIn`) —
  /// burada yalnızca bölümü yeniden çizip kullanıcıya haber veriyoruz.
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

  Future<void> _syncNow() => _run(() async {
    final repo = ref.read(progressRepositoryProvider);
    await CloudSync.instance.pullAndMerge(repo);
    if (!mounted) return;
    ref.read(progressProvider.notifier).reload();
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

    if (user != null) {
      // OTURUM AÇIK — e-posta + eşitle/çıkış.
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_done_rounded),
            title: Text(t(en: 'Account', tr: 'Hesap')),
            subtitle: Text(user.email ?? ''),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _syncNow,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(t(en: 'Sync now', tr: 'Şimdi eşitle')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await CloudSync.instance.signOut();
                            if (mounted) setState(() {});
                          }),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(t(en: 'Sign out', tr: 'Çıkış yap')),
                  ),
                ),
              ],
            ),
          ),
          // Eşitleme/çıkış/silme hataları burada görünür (sessizce yutulmaz).
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 4),
          // Hesap silme — Play Store "veri silme" zorunluluğu (çift onaylı).
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _deleteAccount,
              icon: Icon(
                Icons.delete_forever_rounded,
                color: theme.colorScheme.error,
              ),
              label: Text(
                t(en: 'Delete account & data', tr: 'Hesabımı ve verimi sil'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    // OTURUM KAPALI — adanmış giriş ekranına yönlendir.
    // (Form artık burada değil: kimlik, Ayarlar'ın bir satırı değil kendi akışı.)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 12),
              Text(
                t(en: 'Account & sync', tr: 'Hesap & senkron'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t(
              en:
                  'Sign in to back up your progress and continue on any '
                  'device. Google, email code, or password — your choice.',
              tr:
                  'İlerlemeni yedeklemek ve her cihazda devam etmek için giriş '
                  'yap. Google, e-posta kodu ya da şifre — sen seç.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _openSignIn,
            icon: const Icon(Icons.login_rounded),
            label: Text(t(en: 'Sign in', tr: 'Giriş yap')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Settings', tr: 'Ayarlar')),
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
          // Hesap & bulut senkron — yalnızca Supabase yapılandırıldıysa görünür
          // (supabase_config.dart doldurulunca). Yerel kullanım için şart değil.
          if (CloudSync.instance.isConfigured) ...[
            const _AccountSection(),
            const Divider(),
          ],
          // Not: "Ses aralığı" ve "Oyun alanı" Pratik sekmesinde yaşıyor (Ayarlar'da
          // kopyaları kaldırıldı). "Piyano tınısı" anahtarı da kaldırıldı — v1
          // her zaman gerçek piyano; başka enstrümanlar ileride gelir.
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(t(en: 'Daily reminder', tr: 'Günlük hatırlatma')),
            subtitle: Text(
              settings.reminderEnabled
                  ? t(
                      en: 'Every day around ${_fmt(settings.reminderHour)}',
                      tr: 'Her gün ${_fmt(settings.reminderHour)} civarı',
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
                await NotificationService.instance.scheduleDaily(
                  hour: settings.reminderHour,
                );
                await ctrl.setEnabled(true);
              } else {
                await NotificationService.instance.cancelDaily();
                await ctrl.setEnabled(false);
              }
            },
          ),
          ListTile(
            enabled: settings.reminderEnabled,
            leading: const Icon(Icons.schedule_rounded),
            title: Text(t(en: 'Reminder time', tr: 'Hatırlatma saati')),
            subtitle: Text(_fmt(settings.reminderHour)),
            onTap: settings.reminderEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.reminderHour,
                        minute: 0,
                      ),
                    );
                    if (picked != null) {
                      await ctrl.setHour(picked.hour);
                      await NotificationService.instance.scheduleDaily(
                        hour: picked.hour,
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
