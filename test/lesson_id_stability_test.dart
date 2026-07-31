import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/features/home/curriculum.dart';

// -----------------------------------------------------------------------------
// DERS-ID KARARLILIĞI — kullanıcı ilerlemesinin sessizce silinmesine karşı bariyer
//
// `PlayerProgress.completedLessons`, `skillLevel` ve kilit zinciri ham ders
// id'lerine göre çalışır. Yayına çıkmış bir id değişirse, o dersi bitirmiş
// kullanıcı için ders yeniden KİLİTLİ görünür — sessiz ilerleme kaybı.
//
// KURAL (PROJECT.md §17):
//   • Yeni id EKLE ............... ✔ serbest (bu test yeni id'lere izin verir)
//   • Başlık/içerik DEĞİŞTİR ..... ✔ serbest (id'ye dokunmadığı sürece)
//   • Id'yi YENİDEN ADLANDIR ..... ⚠ göç haritası gerekir (schema_migration.dart)
//   • Id'yi YENİDEN KULLAN ....... ✘ ASLA (eski ilerleme yanlış derse yapışır)
//
// Bu test yayınlanmış id'leri DONDURUR. Kırmızı yanarsa: id'yi geri al ya da
// bilinçli olarak bir göç yaz ve aşağıdaki listeyi güncelle.
// -----------------------------------------------------------------------------

/// Dondurulan ders id'leri. Bu listeden SİLME. Yeni ders eklerken buraya da
/// eklemek zorunlu değil — test yalnızca kaybolan/yeniden adlandırılan id'yi
/// yakalar.
///
/// 2026-07-27 GÜNCELLEMESİ: "Diziler & Tonalite", "Akor İşlevi", "İlerlemeler"
/// ve "Tonalite Yolculuğu" track'leri müfredattan KALDIRILDI (tn*/fn*/pr* ve
/// fn_j_*/pr_j_* id'leri bu yüzden listeden çıkarıldı). Bu, kuralın ihlali
/// değil bilinçli bir istisnadır: uygulama HENÜZ YAYINLANMADI (Play Store
/// adımı bekliyor) ve üretimdeki ilerleme tablosu boş. Yayından SONRA aynı
/// hamle ilerleme kaybı demek olurdu — o yüzden bu pencere kapanmadan yapıldı.
const Set<String> kShippedLessonIds = {
  // Notalar
  'first_notes', 'l2_cde', 'l3_penta', 'l4_diatonic', 'l5_chromatic',
  // Aralıklar
  'iv1', 'iv2', 'iv3', 'iv4', 'iv5', 'iv6',
  // Akorlar
  'ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'ch6',
  'ch7', 'ch8', 'ch9', 'ch10', 'ch11', 'ch12',
  'ch_quality_master',
  // Melodi Kulağı (Eko oyunu)
  'mel1', 'mel2', 'mel3', 'mel4', 'mel5', 'mel6', 'mel7', 'mel8',
};

List<String> curriculumLessonIds() => [
  for (final track in curriculum)
    for (final item in track.items) item.id,
];

void main() {
  // Testler dili değiştirdiğinden, sonraki testleri etkilememek için geri al.
  tearDown(() => ContentLocale.code = 'en');

  test('yayınlanmış hiçbir ders id\'si kaybolmadı', () {
    final current = curriculumLessonIds().toSet();
    final missing = kShippedLessonIds.difference(current);

    expect(
      missing,
      isEmpty,
      reason:
          'Bu id\'ler müfredattan kayboldu: $missing\n'
          'Yayına çıkmış bir id silinemez/yeniden adlandırılamaz — o dersi '
          'bitirmiş kullanıcılar ilerlemesini kaybeder. Geri al ya da '
          'schema_migration.dart\'a id göç haritası yaz.',
    );
  });

  test('müfredatta yinelenen id yok', () {
    final ids = curriculumLessonIds();
    final duplicates = <String>{};
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) duplicates.add(id);
    }

    expect(
      duplicates,
      isEmpty,
      reason:
          'Yinelenen ders id\'si: $duplicates — ilerleme yanlış derse yapışır.',
    );
  });

  test('id\'ler dilden BAĞIMSIZ — dil değişince ilerleme kopmaz', () {
    ContentLocale.code = 'en';
    final english = curriculumLessonIds();
    ContentLocale.code = 'tr';
    final turkish = curriculumLessonIds();

    expect(
      turkish,
      equals(english),
      reason:
          'Ders id\'leri çevrilmiş metinden türetilmiş olabilir. Kullanıcı dili '
          'değiştirince tamamladığı dersler kilitli görünür.',
    );
  });
}
