// -----------------------------------------------------------------------------
// ŞEMA SÜRÜMLEME — kayıtlı ilerlemenin ileriye dönük güvenli göçü
//
// Uygulama büyüdükçe PlayerProgress'in JSON şekli değişir. Sahadaki bir
// kullanıcının eski kaydı, yeni sürüm tarafından SESSİZCE bozulmamalıdır.
// Bu dosya bunu üç güvenceyle sağlar:
//
//   1. DAMGA        — her kayıt, yazıldığı şema sürümünü taşır ('schemaVersion').
//   2. ZİNCİR       — okurken v(n) -> v(n+1) dönüşümleri SIRAYLA uygulanır.
//   3. İLERİ KORUMA — veri bu uygulamadan YENİYSE (kullanıcının başka cihazı
//                     güncel, bu cihaz değil) damga olduğu gibi bırakılır;
//                     üst katman (CloudSync) o veriyi EZMEZ.
//
// Dönüşümler SAF'tır: girdiyi değiştirmez, yeni bir map döndürür. Böylece hem
// test edilebilir hem de idempotenttir (iki kez uygulamak = bir kez uygulamak).
//
// NOT: Bu dosya bilerek `player_progress.dart`'ı İMPORT ETMEZ — tamamen "map
// dünyasında" çalışır (döngüsel bağımlılık olmaz, saf kalır).
// -----------------------------------------------------------------------------

/// Bu uygulama sürümünün YAZDIĞI şema sürümü.
///
/// Şema değiştiğinde (alan eklendi / bir alanın anlamı değişti) bunu **bir**
/// artır ve [kProgressMigrations]'a v(eski) -> v(eski+1) dönüşümünü ekle.
/// `schema_migration_test.dart` zincirde boşluk kalmadığını doğrular.
const int kProgressSchemaVersion = 1;

/// Damgasız kayıtların varsayıldığı sürüm.
///
/// İlk yayına giren kullanıcıların kaydında 'schemaVersion' anahtarı yoktur;
/// o şekil tanım gereği v1'dir.
const int kUnstampedSchemaVersion = 1;

/// Tek adımlık şema dönüşümü: v(n) şeklindeki map -> v(n+1) şeklinde YENİ map.
typedef ProgressMigration =
    Map<String, dynamic> Function(Map<String, dynamic> map);

/// v(anahtar) -> v(anahtar + 1) dönüşüm tablosu.
///
/// Şu an **boş**: mevcut şekil ilk sürüm. Makine önceden kurulu olduğu için
/// ilk gerçek göç, yeniden tasarım değil tek girdilik bir ekleme olacak:
///
/// ```dart
/// const Map<int, ProgressMigration> kProgressMigrations = {1: _v1ToV2};
///
/// /// v2: profil alt-nesnesi eklendi (görünen ad, avatar, üyelik tarihi).
/// Map<String, dynamic> _v1ToV2(Map<String, dynamic> m) => {...m, 'profile': {}};
/// ```
const Map<int, ProgressMigration> kProgressMigrations = {};

/// [map]'in taşıdığı şema sürümü; damga yoksa ya da bozuksa
/// [kUnstampedSchemaVersion].
int readSchemaVersion(Map<String, dynamic> map) {
  final raw = map['schemaVersion'];
  if (raw is num) {
    final version = raw.toInt();
    if (version >= kUnstampedSchemaVersion) return version;
  }
  return kUnstampedSchemaVersion;
}

/// [raw] kaydını [targetVersion]'a taşır ve damgasını günceller.
///
/// - Veri hedeften ESKİYSE: zincirdeki dönüşümler sırayla uygulanır.
/// - Veri hedeften YENİYSE: dönüşümler tek yönlü olduğundan geri alınamaz.
///   Damga **olduğu gibi** bırakılır; okuyucu anladığı alanlarla en iyi çabayla
///   çalışır, üst katman ise damgadan veriyi ezmemesi gerektiğini anlar.
/// - Zincirde boşluk varsa (sürüm artırılmış ama dönüşüm eklenmemiş): sessizce
///   veri bozmaktansa olduğu yerde durulur.
///
/// [migrations] parametreli bırakıldı ki testler motoru gerçek üretim
/// tablosundan bağımsız (sahte bir zincirle) doğrulayabilsin.
Map<String, dynamic> migrateProgressMap(
  Map<String, dynamic> raw, {
  int targetVersion = kProgressSchemaVersion,
  Map<int, ProgressMigration> migrations = kProgressMigrations,
}) {
  var version = readSchemaVersion(raw);
  // Yüzeysel kopya: girdiyi asla değiştirmeyiz (saflık). Dönüşümlerin kendisi
  // de dokundukları İÇ İÇE map'leri kopyalamakla yükümlüdür.
  var map = Map<String, dynamic>.from(raw);

  while (version < targetVersion) {
    final step = migrations[version];
    if (step == null) break; // zincirde boşluk — dur, bozma
    map = step(map);
    version++;
  }

  map['schemaVersion'] = version;
  return map;
}
