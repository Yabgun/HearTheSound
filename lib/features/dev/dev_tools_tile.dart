import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_theme.dart';
import '../home/curriculum.dart';

// -----------------------------------------------------------------------------
// GELİŞTİRİCİ ARAÇLARI — GEÇİCİ (test kolaylığı için)
//
// Geliştirirken her yeni dersi görmek için önündeki bütün müfredatı oynamak
// gerekiyordu; bu, içerik testini pratikte imkânsız kılıyor. Bu bölüm o kapıyı
// tek dokunuşla açar.
//
// ⚠️ KALDIRMA TALİMATI (yayın öncesi): bu DOSYAYI sil + `settings_page.dart`
// içindeki tek `DevToolsSection()` satırını sil. Başka hiçbir yere dokunma —
// bilerek tek dosyaya hapsedildi.
//
// GÜVENLİK: her şey `kDebugMode` arkasında. Bu bir derleme sabitidir; release
// (`flutter build appbundle`) derlemesinde ağaç budanır → düğmeler yayınlanan
// uygulamaya SIZAMAZ, kaldırmayı unutsak bile. Yine de yukarıdaki talimat
// geçerli: yayında ölü kod taşımayalım.
// -----------------------------------------------------------------------------

class DevToolsSection extends ConsumerWidget {
  const DevToolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    // Müfredattaki TÜM ders id'leri. Kilit zinciri "önceki ders tamamlandı mı"
    // diye baktığı için hepsini tamam işaretlemek her dersi açar — ayrıca
    // tamamlanmış ders zaten (taç tekrarı olarak) yeniden oynanabilir.
    final allIds = lessonIdsInFirstTracks(curriculum.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.construction_rounded, color: context.colors.amberDeep),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t(
                    en: 'Developer tools · debug builds only',
                    tr: 'Geliştirici araçları · yalnızca debug',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.colors.amberDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_open_rounded),
          title: Text(t(en: 'Unlock every lesson', tr: 'Tüm dersleri aç')),
          subtitle: Text(
            t(
              en: 'Marks all ${allIds.length} lessons as done, so every track '
                  'opens. The path map will show them all ticked.',
              tr: '${allIds.length} dersin hepsini "tamam" işaretler, böylece '
                  'her track açılır. Yol Haritası hepsini ✓ gösterir.',
            ),
          ),
          onTap: () {
            ref.read(progressProvider.notifier).applyPlacement(allIds);
            _toast(
              context,
              t(
                en: '${allIds.length} lessons unlocked',
                tr: '${allIds.length} ders açıldı',
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.restart_alt_rounded, color: context.colors.danger),
          title: Text(
            t(en: 'Reset progress', tr: 'İlerlemeyi sıfırla'),
            style: TextStyle(color: context.colors.danger),
          ),
          subtitle: Text(
            t(
              en: 'Back to a brand-new account: XP, streak, completed lessons '
                  'and reviews all cleared.',
              tr: 'Sıfırdan hesaba döner: XP, seri, tamamlanan dersler ve '
                  'tekrarlar temizlenir.',
            ),
          ),
          // Tek dokunuşla geri alınamaz bir silme olmasın: kilidi açmak zararsız
          // ama sıfırlamak test ilerlemesini yok eder.
          onTap: () => _confirmReset(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(en: 'Reset progress?', tr: 'İlerleme sıfırlansın mı?')),
        content: Text(
          t(
            en: 'This cannot be undone on this device.',
            tr: 'Bu cihazda geri alınamaz.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(en: 'Cancel', tr: 'Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            child: Text(t(en: 'Reset', tr: 'Sıfırla')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(progressProvider.notifier).reset();
    _toast(context, t(en: 'Progress reset', tr: 'İlerleme sıfırlandı'));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
