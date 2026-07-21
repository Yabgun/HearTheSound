import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/data_export.dart';
import 'package:hear_the_sound/core/merge_progress.dart';
import 'package:hear_the_sound/core/player_profile.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/core/schema_migration.dart';

// -----------------------------------------------------------------------------
// §19 PROFİL — model, kayıpsız birleştirme, v1→v2 göçü ve dışa aktarım.
// -----------------------------------------------------------------------------

void main() {
  group('PlayerProfile serileştirme', () {
    test('gidiş-dönüş tüm alanları korur', () {
      final profile = PlayerProfile(
        displayName: 'Buğra',
        avatarId: 'ocean',
        joinedAt: DateTime(2026, 3, 14, 10, 30),
      );
      final round = PlayerProfile.fromMap(profile.toMap());

      expect(round.displayName, 'Buğra');
      expect(round.avatarId, 'ocean');
      expect(round.joinedAt, profile.joinedAt);
    });

    test('boş profil boş map üretir (kayda çöp yazmayız)', () {
      expect(PlayerProfile.empty.toMap(), isEmpty);
    });

    test('bozuk tarih çökertmez', () {
      final p = PlayerProfile.fromMap({'joinedAt': 'tarih-degil'});
      expect(p.joinedAt, isNull);
    });

    test('hasDisplayName boşluk-only adı ad saymaz', () {
      expect(const PlayerProfile(displayName: '   ').hasDisplayName, isFalse);
      expect(const PlayerProfile(displayName: 'Eko').hasDisplayName, isTrue);
    });
  });

  group('mergeProfile', () {
    test('dolu olan kazanır, yerel (a) öncelikli', () {
      const local = PlayerProfile(displayName: 'Yerel', avatarId: 'forest');
      const remote = PlayerProfile(displayName: 'Uzak', avatarId: 'berry');

      expect(mergeProfile(local, remote).displayName, 'Yerel');
      expect(mergeProfile(local, remote).avatarId, 'forest');
      // Yerelde yoksa uzaktakini alır — hiçbir taraf boşa düşmez.
      expect(
        mergeProfile(PlayerProfile.empty, remote).displayName,
        'Uzak',
      );
    });

    test('joinedAt EN ERKEN olur — üyelik tarihi geri gitmez', () {
      final eski = PlayerProfile(joinedAt: DateTime(2026, 1, 5));
      final yeni = PlayerProfile(joinedAt: DateTime(2026, 6, 20));

      expect(mergeProfile(yeni, eski).joinedAt, DateTime(2026, 1, 5));
      expect(mergeProfile(eski, yeni).joinedAt, DateTime(2026, 1, 5));
    });

    test('ilerleme birleşmesi profili taşır', () {
      const a = PlayerProgress(
        xp: 10,
        profile: PlayerProfile(displayName: 'Buğra'),
      );
      const b = PlayerProgress(xp: 20, profile: PlayerProfile(avatarId: 'mono'));

      final merged = mergeProgress(a, b);
      expect(merged.profile.displayName, 'Buğra');
      expect(merged.profile.avatarId, 'mono');
      expect(merged.xp, 20, reason: 'diğer alanlar bozulmamalı');
    });
  });

  group('v1 → v2 göçü', () {
    test('şema sürümü 2 ve zincir kayıtlı', () {
      expect(kProgressSchemaVersion, 2);
      expect(kProgressMigrations.containsKey(1), isTrue);
    });

    test('profilsiz v1 kaydı boş profille açılır (kayıpsız)', () {
      // Gerçek bir v1 kaydı: damga yok, profile anahtarı yok.
      final v1 = <String, dynamic>{
        'xp': 500,
        'streak': 3,
        'completedLessons': ['first_notes', 'iv1'],
      };

      final loaded = PlayerProgress.fromMap(v1);

      expect(loaded.schemaVersion, 2, reason: 'v2\'ye taşınmalı');
      expect(loaded.profile.displayName, isNull);
      expect(loaded.profile.avatarId, isNull);
      // Eski alanlar aynen durmalı.
      expect(loaded.xp, 500);
      expect(loaded.streak, 3);
      expect(loaded.completedLessons, ['first_notes', 'iv1']);
    });

    test('v1 kaydında beklenmedik şekilde profil varsa SİLİNMEZ', () {
      // Göçler mevcut veriyi asla ezmemeli (spread sırası koruması).
      final v1 = <String, dynamic>{
        'xp': 1,
        'profile': {'displayName': 'Kaybolmamalı'},
      };

      final loaded = PlayerProgress.fromMap(v1);
      expect(loaded.profile.displayName, 'Kaybolmamalı');
    });

    test('göç idempotent — v2 kaydı tekrar göçünce değişmez', () {
      const original = PlayerProgress(
        xp: 42,
        profile: PlayerProfile(displayName: 'Eko', avatarId: 'sunset'),
      );
      final once = PlayerProgress.fromMap(original.toMap());
      final twice = PlayerProgress.fromMap(once.toMap());

      expect(twice.toMap(), equals(once.toMap()));
      expect(twice.profile.displayName, 'Eko');
    });

    test('v2 verisi ESKİ sürüm için "gelecek" sayılır', () {
      // v1 destekleyen bir uygulama v2 veriyi okusaydı: damga korunur →
      // CloudSync buluta yazmayı durdurur → profil silinmez.
      final map = const PlayerProgress(xp: 5).toMap();
      final asSeenByV1 = migrateProgressMap(map, targetVersion: 1);

      expect(asSeenByV1['schemaVersion'], 2);
    });
  });

  group('verimi indir', () {
    test('belge kimlik + sürüm + ilerleme taşır', () {
      const progress = PlayerProgress(
        xp: 320,
        profile: PlayerProfile(displayName: 'Buğra'),
      );
      final json = buildDataExport(
        progress: progress,
        email: 'kisi@ornek.com',
        exportedAt: DateTime.utc(2026, 7, 22, 9),
      );

      expect(json, contains('"app": "HearTheSound"'));
      expect(json, contains('"exportFormatVersion": $kExportFormatVersion'));
      expect(json, contains('"exportedAt": "2026-07-22T09:00:00.000Z"'));
      expect(json, contains('kisi@ornek.com'));
      expect(json, contains('"xp": 320'));
      expect(json, contains('Buğra'));
      // Girintili olmalı — kullanıcıya gösterilen belge, tek satır blob değil.
      expect(json.split('\n').length, greaterThan(5));
    });

    test('misafirde hesap bölümü hiç yazılmaz', () {
      final json = buildDataExport(
        progress: PlayerProgress.empty,
        exportedAt: DateTime.utc(2026, 7, 22),
      );
      expect(json, isNot(contains('account')));
    });

    test('dosya adı tarih damgalı ve güvenli', () {
      expect(
        dataExportFileName(DateTime.utc(2026, 7, 5)),
        'heartthesound-data-2026-07-05.json',
      );
    });
  });
}
