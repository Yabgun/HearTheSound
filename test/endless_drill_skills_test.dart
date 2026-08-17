import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/features/practice/endless_drill_page.dart';

// Sonsuz Pratik adaptörü: tamamlanmış dersleri DOĞRU karıştırma tipiyle
// çalıştırılabilir becerilere çevirir. Tip eşlemesi kritik — ağırlıklandırmanın
// (core/endless_drill.dart) karıştırma bonusu bu tipe göre eşleşir.

void main() {
  test('yalnızca tamamlanmış dersler, doğru karıştırma tipiyle gelir', () {
    final p = PlayerProgress(
      completedLessons: const ['first_notes', 'ch_color', 'mel3'],
    );
    final skills = buildDrillSkills(p, null);
    final byId = {for (final s in skills) s.id: s.type};

    // Tamamlananlar doğru tiple:
    expect(byId['first_notes'], 'note');
    expect(byId['ch_color'], 'color'); // akor rengi (algı)
    expect(byId['mel3'], 'melody'); // Eko oyunu (üretme)

    // Tamamlanmayanlar listede yok:
    expect(byId.containsKey('l2_cde'), isFalse);
    expect(byId.containsKey('ch_bright'), isFalse);
  });

  // Akorlar track'i 2026-08-17'de yeniden kuruldu: eski chord/quality/inv
  // ayrımı yerine RENK ALGISI ile AKORDA SES ÜRETME ayrımı var.
  test('akor tipleri ayrışır (renk algısı / ses üretme)', () {
    final p = PlayerProgress(
      completedLessons: const ['ch_color', 'ch_third', 'ch_build', 'ch_master'],
    );
    final byId = {
      for (final s in buildDrillSkills(p, null)) s.id: s.type,
    };
    expect(byId['ch_color'], 'color');
    expect(byId['ch_master'], 'color');
    expect(byId['ch_third'], 'chordNote'); // üçlüyü üret
    expect(byId['ch_build'], 'chordNote'); // akoru kur
  });

  test('hiç tamamlanmamışsa boş liste (drill edilecek beceri yok)', () {
    expect(buildDrillSkills(const PlayerProgress(), null), isEmpty);
  });
}
