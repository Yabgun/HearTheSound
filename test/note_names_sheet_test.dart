import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/content_locale.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/ui/note_names_sheet.dart';

// -----------------------------------------------------------------------------
// NOTA ADLARI BAŞVURU KARTI (C = Do)
//
// İki ayrı şeyi kilitler:
//  1) SÖZLEŞME (saf veri) — yedi doğal notanın hepsi var, sırası doğru,
//     karşılıklar benzersiz. Bir kopyala-yapıştır hatası ("Fa" iki kez) sessiz
//     kalırsa kart YANLIŞ bilgi öğretir; en pahalı hata türü budur.
//  2) EKRAN — ℹ️ düğmesi kartı açar, kart iki dilde de doğru okur.
// -----------------------------------------------------------------------------

void main() {
  tearDown(() => ContentLocale.code = 'en');

  group('sözleşme: harf ↔ solfej köprüsü', () {
    test('yedi doğal nota, C\'den B\'ye doğru sırayla', () {
      expect(
        noteNameBridge.map((e) => e.letter).toList(),
        ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
      );
    });

    test('her harf gerçek bir nota adı (çekirdekle tutarlı)', () {
      for (final (:letter, solfege: _) in noteNameBridge) {
        expect(
          noteNames.contains(letter),
          isTrue,
          reason: '$letter, noteNames kataloğunda yok',
        );
      }
    });

    test('solfej adları benzersiz (kopyala-yapıştır nöbetçisi)', () {
      final solfege = noteNameBridge.map((e) => e.solfege).toList();
      expect(solfege.toSet().length, solfege.length);
      // Do-Re-Mi'nin kendisi: kartın vaat ettiği bilgi bu.
      expect(solfege, ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si']);
    });
  });

  group('kart ekranı', () {
    // ℹ️ düğmesini taşıyan minik bir ev sahibi — gerçek oyun ekranlarının
    // AppBar'ında olduğu gibi.
    Widget host({double textScale = 1.0}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Test'),
          actions: const [NoteNamesButton()],
        ),
      ),
    );

    testWidgets('ℹ️ düğmesi kartı açar ve yedi eşleşmeyi gösterir', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(host());

      await t.tap(find.byType(NoteNamesButton));
      await t.pumpAndSettle();

      expect(find.text('Note names'), findsOneWidget);
      for (final (:letter, :solfege) in noteNameBridge) {
        expect(find.text(letter), findsOneWidget, reason: '$letter satırı yok');
        expect(find.text(solfege), findsOneWidget, reason: '$solfege yok');
      }
      // Ekranda gerçekten karşılaşılan iki soru: diyez ve oktav sayısı.
      expect(find.textContaining('sharp'), findsWidgets);
      expect(find.textContaining('octave'), findsWidgets);
    });

    testWidgets('"Anladım" kartı kapatır', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(host());

      await t.tap(find.byType(NoteNamesButton));
      await t.pumpAndSettle();
      // Kart kaydırılabilir (büyük metin ölçeğinde uzar) — düğmeyi önce görünür
      // kıl ki test "dokundum ama ıskaladım" hatasıyla yanıltmasın.
      await t.ensureVisible(find.text('Got it'));
      await t.pumpAndSettle();
      await t.tap(find.text('Got it'));
      await t.pumpAndSettle();

      expect(find.text('Note names'), findsNothing);
    });

    testWidgets('TR: kart Türkçe okur', (t) async {
      ContentLocale.code = 'tr';
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(host());

      await t.tap(find.byType(NoteNamesButton));
      await t.pumpAndSettle();

      expect(find.text('Nota adları'), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);
      // Harfler ÇEVRİLMEZ — bu bir köprü, yeniden adlandırma değil.
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Do'), findsOneWidget);
    });

    testWidgets('1.3x metin ölçeğinde taşma yok', (t) async {
      await t.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(host(textScale: 1.3));

      await t.tap(find.byType(NoteNamesButton));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '1.3x kart taşmamalı');
    });
  });
}
