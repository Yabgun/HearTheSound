import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/state/progress_controller.dart';
import 'package:hear_the_sound/core/echo.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_arpeggio_page.dart';
import 'package:hear_the_sound/features/chords/chord_inversion_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_lesson.dart';
import 'package:hear_the_sound/features/chords/chord_quality_recognition_page.dart';
import 'package:hear_the_sound/features/chords/chord_recognition_page.dart';
import 'package:hear_the_sound/features/harmony/harmony_choice_page.dart';
import 'package:hear_the_sound/features/harmony/harmony_find_page.dart';
import 'package:hear_the_sound/features/harmony/harmony_lesson.dart';
import 'package:hear_the_sound/features/harmony/harmony_pattern_page.dart';
import 'package:hear_the_sound/features/melody/echo_game_page.dart';
import 'package:hear_the_sound/features/melody/melody_lesson.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_echo_page.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_lesson.dart';
import 'package:hear_the_sound/features/rhythm/rhythm_timeline.dart';
import 'package:hear_the_sound/features/mascot/player_eko.dart';

// Ses eklentisi çağırmayan sahte oynatıcı — testte plugin hatası olmasın.
class _FakePlayer implements NotePlayer {
  @override
  Future<void> play(Note note) async {}
  @override
  Future<void> playChord(List<Note> notes) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

ChordLesson _chordLesson(String id) =>
    chordLessons.firstWhere((l) => l.id == id);

HarmonyLesson _harmonyLesson(String id) =>
    harmonyLessons.firstWhere((l) => l.id == id);


// Ritim ekranı kullanıcının Eko rengini gösterdiği için (PlayerEko) ProviderScope
// gerekiyor; bellek-içi sahte repo ile besliyoruz (SharedPreferences'e girmeden).
class _FakeRepo implements ProgressRepository {
  PlayerProgress _p = PlayerProgress.empty;
  @override
  PlayerProgress load() => _p;
  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}

/// Sayfayı ProviderScope + MaterialApp ile sarmalar.
Widget _wrap(Widget page) => ProviderScope(
  overrides: [progressRepositoryProvider.overrideWithValue(_FakeRepo())],
  child: MaterialApp(home: page),
);

void main() {
  final fake = _FakePlayer();

  // İlk çizimde exception fırlamadığını doğrular; sonra ses-gecikmesi
  // zamanlayıcılarını boşaltır (pending-timer teardown hatası olmasın).
  // Yüzey uzun bir telefon boyutuna ayarlanır — varsayılan 800×600 test
  // penceresi kısa olduğundan gerçekçi olmayan layout taşmaları vermesin.
  Future<void> smoke(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(page));
    expect(tester.takeException(), isNull, reason: 'ilk çizimde hata olmamalı');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(tester.takeException(), isNull);
  }

