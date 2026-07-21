import 'dart:convert';

import 'player_progress.dart';

// -----------------------------------------------------------------------------
// VERİ DIŞA AKTARIMI — "verimi indir" (saf, testli)
//
// Play Store'un **veri taşınabilirliği** beklentisi: kullanıcı, kendisi hakkında
// tuttuğumuz veriyi okunabilir bir biçimde alabilmeli.
//
// Ham `toMap()` yerine ayrı bir işlev olmasının sebebi: dışa aktarım kullanıcıya
// GÖSTERİLEN bir belgedir, iç serileştirme değil. Bu yüzden (a) girintili yazılır,
// (b) ne olduğunu anlatan bir başlık taşır, (c) oturum e-postası gibi yalnızca
// çalışma anında bilinen bilgiyi de içerebilir. İkisini birbirine bağlamak,
// iç şemayı her değiştirdiğimizde kullanıcının belgesini bozardı.
// -----------------------------------------------------------------------------

/// Dışa aktarılan belgenin kendi biçim sürümü (iç şemadan BAĞIMSIZ).
const int kExportFormatVersion = 1;

/// [progress]'i insan-okunur JSON belgesine çevirir.
///
/// [email] ve [exportedAt] çağıran tarafından verilir (saf kalsın: bu dosya
/// ne oturumu ne saati kendi başına okur — testte sabitlenebilir).
String buildDataExport({
  required PlayerProgress progress,
  String? email,
  required DateTime exportedAt,
}) {
  final doc = <String, dynamic>{
    'app': 'HearTheSound',
    'exportFormatVersion': kExportFormatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    if (email != null) 'account': {'email': email},
    'progress': progress.toMap(),
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}

/// Dışa aktarım dosyasının adı — tarih damgalı, dosya sistemi güvenli.
/// Ör. `heartthesound-data-2026-07-22.json`
String dataExportFileName(DateTime exportedAt) {
  final d = exportedAt.toUtc();
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return 'heartthesound-data-${d.year}-$month-$day.json';
}
