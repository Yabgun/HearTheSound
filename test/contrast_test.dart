import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/ui/app_theme.dart';

// -----------------------------------------------------------------------------
// KONTRAST KİLİDİ — WCAG 2.x oranları
//
// Tema renkleri "göze güzel" diye seçilirken erişilebilirlik sessizce bozulur.
// Bu test kritik metin/zemin çiftlerinin oranını HESAPLAR ve eşiğin altına
// düşen her değişikliği kırmızıya boyar. Eşikler:
//   ≥ 4.5 : normal metin (AA)
//   ≥ 3.0 : büyük/kalın metin, ikincil ikonlar (AA-large)
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

void main() {
  const white = Colors.white;

  group('normal metin (≥4.5)', () {
    test('ana metin zeminlerde', () {
      _expectAtLeast(AppColors.ink, AppColors.paper, 4.5, 'ink/paper');
      _expectAtLeast(AppColors.ink, AppColors.card, 4.5, 'ink/card');
    });

    test('ikincil metin zeminlerde', () {
      _expectAtLeast(AppColors.muted, AppColors.paper, 4.5, 'muted/paper');
      _expectAtLeast(AppColors.muted, AppColors.card, 4.5, 'muted/card');
    });

    test('geri bildirim renkleri metin olarak', () {
      _expectAtLeast(AppColors.success, AppColors.paper, 4.5, 'success/paper');
      _expectAtLeast(AppColors.danger, AppColors.paper, 4.5, 'danger/paper');
      _expectAtLeast(AppColors.amberDeep, white, 4.5, 'amberDeep/white');
    });

    test('beyaz metin dolgu düğmelerinde', () {
      _expectAtLeast(white, AppColors.grape, 4.5, 'white/grape');
      _expectAtLeast(white, AppColors.success, 4.5, 'white/success');
      _expectAtLeast(white, AppColors.danger, 4.5, 'white/danger');
    });
  });

  group('büyük metin / ikon (≥3.0)', () {
    test('soluk metin ve ikonlar', () {
      _expectAtLeast(AppColors.faint, AppColors.paper, 3.0, 'faint/paper');
      _expectAtLeast(AppColors.faint, AppColors.card, 3.0, 'faint/card');
    });
  });
}
