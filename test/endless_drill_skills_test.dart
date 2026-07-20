import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/features/practice/endless_drill_page.dart';

// Sonsuz Pratik adaptörü: tamamlanmış dersleri DOĞRU karıştırma tipiyle
// çalıştırılabilir becerilere çevirir. Tip eşlemesi kritik — ağırlıklandırmanın
// (core/endless_drill.dart) karıştırma bonusu bu tipe göre eşleşir.

void main() {
  test('yalnızca tamamlanmış dersler, doğru karıştırma tipiyle gelir', () {
    final p = PlayerProgress(
      completedLessons: const ['first_notes', 'ch5', 'iv1'],
    );
    final skills = buildDrillSkills(p, null);
    final byId = {for (final s in skills) s.id: s.type};

    // Tamamlananlar doğru tiple:
    expect(byId['first_notes'], 'note');
    expect(byId['ch5'], 'quality'); // ch5 = nitelik (renk) tanıma
    expect(byId['iv1'], 'interval');

    // Tamamlanmayanlar listede yok:
    expect(byId.containsKey('l2_cde'), isFalse);
    expect(byId.containsKey('ch1'), isFalse);
  });

  test('akor tanıma tipleri ayrışır (chord / quality / inv)', () {
    final p = PlayerProgress(
      completedLessons: const ['ch1', 'ch5', 'ch9'],
    );
    final byId = {
      for (final s in buildDrillSkills(p, null)) s.id: s.type,
    };
    expect(byId['ch1'], 'chord'); // spesifik akor
    expect(byId['ch5'], 'quality'); // nitelik
    expect(byId['ch9'], 'inv'); // çevrim
  });

  test('hiç tamamlanmamışsa boş liste (drill edilecek beceri yok)', () {
    expect(buildDrillSkills(const PlayerProgress(), null), isEmpty);
  });
}
