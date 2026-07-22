import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content_locale.dart';
import '../../state/update_gate_controller.dart';
import '../mascot/eko_mascot.dart';

// -----------------------------------------------------------------------------
// GÜNCELLEME KAPISI (§20) — zorunlu güncelleme ekranı + yumuşak öneri kartı
//
// `UpdateGate` uygulama ağacının EN ÜSTÜNE sarılır (_RootGate'ten önce):
// karar "force" ise çocuk hiç kurulmaz, kaçışsız engelleme ekranı gösterilir.
// Karar oturum ORTASINDA force'a dönerse de ekran anında değişir (kill-switch).
// -----------------------------------------------------------------------------

/// Play Store ürün sayfası. `market://` yerine https kullanıyoruz: Android bunu
/// zaten Play uygulamasında açar, ayrıca paket-görünürlük (queries) istisnası
/// gerektirmez ve Play kurulu olmayan cihazda da (tarayıcı) çalışır.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.hearthesound.hear_the_sound';

/// Engelleme kapısı: force değilse [child]'ı olduğu gibi gösterir.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(updateGateProvider.select((s) => s.blocked));
    return blocked ? const UpdateRequiredPage() : child;
  }
}

/// Kaçışsız zorunlu güncelleme ekranı.
class UpdateRequiredPage extends ConsumerWidget {
  const UpdateRequiredPage({super.key});

  Future<void> _openStore() =>
      launchUrl(Uri.parse(kPlayStoreUrl), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(updateGateProvider.select((s) => s.config));

    // Panelden özel mesaj girildiyse onu, yoksa varsayılanı göster.
    final custom = ContentLocale.isTr
        ? (config.messageTr ?? config.messageEn)
        : (config.messageEn ?? config.messageTr);
    final message = (custom == null || custom.trim().isEmpty)
        ? t(
            en:
                'This version of HearTheSound is no longer supported. '
                'Please update to keep practicing.',
            tr:
                'HearTheSound\'un bu sürümü artık desteklenmiyor. '
                'Pratiğe devam etmek için lütfen güncelle.',
          )
        : custom;

    // PopScope(canPop: false): geri tuşu kapıyı KAPATAMAZ — zorunlu demek bu.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EkoMascot(size: 96),
                  const SizedBox(height: 20),
                  Icon(
                    Icons.system_update_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(en: 'Update required', tr: 'Güncelleme gerekli'),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      en: 'Your progress is safe and will be waiting for you.',
                      tr: 'İlerlemen güvende — seni bekliyor olacak.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.shop_rounded),
                    label: Text(
                      t(en: 'Update on Play Store', tr: 'Play Store\'da güncelle'),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bugün ekranına eklenen kapatılabilir "yeni sürüm var" kartı.
/// Uygun değilse hiçbir şey çizmez → çağıran koşulsuz ekleyebilir.
class UpdateSuggestCard extends ConsumerWidget {
  const UpdateSuggestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      updateGateProvider.select((s) => s.showSuggestion),
    );
    if (!show) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t(
                    en: 'A new version is available on Play Store.',
                    tr: 'Play Store\'da yeni bir sürüm var.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(kPlayStoreUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(t(en: 'Update', tr: 'Güncelle')),
              ),
              IconButton(
                tooltip: t(en: 'Dismiss', tr: 'Kapat'),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () =>
                    ref.read(updateGateProvider.notifier).dismissSuggestion(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
