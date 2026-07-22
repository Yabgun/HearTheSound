import 'dart:convert';

// -----------------------------------------------------------------------------
// ZORUNLU GÜNCELLEME KAPISI — sürüm karşılaştırma çekirdeği (saf, testli)
//
// Sunucudaki `app_config` tablosu iki eşik yayınlar:
//   min_supported_build .. bunun ALTINDAKİ sürümler ZORUNLU güncellenir
//   latest_build ......... bunun altındakilere yumuşak "yeni sürüm var" önerisi
//
// Karşılaştırma pubspec'teki `+N` build numarasıyla yapılır (versionCode) —
// monotonik tamsayı; "1.10.0 mu 1.2.0'dan büyük?" tarzı semver string
// ayrıştırma hataларına yer yok.
//
// FAIL-OPEN İLKESİ: bu kapının kendi hatası kullanıcıyı ASLA kilitlememeli.
//   - Sunucuya ulaşılamadı → kapı yok (önbellekteki son bilinen config kullanılır).
//   - Mevcut build numarası okunamadı (0/negatif) → kapı yok.
//   - Config alanı yok/bozuk → o eşik yok sayılır.
// Kapının amacı BİLİNEN eski sürümü durdurmak; şüphede kullanıcıdan yana karar.
// -----------------------------------------------------------------------------

/// Kapının kararı.
enum UpdateVerdict {
  /// Güncel — hiçbir şey gösterilmez.
  none,

  /// Yeni sürüm var ama zorunlu değil — kapatılabilir öneri gösterilir.
  suggest,

  /// Sürüm artık desteklenmiyor — uygulama engellenir, Play Store'a yönlendirilir.
  force,
}

/// Sunucudan (ya da önbellekten) okunan yapılandırma.
///
/// Alanlar bilerek nullable: eksik/bozuk alan "eşik tanımsız" demektir ve
/// o eşik değerlendirmede yok sayılır (fail-open).
class AppConfig {
  final int? minSupportedBuild;
  final int? latestBuild;

  /// Zorunlu güncelleme ekranında gösterilecek isteğe bağlı mesaj (EN/TR).
  /// Boşsa uygulamanın varsayılan metni kullanılır.
  final String? messageEn;
  final String? messageTr;

  const AppConfig({
    this.minSupportedBuild,
    this.latestBuild,
    this.messageEn,
    this.messageTr,
  });

  static const empty = AppConfig();

  /// Sunucu satırından / önbellek JSON'undan güvenli okuma.
  /// Sayı olmayan değerler null'a düşer — bozuk veri kapıyı asla ZORLAYAMAZ
  /// (cast İSTİSNASI bile fırlatılmaz; `is num` kontrolüyle okunur).
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    String? asText(Object? v) => v is String ? v : null;
    return AppConfig(
      minSupportedBuild: asInt(map['min_supported_build']),
      latestBuild: asInt(map['latest_build']),
      messageEn: asText(map['message_en']),
      messageTr: asText(map['message_tr']),
    );
  }

  Map<String, dynamic> toMap() => {
    'min_supported_build': minSupportedBuild,
    'latest_build': latestBuild,
    'message_en': messageEn,
    'message_tr': messageTr,
  };

  String toJson() => jsonEncode(toMap());

  /// Önbellekten okuma; bozuk JSON null döndürür (çökmek yok).
  static AppConfig? tryParse(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      return AppConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// [currentBuild] için kapı kararı.
///
/// [currentBuild] <= 0 "sürüm okunamadı" demektir → [UpdateVerdict.none]
/// (fail-open: kendi hatamız yüzünden kimseyi kilitlemeyiz).
UpdateVerdict evaluateUpdateVerdict({
  required int currentBuild,
  required AppConfig config,
}) {
  if (currentBuild <= 0) return UpdateVerdict.none;

  final min = config.minSupportedBuild;
  if (min != null && min > 0 && currentBuild < min) return UpdateVerdict.force;

  final latest = config.latestBuild;
  if (latest != null && currentBuild < latest) return UpdateVerdict.suggest;

  return UpdateVerdict.none;
}
