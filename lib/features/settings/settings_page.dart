import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../core/content_locale.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../notifications/notification_service.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../calibration/calibration_page.dart';
import '../explorer/range_playground_page.dart';

// -----------------------------------------------------------------------------
// AYARLAR — ses aralığı kalibrasyonu + günlük hatırlatma bildirimi
// -----------------------------------------------------------------------------

/// Hesap & bulut senkron bölümü — e-posta + 6 haneli kodla giriş (OTP).
/// Şifre yok; kod e-postaya gelir. Girişte buluttaki ilerleme YERELLE KAYIPSIZ
/// birleştirilir (mergeProgress) ve arayüz tazelenir.
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

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

  Future<void> _sendCode() => _run(() async {
    await CloudSync.instance.sendOtp(_email.text.trim());
    setState(() => _codeSent = true);
  });

  Future<void> _verify() => _run(() async {
    await CloudSync.instance.verifyOtp(
      email: _email.text.trim(),
      code: _code.text.trim(),
    );
    // Giriş başarılı → buluttakiyle kayıpsız birleştir, arayüzü tazele.
    final repo = ref.read(progressRepositoryProvider);
    await CloudSync.instance.pullAndMerge(repo);
    if (!mounted) return;
    ref.read(progressProvider.notifier).reload();
    setState(() {
      _codeSent = false;
      _code.clear();
    });
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
  });

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

    // OTURUM KAPALI — e-posta → kod → doğrula.
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
                  'Sign in with your email to back up progress and use it on '
                  'any device. No password — we send a 6-digit code.',
              tr:
                  'İlerlemeni yedeklemek ve her cihazda kullanmak için '
                  'e-postanla giriş yap. Şifre yok — 6 haneli kod göndeririz.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: t(en: 'Email', tr: 'E-posta'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t(en: '6-digit code', tr: '6 haneli kod'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
            child: Text(
              _codeSent
                  ? t(en: 'Verify and sign in', tr: 'Doğrula ve giriş yap')
                  : t(en: 'Send code', tr: 'Kod gönder'),
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
    final range = ref.watch(progressProvider).vocalRange;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Settings', tr: 'Ayarlar')),
      ),
      body: ListView(
        children: [
          // Dil — varsayılan İngilizce; içerik ve arayüz birlikte değişir.
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(t(en: 'Language', tr: 'Dil')),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
              ],
              selected: {settings.localeCode},
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
          ListTile(
            leading: const Icon(Icons.graphic_eq_rounded),
            title: Text(t(en: 'Vocal range', tr: 'Ses aralığı')),
            subtitle: Text(
              range == null
                  ? t(
                      en: 'Not calibrated yet — tap to measure',
                      tr: 'Henüz kalibre edilmedi — dokun ve ölç',
                    )
                  : '${t(en: 'Comfortable', tr: 'Rahat')}: '
                        '${range.comfortLowNote.label} – ${range.comfortHighNote.label}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CalibrationPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.explore_rounded),
            title: Text(
              t(en: 'Vocal range playground', tr: 'Ses aralığı oyun alanı'),
            ),
            subtitle: Text(
              t(
                en: 'Explore and stretch your voice (no scoring)',
                tr: 'Keşfet ve sesini genişlet (puansız)',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RangePlaygroundPage(),
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.piano_rounded),
            title: Text(t(en: 'Piano sound', tr: 'Piyano tınısı')),
            subtitle: Text(
              settings.instrument == Instrument.piano
                  ? t(
                      en: 'Real piano samples (GeneralUser GS)',
                      tr: 'Gerçek piyano örnekleri (GeneralUser GS)',
                    )
                  : t(en: 'Simple synth tone', tr: 'Basit sentez ton'),
            ),
            value: settings.instrument == Instrument.piano,
            onChanged: (value) =>
                ctrl.setInstrument(value ? Instrument.piano : Instrument.synth),
          ),
          const Divider(),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: Text(
              t(en: 'Send test notification', tr: 'Test bildirimi gönder'),
            ),
            subtitle: Text(
              t(
                en: 'Fire one right now (to verify)',
                tr: 'Hemen bir bildirim at (doğrulama için)',
              ),
            ),
            onTap: () async {
              final granted = await NotificationService.instance
                  .requestPermission();
              if (granted) {
                await NotificationService.instance.showTestNow();
              } else if (context.mounted) {
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
            },
          ),
        ],
      ),
    );
  }
}
