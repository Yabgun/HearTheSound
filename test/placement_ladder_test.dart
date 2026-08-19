import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/harmony/harmony_lesson.dart';
import 'package:hear_the_sound/features/home/curriculum.dart';
import 'package:hear_the_sound/features/lesson/lesson.dart';
import 'package:hear_the_sound/features/melody/melody_lesson.dart';
import 'package:hear_the_sound/features/placement/placement_ladder.dart';
import 'package:hear_the_sound/features/placement/placement_test_page.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_lesson.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// MERDİVEN TESTİ (seviye tespiti)
//
// Eski yerleştirme testinin hatası bir KAPSAM hatasıydı: beş track'in yalnızca
// ikisini yokluyordu, sessizce. Buradaki nöbetçilerin ilk işi o hatanın bir daha
// olmasını engellemek — merdiven her track'i kapsamalı ve her basamağın gerçek
// bir oyun ekranı olmalı.
// -----------------------------------------------------------------------------

class _FakeRepo implements ProgressRepository {
  PlayerProgress _p = PlayerProgress.empty;
  @override
  PlayerProgress load() => _p;
  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}

void main() {
  tearDown(() => ContentLocale.code = 'en');

  group('merdiven basamakları', () {
    test('her track\'in tam olarak bir basamağı var (KAPSAM nöbetçisi)', () {
      // Eski testin kırılma noktası: beş track, iki basamak. Bu satır o hatayı
      // bir daha sessiz bırakmaz.
      expect(placementRungIds.length, curriculum.length);
      expect(placementRungIds.toSet().length, placementRungIds.length);
    });

    test('basamaklar beklenen en zor dersler', () {
      expect(placementRungIds, [
        'l5_chromatic',
        'mel8',
        'ch_master',
        'har_decoys',
        'rhy7',
      ]);
    });

    test('her basamak kendi track\'inin SON dersi', () {
      for (var i = 0; i < curriculum.length; i++) {
        expect(placementRungIds[i], curriculum[i].items.last.id);
      }
    });

    test('her basamağın oyun ekranı kurulabilir bir derse çözülür', () {
      // Bir track eklenip oyun ekranı bağlanmazsa test ekranı boşa düşerdi.
      for (final id in placementRungIds) {
        final found =
            lessons.any((l) => l.id == id) ||
            melodyLessons.any((l) => l.id == id) ||
            chordLessons.any((l) => l.id == id) ||
            harmonyLessons.any((l) => l.id == id) ||
            rhythmLessons.any((l) => l.id == id);
        expect(found, isTrue, reason: '$id hiçbir ders ailesinde yok');
      }
    });

    test('basamak listesi dilden bağımsız', () {
      ContentLocale.code = 'en';
      final en = placementRungIds;
      ContentLocale.code = 'tr';
      expect(placementRungIds, en);
    });
  });

  group('geçilen basamak → açılan dersler', () {
    test('hiç geçemeyen hiçbir ders açmaz', () {
      expect(placementUnlocks(0), isEmpty);
    });

    test('n basamak geçen ilk n track\'i açar', () {
      for (var n = 1; n < curriculum.length; n++) {
        final ids = placementUnlocks(n);
        for (var i = 0; i < n; i++) {
          for (final item in curriculum[i].items) {
            expect(ids, contains(item.id), reason: 'track $i · ${item.id}');
          }
        }
        // Geçilmemiş track'ten hiçbir şey açılmamalı.
        for (final item in curriculum[n].items) {
          expect(ids, isNot(contains(item.id)));
        }
      }
    });

    test('HEPSİNİ geçen bile oynayacak bir ders bulur (son ders kuralı)', () {
      final ids = placementUnlocks(curriculum.length);
      final all = lessonIdsInFirstTracks(curriculum.length);
      expect(ids.length, all.length - 1);

      // Asıl sözleşme: uygulamada açık bir sonraki ders KALMALI. Aksi hâlde
      // kullanıcı boş bir yol haritasıyla karşılanırdı.
      final progress = PlayerProgress.empty.copyWith(completedLessons: ids);
      expect(nextLesson(progress), isNotNull);
      expect(nextLesson(progress)!.item.id, placementRungIds.last);
    });

    test('kısmi geçişte de sıradaki ders doğru track\'te', () {
      final progress = PlayerProgress.empty.copyWith(
        completedLessons: placementUnlocks(2),
      );
      expect(nextLesson(progress)!.track.name, curriculum[2].name);
    });
  });

  group('test ekranı', () {
    Future<ProviderContainer> pump(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          progressRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlacementTestPage()),
        ),
      );
      await t.pump();
      return container;
    }

    testWidgets('açılışta merdiven görünür — beş bölüm de listelenir', (t) async {
      await pump(t);
      expect(t.takeException(), isNull);
      for (final track in curriculum) {
        expect(find.text(track.name), findsWidgets, reason: track.name);
      }
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('"sıfırdan başla" hiçbir ders açmaz', (t) async {
      final container = await pump(t);
      await t.tap(find.text('Start from scratch instead'));
      await t.pumpAndSettle();
      expect(container.read(progressProvider).completedLessons, isEmpty);
    });

    testWidgets('ilk basamak gerçek ders ekranını açar', (t) async {
      await pump(t);
      await t.tap(find.text('Start'));
      await t.pump();
      // Notalar basamağı = nota tanıma ekranı; "Soru 1 / 3" başlığı testin
      // üç soru sorduğunu da doğrular.
      expect(find.text('Question 1 / 3'), findsOneWidget);
      // Ses zamanlayıcılarını boşalt (teardown "pending timer" vermesin).
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 800));
      }
    });

    testWidgets('1.3x metin ölçeğinde merdiven taşmaz', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            progressRepositoryProvider.overrideWithValue(_FakeRepo()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const PlacementTestPage(),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull, reason: '1.3x merdiven taşmamalı');
    });
  });
}
