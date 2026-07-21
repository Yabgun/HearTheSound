import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/content_locale.dart';
import '../../core/data_export.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_theme.dart';
import '../mascot/eko_mascot.dart';

// -----------------------------------------------------------------------------
// PROFİL KİMLİĞİ — avatar, görünen ad, hesap ve üyelik tarihi
//
// Veri, ilerleme JSON'unun içindeki `profile` alt-nesnesinde yaşar (ayrı tablo
// YOK) → bulut senkronu ve birleştirme bedavaya gelir. Bkz. core/player_profile.dart
// -----------------------------------------------------------------------------

/// Profil başlığı: avatar + ad + hesap durumu + üyelik tarihi.
class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(progressProvider).profile;
    // E-postanın tek doğru kaynağı oturumun kendisi — kopyasını saklamıyoruz.
    final email = CloudSync.instance.isConfigured
        ? CloudSync.instance.user?.email
        : null;

    return Row(
      children: [
        _AvatarBubble(avatarId: profile.avatarId),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.hasDisplayName
                    ? profile.displayName!
                    : t(en: 'Add your name', tr: 'Adını ekle'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: profile.hasDisplayName
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email ?? t(en: 'Playing as guest', tr: 'Misafir olarak oynuyor'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (profile.joinedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  t(
                    en: 'Member since ${formatMonthYear(profile.joinedAt!)}',
                    tr: '${formatMonthYear(profile.joinedAt!)} tarihinden beri üye',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: t(en: 'Edit profile', tr: 'Profili düzenle'),
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => showProfileEditSheet(context, ref),
        ),
      ],
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.avatarId});

  final String? avatarId;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final palette = ekoPaletteFor(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.from.withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: EkoMascot(size: size * 0.86, palette: palette),
    );
  }
}

/// Ay-yıl etiketi, aktif dile göre. (Sırf bunun için `intl` bağımlılığı
/// eklemiyoruz — 12 ad × 2 dil, uygulamanın `t()` mekanizmasıyla tutarlı.)
String formatMonthYear(DateTime date) {
  const en = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const tr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  final month = ContentLocale.isTr ? tr[date.month - 1] : en[date.month - 1];
  return '$month ${date.year}';
}

/// Ad + avatar düzenleme sayfası (alt sayfa olarak açılır).
Future<void> showProfileEditSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ProfileEditSheet(),
  );
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet();

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _name;
  late String? _avatarId;

  /// Görünen ad üst sınırı — listelerde taşmasın, sunucuya şişkin veri gitmesin.
  static const int _maxNameLength = 24;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(progressProvider).profile;
    _name = TextEditingController(text: profile.displayName ?? '');
    _avatarId = profile.avatarId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final ctrl = ref.read(progressProvider.notifier);
    ctrl.setDisplayName(_name.text);
    if (_avatarId != null) ctrl.setAvatar(_avatarId!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Klavye açılınca içerik gizlenmesin.
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(en: 'Edit profile', tr: 'Profili düzenle'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: _maxNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t(en: 'Display name', tr: 'Görünen ad'),
              helperText: t(
                en: 'Leave empty to stay anonymous',
                tr: 'Anonim kalmak için boş bırak',
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(en: 'Your Eko', tr: 'Senin Eko\'n'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final palette in kEkoPalettes)
                _AvatarChoice(
                  palette: palette,
                  selected: ekoPaletteFor(_avatarId).id == palette.id,
                  onTap: () => setState(() => _avatarId = palette.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(t(en: 'Save', tr: 'Kaydet')),
          ),
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final EkoPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.from.withValues(alpha: 0.16),
            border: Border.all(
              color: selected ? AppColors.ink : Colors.transparent,
              width: 3,
            ),
          ),
          alignment: Alignment.center,
          child: EkoMascot(size: 48, palette: palette),
        ),
      ),
    );
  }
}

/// "Verimi indir" satırı — Play veri taşınabilirliği.
class ExportDataTile extends ConsumerStatefulWidget {
  const ExportDataTile({super.key});

  @override
  ConsumerState<ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends ConsumerState<ExportDataTile> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final progress = ref.read(progressProvider);
      final now = DateTime.now();
      final json = buildDataExport(
        progress: progress,
        email: CloudSync.instance.isConfigured
            ? CloudSync.instance.user?.email
            : null,
        exportedAt: now,
      );

      // Geçici dosyaya yaz → paylaşım sayfası (Dosyalar/Drive/e-posta...).
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${dataExportFileName(now)}');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: t(
            en: 'My HearTheSound data',
            tr: 'HearTheSound verilerim',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              en: 'Could not export your data. Please try again.',
              tr: 'Verin dışa aktarılamadı. Lütfen tekrar dene.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.download_rounded),
      title: Text(t(en: 'Download my data', tr: 'Verimi indir')),
      subtitle: Text(
        t(
          en: 'Export everything we store about you as a JSON file',
          tr: 'Senin hakkında sakladığımız her şeyi JSON dosyası olarak al',
        ),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _busy ? null : _export,
    );
  }
}