  // Cihazdaki sistem çubuklarıyla kısalan ekranda, cevap geri bildirimi
  // açıldıktan sonra da tanıma ekranlarının taşmamasını korur. (Cihazda
  // görülen 3px "Sonraki" taşmalarının nöbetçisi.)
  Future<void> compactAnsweredSmoke(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(page));
    await tester.pump();
    final firstOption = find.byType(InkWell).first;
    await tester.ensureVisible(firstOption);
    await tester.tap(firstOption);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.takeException(),
      isNull,
      reason: 'cevap sonrası taşma olmamalı',
    );
    // Ses-gecikmesi zamanlayıcılarını boşalt: müzikal CÜMLE çalan sayfalarda
    // (tek nota değil) çalma birkaç saniye sürer → 1 sn yetmez, teardown
    // "pending timer" hatası verir.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('A1/A4 nitelik tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordQualityRecognitionPage(
        pool: _chordLesson('ch5').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('A3 çevrim tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordInversionRecognitionPage(
        pool: _chordLesson('ch9').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  // NOT: Aralık ekranlarının smoke testleri kaldırıldı — "Aralıklar" track'i
  // dağıtıldı (melodik kısım Melodi Kulağı'nda, harmonik kısım Armoni
  // Kulağı'na taşınacak).

  testWidgets('A8 yeni kök akor tanıma çizilir', (t) async {
    await smoke(
      t,
      ChordRecognitionPage(
        pool: _chordLesson('ch11').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('akor arpej çizilir', (t) async {
    await smoke(
      t,
      ChordArpeggioPage(
        chords: _chordLesson('ch5').pool.take(2).toList(),
        player: fake,
        onComplete: () {},
        title: 'Arpej',
      ),
    );
  });

  // Akor tanıma ekranları kısa yükseklikte cevap sonrası taşmamalı — cihazda
  // görülen 3px taşmaların ve uzun nitelik etiketlerinin nöbetçisi.
  testWidgets('akor tanıma ekranları kısa ekranda taşmaz', (t) async {
    await compactAnsweredSmoke(
      t,
      ChordRecognitionPage(
        pool: _chordLesson('ch11').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
    await compactAnsweredSmoke(
      t,
      ChordQualityRecognitionPage(
        pool: _chordLesson('ch_quality_master').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
    await compactAnsweredSmoke(
      t,
      ChordInversionRecognitionPage(
        pool: _chordLesson('ch9').pool,
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  // EKO OYUNU — yeni yetenek track'inin çekirdek ekranı (etiketleme değil,
  // duyduğunu TEKRARLAMA). İki cevap modu da ilk çizimde güvenli olmalı.
  testWidgets('Eko oyunu tuş modunda çizilir (ilk ve son ders)', (t) async {
    for (final lesson in [melodyLessons.first, melodyLessons.last]) {
      await smoke(
        t,
        EchoGamePage(
          lesson: lesson,
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      );
    }
  });

  testWidgets('Eko oyunu söyleme modunda çizilir', (t) async {
    await smoke(
      t,
      EchoGamePage(
        lesson: melodyLessons.first,
        player: fake,
        mode: EchoInputMode.sing,
        onModeChanged: (_) {},
        onComplete: (_) {},
      ),
    );
  });

  testWidgets('Eko oyunu kısa ekranda cevap sonrası taşmaz', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _wrap(
        EchoGamePage(
          lesson: melodyLessons.first, // 2 notalık ezgi
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      ),
    );
    // Ev sesi + ezgi çalınsın, cevap aşamasına geçilsin.
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    // İki notayı da gir → sonuç alanı (en taşma riskli hâl) açılır.
    for (var i = 0; i < 2; i++) {
      final pad = find.byType(InkWell).first;
      await t.ensureVisible(pad);
      await t.tap(pad);
      await t.pump(const Duration(milliseconds: 400));
    }
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(
      t.takeException(),
      isNull,
      reason: 'cevap sonrası taşma olmamalı',
    );
  });

  // Cihaz geri bildirimi: oktavsız tuş yazımı hangi sesin daha pes olduğunu
  // söylemiyordu ("F akoru C'den kalın çıkıyor"). Bu test yazımın sessizce
  // oktavsıza dönmesini engeller.
  testWidgets('bas tuşları ve akor taşları oktavı gösterir', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 960));
    addTearDown(() => t.binding.setSurfaceSize(null));

    // Bası Bul: ev sabit (C4) → tuşlar C4/F4/G4/A4.
    await t.pumpWidget(
      _wrap(
        HarmonyFindPage(
          lesson: _harmonyLesson('har4'),
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          questionCount: 4,
          onComplete: (_) {},
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(find.text('C4'), findsOneWidget);
    expect(find.text('C'), findsNothing, reason: 'oktavsız tuş kalmamalı');

    // Eko Oyunu aynı dili konuşmalı: mel8'de üst oktav toniği var, oktavsız
    // yazımda İKİ TANE "C" tuşu görünüyordu (biri doğru, biri yanlış).
    await t.pumpWidget(
      _wrap(
        EchoGamePage(
          lesson: melodyLessons.last,
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          onComplete: (_) {},
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(find.text('C'), findsNothing);
    final padLabels = t
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .where((l) => RegExp(r'^[A-G]#?\d$').hasMatch(l))
        .toList();
    // Boş liste testi sessizce yeşil yakardı — tuşların gerçekten bulunduğunu
    // önce doğrula (mel8 havuzu 8 derece).
    expect(padLabels.length, 8, reason: 'tuşlar bulunamadı: $padLabels');
    expect(
      padLabels.length,
      padLabels.toSet().length,
      reason: 'iki tuş aynı etiketi taşımamalı: $padLabels',
    );
  });

  // ARMONİ KULAĞI — üç oyun ekranı (algı / bas bulma / kalıp dizme).
  testWidgets('armoni algı ekranı üç soru tipinde de çizilir', (t) async {
    for (final id in ['har1', 'har2', 'har3']) {
      await smoke(
        t,
        HarmonyChoicePage(
          lesson: _harmonyLesson(id),
          player: fake,
          questionCount: 4,
          onComplete: (_) {},
        ),
      );
    }
  });

  testWidgets('armoni bas bulma ekranı çizilir (tuş + söyleme)', (t) async {
    for (final id in ['har4', 'har_bassline']) {
      await smoke(
        t,
        HarmonyFindPage(
          lesson: _harmonyLesson(id),
          player: fake,
          mode: EchoInputMode.tap,
          onModeChanged: (_) {},
          questionCount: 4,
          onComplete: (_) {},
        ),
      );
    }
    await smoke(
      t,
      HarmonyFindPage(
        lesson: _harmonyLesson('har4'),
        player: fake,
        mode: EchoInputMode.sing,
        onModeChanged: (_) {},
        questionCount: 4,
        onComplete: (_) {},
      ),
    );
  });

  // İki akorluk hafif hâlden en kalabalık palete (tuzaklı) kadar.
  testWidgets('armoni kalıp ekranı üç zorlukta da çizilir', (t) async {
    for (final id in ['har_two_chords', 'har8', 'har_decoys']) {
      await smoke(
        t,
        HarmonyPatternPage(
          lesson: _harmonyLesson(id),
          player: fake,
          questionCount: 4,
          onComplete: (_) {},
        ),
      );
    }
  });

  // Kısa ekranda CEVAP SONRASI hâl en taşma riskli andır (sonuç alanı açılır).
  // Cevap verebilmek için önce cümlenin çalması beklenmeli — çalarken şıklar
  // kapalıdır, erken dokunuş sessizce yutulur ve test yalancı yeşil yanardı.
  testWidgets('armoni ekranları kısa ekranda cevap sonrası taşmaz', (t) async {
    Future<void> tapAt(Finder finder) async {
      await t.ensureVisible(finder);
      await t.tap(finder);
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> answeredSmoke(
      Widget page,
      Future<void> Function() answer,
    ) async {
      await t.binding.setSurfaceSize(const Size(420, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(page));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 800));
      }
      await answer();
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 800));
      }
      // Cevap gerçekten VERİLDİ mi? Dokunuşlar yutulmuşsa sayfa hâlâ cevap
      // bekliyor olurdu ve test yalancı yeşil yanardı.
      expect(
        find.text('Next'),
        findsOneWidget,
        reason: 'cevap sonrası sonuç alanı açılmalı',
      );
      expect(
        t.takeException(),
        isNull,
        reason: 'cevap sonrası taşma olmamalı',
      );
    }

    // En uzun şık metni: "aynı kaldı / değişti".
    await answeredSmoke(
      HarmonyChoicePage(
        lesson: _harmonyLesson('har2'),
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
      () => tapAt(find.byType(InkWell).first),
    );
    // Bas hattı: üç tuşa bas, sonra "Hattım bu" ile onayla (en kalabalık hâl).
    await answeredSmoke(
      HarmonyFindPage(
        lesson: _harmonyLesson('har_bassline'),
        player: fake,
        mode: EchoInputMode.tap,
        onModeChanged: (_) {},
        questionCount: 4,
        onComplete: (_) {},
      ),
      () async {
        for (var i = 0; i < 3; i++) {
          await tapAt(find.byType(InkWell).first);
        }
        await tapAt(find.widgetWithText(FilledButton, "That's it"));
      },
    );
    // Tuzaklı kalıp: en kalabalık palet + dört yuva dolunca değerlendirilir.
    await answeredSmoke(
      HarmonyPatternPage(
        lesson: _harmonyLesson('har_decoys'),
        player: fake,
        questionCount: 4,
        onComplete: (_) {},
      ),
      () async {
        for (var i = 0; i < 4; i++) {
          await tapAt(find.byType(InkWell).first);
        }
      },
    );
  });

  // RİTİM KULAĞI — dokunarak tekrar (perde yok). En basit ve en yoğun ders.
  testWidgets('ritim eko oyunu çizilir (ilk ve son ders)', (t) async {
    for (final lesson in [rhythmLessons.first, rhythmLessons.last]) {
      await smoke(
        t,
        RhythmEchoPage(
          lesson: lesson,
          player: fake,
          questionCount: 4,
          onComplete: (_) {},
        ),
      );
      // Dersin görsel kalbi ve maskotu yerinde mi? İkisi de cihaz geri
      // bildirimiyle ("UI fazla sade kalmış") eklendi; sessizce kaybolmasınlar.
      expect(find.byType(RhythmTimeline), findsOneWidget);
      expect(find.byType(PlayerEko), findsOneWidget);
    }
  });

  testWidgets('ritim: vurunca sonuç açılır, kısa ekranda taşmaz', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final lesson = rhythmLessons.first; // 2 vuruşluk kalıp
    await t.pumpWidget(
      _wrap(
        RhythmEchoPage(
          lesson: lesson,
          player: fake,
          questionCount: 4,
          onComplete: (_) {},
        ),
      ),
    );
    // Kalıp çalsın, cevap aşamasına geçilsin.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    // Vuruş alanına kalıptaki ses sayısı kadar dokun → değerlendirme açılır.
    // (Semantik etiket yerine görünen metin: bySemanticsLabel için semantik
    // ağacının açık olması gerekir, smoke testinde gereksiz yük.)
    final pad = find.text('TAP');
    expect(pad, findsOneWidget, reason: 'kalıp bitince vuruş alanı açılmalı');
    for (var i = 0; i < lesson.shape.onsetCount; i++) {
      await t.tap(pad);
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(
      find.text('Next'),
      findsOneWidget,
      reason: 'tüm vuruşlar girilince sonuç alanı açılmalı',
    );
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(t.takeException(), isNull, reason: 'cevap sonrası taşma olmamalı');
  });
}
