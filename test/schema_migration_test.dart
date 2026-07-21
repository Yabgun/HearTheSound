import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/merge_progress.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/core/schema_migration.dart';
import 'package:hear_the_sound/core/spaced_repetition.dart';
import 'package:hear_the_sound/core/vocal_range.dart';

// -----------------------------------------------------------------------------
// ŞEMA SÜRÜMLEME — sahadaki kullanıcının kaydı güncellemede BOZULMAMALI.
//
// Bu dosya üç şeyi ayrı ayrı kilitler:
//   1. Damgasız (yayın öncesi) kayıt kayıpsız okunur ve damga kazanır.
//   2. Göç motoru: sıra, idempotanlık, zincir boşluğu, gelecek sürüm.
//   3. İleri-sürüm bayrağı merge'de yutulmaz (bulut ezmesini engelleyen sinyal).
// -----------------------------------------------------------------------------

void main() {
  // Her alanı DOLU bir ilerleme — göçün hiçbir şeyi düşürmediğini görebilmek
  // için kasıtlı olarak zengin.
  PlayerProgress richProgress() => PlayerProgress(
    xp: 1240,
    streak: 5,
    longestStreak: 11,
    lastActiveDay: '2026-07-20',
    dailyXp: 40,
    skillXp: const {'note:C': 30, 'quality:major': 12},
    skillLevel: const {'first_notes': 2},
    completedLessons: const ['first_notes', 'l2_cde', 'iv1'],
    vocalRange: VocalRange(
      comfortLow: 48,
      comfortHigh: 60,
      stretchLow: 45,
      stretchHigh: 64,
      calibratedAt: DateTime(2026, 7, 1),
    ),
    reviews: const {
      'iv1': ReviewState(
        ease: 2.5,
        intervalDays: 6,
        reps: 3,
        lapses: 1,
        dueDay: '2026-08-01',
        lastReviewedDay: '2026-07-19',
      ),
    },
    confusionCounts: const {'quality:major7>dominant7': 4},
    lastChallengeDay: '2026-07-20',
  );

  /// Yayın öncesi (damgasız) bir kaydın diskteki hali: güncel şekil, ama
  /// 'schemaVersion' anahtarı YOK. Elle JSON yazmak yerine gerçek serileştirmeden
  /// türetiyoruz ki test, şekil değişince kendiliğinden güncel kalsın.
  Map<String, dynamic> unstampedRecord() {
    final map = richProgress().toMap();
    map.remove('schemaVersion');
    return map;
  }

  group('damgasız (v1) kayıt', () {
    test('kayıpsız okunur — mevcut kullanıcıların verisi korunur', () {
      final loaded = PlayerProgress.fromMap(unstampedRecord());
      final original = richProgress();

      expect(loaded.xp, original.xp);
      expect(loaded.streak, original.streak);
      expect(loaded.longestStreak, original.longestStreak);
      expect(loaded.lastActiveDay, original.lastActiveDay);
      expect(loaded.dailyXp, original.dailyXp);
      expect(loaded.skillXp, original.skillXp);
      expect(loaded.skillLevel, original.skillLevel);
      expect(loaded.completedLessons, original.completedLessons);
      expect(loaded.vocalRange?.comfortLow, original.vocalRange?.comfortLow);
      expect(loaded.vocalRange?.calibratedAt, original.vocalRange?.calibratedAt);
      expect(loaded.reviews['iv1']?.reps, 3);
      expect(loaded.confusionCounts, original.confusionCounts);
      expect(loaded.lastChallengeDay, original.lastChallengeDay);
    });

    test('okunduğunda güncel sürümle damgalanır', () {
      final loaded = PlayerProgress.fromMap(unstampedRecord());
      expect(loaded.schemaVersion, kProgressSchemaVersion);
      expect(loaded.isFromFutureSchema, isFalse);
      // Bir sonraki kayıtta damga diske de yazılır.
      expect(loaded.toMap()['schemaVersion'], kProgressSchemaVersion);
    });

    test('bozuk damga (metin/negatif) v1 sayılır, çökmez', () {
      for (final bad in <dynamic>['abc', -3, 0, null]) {
        final map = unstampedRecord()..['schemaVersion'] = bad;
        expect(
          readSchemaVersion(map),
          kUnstampedSchemaVersion,
          reason: 'bozuk damga: $bad',
        );
        expect(PlayerProgress.fromMap(map).xp, 1240);
      }
    });
  });

  group('göç motoru', () {
    // Sahte zincir: üretim tablosu bugün boş olduğundan motoru kendi
    // dönüşümlerimizle sınarız (v1 -> v2 -> v3).
    final fakeChain = <int, ProgressMigration>{
      1: (m) => {...m, 'xp': (m['xp'] as int) + 1, 'addedInV2': true},
      2: (m) => {...m, 'xp': (m['xp'] as int) * 10, 'addedInV3': true},
    };

    test('dönüşümler SIRAYLA uygulanır', () {
      final out = migrateProgressMap(
        {'xp': 4},
        targetVersion: 3,
        migrations: fakeChain,
      );
      // Sıra önemli: (4+1)*10 = 50. Ters sırada 41 çıkardı.
      expect(out['xp'], 50);
      expect(out['addedInV2'], isTrue);
      expect(out['addedInV3'], isTrue);
      expect(out['schemaVersion'], 3);
    });

    test('ara sürümden devam eder — baştan başlamaz', () {
      final out = migrateProgressMap(
        {'xp': 4, 'schemaVersion': 2},
        targetVersion: 3,
        migrations: fakeChain,
      );
      expect(out['xp'], 40, reason: 'yalnızca v2->v3 uygulanmalı');
      expect(out.containsKey('addedInV2'), isFalse);
    });

    test('idempotent — iki kez göç, bir kez göçle aynı', () {
      final once = migrateProgressMap(
        {'xp': 4},
        targetVersion: 3,
        migrations: fakeChain,
      );
      final twice = migrateProgressMap(
        once,
        targetVersion: 3,
        migrations: fakeChain,
      );
      expect(twice, equals(once));
    });

    test('girdiyi DEĞİŞTİRMEZ (saflık)', () {
      final input = <String, dynamic>{'xp': 4};
      migrateProgressMap(input, targetVersion: 3, migrations: fakeChain);
      expect(input, equals({'xp': 4}), reason: 'çağıranın map\'i bozulmamalı');
    });

    test('zincirde boşluk varsa durur — veriyi bozmaz', () {
      final out = migrateProgressMap(
        {'xp': 4},
        targetVersion: 3,
        migrations: {2: fakeChain[2]!}, // v1->v2 EKSİK
      );
      expect(out['xp'], 4, reason: 'hiçbir dönüşüm uygulanmamalı');
      expect(out['schemaVersion'], 1, reason: 'damga olduğu yerde kalmalı');
    });

    test('gelecek sürüm geri alınmaz — damga korunur', () {
      final out = migrateProgressMap(
        {'xp': 4, 'schemaVersion': 99},
        targetVersion: 3,
        migrations: fakeChain,
      );
      expect(out['schemaVersion'], 99);
      expect(out['xp'], 4, reason: 'ileri veriye dokunulmaz');
    });
  });

  group('ileri-sürüm koruması', () {
    test('gelecek şemadan gelen kayıt işaretlenir', () {
      final map = unstampedRecord()
        ..['schemaVersion'] = kProgressSchemaVersion + 1;
      final loaded = PlayerProgress.fromMap(map);

      expect(loaded.isFromFutureSchema, isTrue);
      expect(loaded.schemaVersion, kProgressSchemaVersion + 1);
      // Anladığımız alanlarla yine de çalışırız (uygulama kilitlenmez).
      expect(loaded.xp, 1240);
      // Damga geri yazılırken düşürülmez — yalan söylemeyiz.
      expect(loaded.toMap()['schemaVersion'], kProgressSchemaVersion + 1);
    });

    test('merge bayrağı YUTMAZ — max sürüm kazanır', () {
      final future = richProgress().copyWith(
        schemaVersion: kProgressSchemaVersion + 1,
      );
      final current = richProgress();

      // Her iki sırada da: birleşim "gelecek" kalmalı, yoksa eski cihaz
      // buluttaki güncel veriyi ezerdi.
      expect(mergeProgress(current, future).isFromFutureSchema, isTrue);
      expect(mergeProgress(future, current).isFromFutureSchema, isTrue);
      expect(
        mergeProgress(current, current).schemaVersion,
        kProgressSchemaVersion,
      );
    });
  });

  group('üretim zinciri sözleşmesi', () {
    test('zincir boşluksuz — sürüm artırıldıysa dönüşüm de eklenmiş olmalı', () {
      for (var v = kUnstampedSchemaVersion; v < kProgressSchemaVersion; v++) {
        expect(
          kProgressMigrations.containsKey(v),
          isTrue,
          reason:
              'kProgressSchemaVersion=$kProgressSchemaVersion ama v$v -> v${v + 1} '
              'dönüşümü yok. schema_migration.dart\'a ekle.',
        );
      }
    });

    test('gidiş-dönüş: toMap -> fromMap tüm alanları korur', () {
      final original = richProgress();
      final round = PlayerProgress.fromMap(original.toMap());

      expect(round.toMap(), equals(original.toMap()));
    });
  });
}
