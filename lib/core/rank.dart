/// RPG rütbe merdiveni — kullanıcının toplam XP'sine göre unvanı.
/// İçerik planındaki "Sağır Kulak → … → Mutlak Kulak" merdiveni.
class Rank {
  final String name;
  final int minXp;
  const Rank(this.name, this.minXp);
}

const List<Rank> ranks = [
  Rank('Sağır Kulak', 0),
  Rank('Çırak', 100),
  Rank('Kalfa', 300),
  Rank('Usta', 700),
  Rank('Virtüöz', 1500),
  Rank('Mutlak Kulak', 3000),
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
