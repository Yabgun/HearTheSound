import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/version_gate.dart';
import 'supabase_config.dart';

// -----------------------------------------------------------------------------
// APP CONFIG — sunucudan yayın yapılandırmasını okuma
//
// `app_config` tek satırlık, HERKESE-AÇIK OKUNUR bir tablodur (anon SELECT
// açık — misafir kullanıcı da güncelleme kapısından geçmeli). İçinde kişisel
// veri yoktur; yalnızca sürüm eşikleri ve isteğe bağlı duyuru mesajı.
//
// Yazma yolu YOKTUR: değerler yalnızca Supabase panelinden (Table Editor)
// değiştirilir. "3. sürümü yasakla" = panelde bir sayıyı büyütmek.
// -----------------------------------------------------------------------------

/// Sunucudan güncel yapılandırmayı çeker; HER hatada null (fail-open).
///
/// Bilerek hiçbir istisna sızdırmaz: bulut kapalı, ağ yok, tablo yok, Supabase
/// başlatılmamış (testler) — hepsi "config alınamadı" = null olur ve çağıran
/// önbelleğe/varsayılana düşer.
Future<AppConfig?> fetchAppConfig() async {
  try {
    if (!isCloudConfigured) return null;
    final row = await Supabase.instance.client
        .from('app_config')
        .select()
        .eq('id', 1)
        .maybeSingle();
    if (row == null) return null;
    return AppConfig.fromMap(row);
  } catch (_) {
    return null;
  }
}
