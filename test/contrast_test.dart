import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/ui/app_theme.dart';

// -----------------------------------------------------------------------------
// KONTRAST KİLİDİ — WCAG 2.x oranları, İKİ PALET İÇİN DE
//
// Tema renkleri "göze güzel" diye seçilirken erişilebilirlik sessizce bozulur.
// Bu test kritik metin/zemin çiftlerinin oranını HESAPLAR ve eşiğin altına
// düşen her değişikliği kırmızıya boyar. Eşikler:
//   ≥ 4.5 : normal metin (AA)
//   ≥ 3.0 : büyük/kalın metin, ikincil ikonlar (AA-large)
//
// TASARIM: kontroller TEK bir gövdede ([_checkPalette]) yazılır ve hem açık hem
// koyu palete uygulanır. Ayrı ayrı yazılsalardı yeni bir kontrol eklendiğinde
// biri güncellenip diğeri unutulurdu — koyu tema tam olarak böyle çürür.
// -----------------------------------------------------------------------------

double _linear(double channel) {
  // 0..1 sRGB → doğrusal ışık
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _linear((c.r * 255.0).round() / 255.0) +
    0.7152 * _linear((c.g * 255.0).round() / 255.0) +
    0.0722 * _linear((c.b * 255.0).round() / 255.0);

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}

void _expectAtLeast(Color fg, Color bg, double min, String label) {
  final ratio = contrastRatio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$label: ${ratio.toStringAsFixed(2)}:1 < $min:1',
  );
}

/// Bir paletin tüm kritik çiftlerini sınar. [name] hata mesajında görünür ki
/// hangi paletin bozulduğu tek bakışta belli olsun.
void _checkPalette(AppPalette p, String name) {
  group('$name palet', () {
    test('normal metin zeminlerde (≥4.5)', () {
      _expectAtLeast(p.ink, p.paper, 4.5, '$name ink/paper');
      _expectAtLeast(p.ink, p.card, 4.5, '$name ink/card');
      _expectAtLeast(p.ink, p.wash, 4.5, '$name ink/wash');
      // Mor tint zemini seçili şıklarda kullanılıyor; üstündeki metin okunmalı.
      _expectAtLeast(p.ink, p.grapeSoft, 4.5, '$name ink/grapeSoft');
      _expectAtLeast(p.muted, p.paper, 4.5, '$name muted/paper');
      _expectAtLeast(p.muted, p.card, 4.5, '$name muted/card');
    });

    test('vurgu ve geri bildirim METİN olarak (≥4.5)', () {
      for (final (label, color) in [
        ('grape', p.grape),
        ('success', p.success),
        ('danger', p.danger),
        ('amberDeep', p.amberDeep),
      ]) {
        _expectAtLeast(color, p.paper, 4.5, '$name $label/paper');
        _expectAtLeast(color, p.card, 4.5, '$name $label/card');
      }
    });

    test('dolgu üstündeki etiket (≥4.5)', () {
      // Cevap geri bildiriminde doğru/yanlış şıkkın zemini success/danger olur.
      // Üstüne yazılan rengin paletle GELMESİ şart: açık temada beyaz doğruydu,
      // koyu temada açık yeşil dolgunun üstünde beyaz okunmaz.
      _expectAtLeast(p.onSuccess, p.success, 4.5, '$name onSuccess/success');
      _expectAtLeast(p.onDanger, p.danger, 4.5, '$name onDanger/danger');
    });

    test('soluk metin ve ikonlar (≥3.0)', () {
      _expectAtLeast(p.faint, p.paper, 3.0, '$name faint/paper');
      _expectAtLeast(p.faint, p.card, 3.0, '$name faint/card');
    });

    test('zeminler birbirinden ayırt edilebilir', () {
      // Kart zeminden ayrılmazsa arayüz tek düz yüzeye dönüşür — koyu temada
      // en sık yapılan hata bu. Küçük ama SIFIR OLMAYAN bir fark şart.
      expect(
        contrastRatio(p.card, p.paper),
        greaterThan(1.03),
        reason: '$name: kart ile zemin ayırt edilemiyor',
      );
    });
  });
}

/// Temanın ColorScheme'i de sınanır: ekranların çoğu rengi doğrudan palet
/// yerine şemadan okur (`theme.colorScheme.primary` gibi). Palet doğru olup
/// şema yanlış olsaydı test yeşil, ekran okunaksız olurdu.
void _checkScheme(Brightness brightness, AppPalette palette, String name) {
  // Tema GÖVDE İÇİNDE kurulur: kurulum aşamasında (main gövdesinde) patlarsa
  // dosyadaki TÜM testler "did not complete" olur, palet testleri dahil.
  test('$name ColorScheme rolleri', () {
    final s = AppTheme.forTest(brightness, palette).colorScheme;
    _expectAtLeast(s.onSurface, s.surface, 4.5, '$name onSurface/surface');
    _expectAtLeast(
      s.onSurfaceVariant,
      s.surface,
      4.5,
      '$name onSurfaceVariant/surface',
    );
    _expectAtLeast(s.onPrimary, s.primary, 4.5, '$name onPrimary/primary');
    _expectAtLeast(s.onError, s.error, 4.5, '$name onError/error');
    _expectAtLeast(
      s.onPrimaryContainer,
      s.primaryContainer,
      4.5,
      '$name onPrimaryContainer/primaryContainer',
    );
    _expectAtLeast(
      s.onSurface,
      s.surfaceContainerHighest,
      4.5,
      '$name onSurface/surfaceContainerHighest',
    );
  });
}

void main() {
  // Tema kurulumu platform kanallarına uzanıyor.
  TestWidgetsFlutterBinding.ensureInitialized();

  _checkPalette(AppPalette.light, 'açık');
  _checkPalette(AppPalette.dark, 'koyu');

  group('tema şemaları', () {
    _checkScheme(Brightness.light, AppPalette.light, 'açık');
    _checkScheme(Brightness.dark, AppPalette.dark, 'koyu');
  });

  group('tema kurulumu', () {
    test('her iki tema da paleti uzantı olarak taşır', () {
      // Uzantı takılmazsa `context.colors` sessizce AÇIK palete düşer ve koyu
      // tema hiç görünmez — bu testin asıl işi o sessiz düşüşü yakalamak.
      final light = AppTheme.forTest(Brightness.light, AppPalette.light);
      final dark = AppTheme.forTest(Brightness.dark, AppPalette.dark);
      expect(light.extension<AppPalette>(), AppPalette.light);
      expect(dark.extension<AppPalette>(), AppPalette.dark);
      // Zemin de paletten gelmeli: uzantı takılı olup scaffold rengi elle
      // yazılsaydı koyu temada ekran beyaz kalırdı.
      expect(dark.scaffoldBackgroundColor, AppPalette.dark.paper);
    });

    test('parlaklık bayrakları paletlerle tutarlı', () {
      expect(
        AppTheme.forTest(Brightness.light, AppPalette.light).brightness,
        Brightness.light,
      );
      expect(
        AppTheme.forTest(Brightness.dark, AppPalette.dark).brightness,
        Brightness.dark,
      );
      // Koyu temanın zemini gerçekten koyu olmalı (yanlış palet takılırsa
      // brightness doğru ama renkler açık kalabilir).
      expect(_luminance(AppPalette.dark.paper), lessThan(0.05));
      expect(_luminance(AppPalette.light.paper), greaterThan(0.5));
    });
  });
}
