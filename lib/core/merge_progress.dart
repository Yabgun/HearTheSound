import 'player_profile.dart';
import 'player_progress.dart';
import 'spaced_repetition.dart';
import 'vocal_range.dart';

// -----------------------------------------------------------------------------
// İLERLEME BİRLEŞTİRME — yerel ↔ bulut senkronunun kalbi (saf, testli)
//
// İki cihaz (ya da yerel + bulut) aynı hesapta farklı ilerlemeler biriktirmiş
// olabilir. Kaba "son yazan kazanır" veri KAYBETTİRİR (bir cihazdaki dersler
// silinir). Bunun yerine alan-bazlı, kayıpsız birleştirme yaparız:
//
//   xp / longestStreak ................ max (emek asla kaybolmaz)
//   completedLessons .................. birleşim (kilitler asla geri kapanmaz)
//   skillXp / confusionCounts ......... anahtar başına max (çift saymayı önler)
//   streak / dailyXp / lastActiveDay .. daha YENİ gün hangi taraftaysa onunki
//   vocalRange ........................ daha yeni kalibrasyon
//   reviews ........................... beceri başına daha yeni tekrar durumu
//   profile ........................... dolu olan kazanır; joinedAt en erken
//   schemaVersion ..................... max (bkz. aşağıdaki not)
//
// Kural: merge(a, b) simetrik olmalı (merge(b, a) aynı sonucu verir) — testler
// bunu doğrular.
//
// ŞEMA SÜRÜMÜ NEDEN max: taraflardan biri bu uygulamadan YENİ bir şemadan
// geliyorsa, birleşim de "yeni" sayılmalıdır. Aksi halde merge, ileri-sürüm
// bayrağını yutar ve eski cihaz güncel cihazın verisini buluta geri yazarak
// bozar (bkz. PlayerProgress.isFromFutureSchema).
// -----------------------------------------------------------------------------

PlayerProgress mergeProgress(PlayerProgress a, PlayerProgress b) {
  // 'yyyy-mm-dd' anahtarları sözlük sırası = kronolojik sıra; null en eski.
  int compareDay(String? x, String? y) {
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return x.compareTo(y);
  }

  // Gün karşılaştırmasında yeni taraf; eşitlikte değeri BÜYÜK olan taraf
  // (aynı gün iki cihazda oynanmışsa daha çok ilerleyen kazanır).
  final dayCmp = compareDay(a.lastActiveDay, b.lastActiveDay);
  final PlayerProgress newer;
  if (dayCmp > 0) {
    newer = a;
  } else if (dayCmp < 0) {
    newer = b;
  } else {
    newer = a.dailyXp >= b.dailyXp ? a : b;
  }

  // skillXp: anahtar başına max.
  final skillXp = Map<String, int>.from(a.skillXp);
  b.skillXp.forEach((k, v) {
    skillXp[k] = v > (skillXp[k] ?? 0) ? v : skillXp[k]!;
  });

  // skillLevel: anahtar başına max (taç/ustalık seviyesi geri düşmez).
  final skillLevel = Map<String, int>.from(a.skillLevel);
  b.skillLevel.forEach((k, v) {
    skillLevel[k] = v > (skillLevel[k] ?? 0) ? v : skillLevel[k]!;
  });

  // confusionCounts: anahtar başına max (ortak geçmişi çift saymamak için
  // toplama DEĞİL max — iki cihaz da aynı geçmişten türedi).
  final confusions = Map<String, int>.from(a.confusionCounts);
  b.confusionCounts.forEach((k, v) {
    final existing = confusions[k];
    confusions[k] = existing == null || v > existing ? v : existing;
  });

  // completedLessons: sıra korunarak birleşim.
  final completed = List<String>.from(a.completedLessons);
  for (final id in b.completedLessons) {
    if (!completed.contains(id)) completed.add(id);
  }

  // reviews: beceri başına daha yeni lastReviewedDay; eşitlikte reps büyük olan.
  final reviews = Map<String, ReviewState>.from(a.reviews);
  b.reviews.forEach((skill, rb) {
    final ra = reviews[skill];
    if (ra == null) {
      reviews[skill] = rb;
      return;
    }
    final cmp = ra.lastReviewedDay.compareTo(rb.lastReviewedDay);
    if (cmp < 0 || (cmp == 0 && rb.reps > ra.reps)) {
      reviews[skill] = rb;
    }
  });

  // vocalRange: daha yeni kalibrasyon (tarihi olmayan en eski sayılır).
  VocalRange? range;
  final ra = a.vocalRange;
  final rb = b.vocalRange;
  if (ra == null) {
    range = rb;
  } else if (rb == null) {
    range = ra;
  } else {
    final ta = ra.calibratedAt;
    final tb = rb.calibratedAt;
    if (ta == null) {
      range = rb;
    } else if (tb == null) {
      range = ra;
    } else {
      range = tb.isAfter(ta) ? rb : ra;
    }
  }

  return PlayerProgress(
    xp: a.xp > b.xp ? a.xp : b.xp,
    streak: newer.streak,
    longestStreak: a.longestStreak > b.longestStreak
        ? a.longestStreak
        : b.longestStreak,
    lastActiveDay: newer.lastActiveDay,
    dailyXp: newer.dailyXp,
    skillXp: skillXp,
    skillLevel: skillLevel,
    completedLessons: completed,
    vocalRange: range,
    reviews: reviews,
    confusionCounts: confusions,
    // Günün meydan okuması: daha yeni gün hangi taraftaysa onunki.
    lastChallengeDay: compareDay(a.lastChallengeDay, b.lastChallengeDay) >= 0
        ? a.lastChallengeDay
        : b.lastChallengeDay,
    // Profil: dolu olan kazanır, üyelik tarihi en erken (bkz. mergeProfile).
    profile: mergeProfile(a.profile, b.profile),
    schemaVersion: a.schemaVersion > b.schemaVersion
        ? a.schemaVersion
        : b.schemaVersion,
  );
}
