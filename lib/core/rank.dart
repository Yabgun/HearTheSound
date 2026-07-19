import 'content_locale.dart';

/// RPG rütbe merdiveni — kullanıcının toplam XP'sine göre unvanı.
/// İçerik planındaki "Sağır Kulak → … → Mutlak Kulak" merdiveni.
/// Rütbe adları aktif içerik diline göre çözülür (i18n).
class Rank {
  final String name;
  final int minXp;
  const Rank(this.name, this.minXp);
}

List<Rank> get ranks => [
  Rank(t(en: 'Deaf Ear', tr: 'Sağır Kulak'), 0),
  Rank(t(en: 'Apprentice', tr: 'Çırak'), 100),
  Rank(t(en: 'Journeyman', tr: 'Kalfa'), 300),
  Rank(t(en: 'Master', tr: 'Usta'), 700),
  Rank(t(en: 'Virtuoso', tr: 'Virtüöz'), 1500),
  Rank(t(en: 'Absolute Ear', tr: 'Mutlak Kulak'), 3000),
];

/// Verilen XP'deki güncel rütbe.
Rank rankForXp(int xp) {
  var current = ranks.first;
  for (final r in ranks) {
    if (xp >= r.minXp) {
      current = r;
    } else {
      break;
    }
  }
  return current;
}

/// Bir sonraki rütbe (varsa) — ilerleme çubuğu için. Zirvede ise null.
Rank? nextRankAfter(int xp) {
  for (final r in ranks) {
    if (r.minXp > xp) return r;
  }
  return null;
}
