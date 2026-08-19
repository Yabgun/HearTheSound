import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import 'rhythm_pattern.dart';

// -----------------------------------------------------------------------------
// RİTİM ZAMAN ÇİZELGESİ — dersin görsel kalbi
//
// İlk sürümde bu, ince bir ray üstünde eşit büyüklükte noktalardı. Cihazda
// "UI fazla sade kalmış" geri bildirimi geldi ve haklıydı — ama sorun süs
// eksikliği değil, BİLGİ eksikliğiydi. Dört şey eklendi ve dördü de dekor
// değil, ölçülebilir bir öğretme işi yapıyor:
//
//  1. VURUŞ IZGARASI — her vuruşta soluk dikey çizgi, ölçü başında belirgin.
//     Senkop dersinde "ses vuruşun ARASINA düştü" cümlesi artık GÖRÜLÜYOR;
//     kelime olmaktan çıkıp şekle dönüşüyor.
//  2. SESLER BLOK — genişlik, bir sonraki sese kadar geçen süre. Ritim demek
//     süre demek; eşit noktalar tam da öğretilmek isteneni gizliyordu.
//  3. GERÇEK ZAMANLI İMLEÇ — çalarken soldan sağa süzülür, nabız görünür olur.
//  4. SENİN ŞERİDİN — vuruşların canlı düşer; cevaptan sonra her vuruş kendi
//     hedefine kısa bir çizgiyle bağlanır → "geç kaldın" bir MESAFE olur.
//
// KURAL: ekranda kıpırdayan her şey GERÇEK ZAMANI temsil eder. Bu bir zamanlama
// dersi; gerçeğe bağlı olmayan bir animasyon yanlış tempo öğretirdi.
//
// İmleç `setState` ile değil tek bir [Animation] + [CustomPainter] ile çizilir:
// kare düşürmek burada kozmetik bir kusur değil, mekaniği bozan bir hatadır.
// -----------------------------------------------------------------------------

class RhythmTimeline extends StatelessWidget {
  const RhythmTimeline({
    super.key,
    required this.shape,
    required this.targetMs,
    required this.tapMs,
    this.comparison,
    this.soundingIndex,
    this.playhead,
    this.playheadSpanMs = 0,
  });

  final RhythmShape shape;

  /// Çalınan kalıbın ses zamanları (ms).
  final List<int> targetMs;

  /// Kullanıcının vuruşları (ms, kendi kronometresine göre).
  final List<int> tapMs;

  /// Değerlendirme yapıldıysa sonuç; null ise kullanıcı hâlâ vuruyor.
  final RhythmComparison? comparison;

  /// Şu an çalan sesin indisi (yalnızca çalarken).
  final int? soundingIndex;

  /// 0→1 ilerleyen çalma animasyonu; null = imleç gösterilmez.
  final Animation<double>? playhead;

  /// [playhead] 1'e ulaştığında kaç ms geçmiş olacak.
  final int playheadSpanMs;

  /// Sabit yükseklik: faz değiştikçe (çalma → cevap → sonuç) çizelge zıplamasın.
  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animation = playhead;

    Widget paint(double? playheadMs) => CustomPaint(
      size: Size.infinite,
      painter: _RhythmPainter(
        shape: shape,
        targetMs: targetMs,
        tapMs: tapMs,
        comparison: comparison,
        soundingIndex: soundingIndex,
        playheadMs: playheadMs,
        grid: theme.colorScheme.outline.withValues(alpha: 0.25),
        gridStrong: theme.colorScheme.outline.withValues(alpha: 0.55),
        rail: context.colors.wash,
        block: theme.colorScheme.outline,
        active: context.colors.grape,
        ok: context.colors.success,
        bad: context.colors.danger,
      ),
    );

    return Semantics(
      // Çizim ekran okuyucuya bir şey söylemez; özet metin söyler.
      label: t(
        en: '${targetMs.length} hits over ${shape.beats} beats',
        tr: '${shape.beats} vuruşluk kalıpta ${targetMs.length} ses',
      ),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: animation == null
            ? paint(null)
            : AnimatedBuilder(
                // Yalnızca boyayıcı yeniden çizilir; sayfa yeniden kurulmaz.
                animation: animation,
                builder: (context, _) =>
                    paint(animation.value * playheadSpanMs),
              ),
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter({
    required this.shape,
    required this.targetMs,
    required this.tapMs,
    required this.comparison,
    required this.soundingIndex,
    required this.playheadMs,
    required this.grid,
    required this.gridStrong,
    required this.rail,
    required this.block,
    required this.active,
    required this.ok,
    required this.bad,
  });

  final RhythmShape shape;
  final List<int> targetMs;
  final List<int> tapMs;
  final RhythmComparison? comparison;
  final int? soundingIndex;
  final double? playheadMs;
  final Color grid;
  final Color gridStrong;
  final Color rail;
  final Color block;
  final Color active;
  final Color ok;
  final Color bad;

  // Dikey yerleşim (px): üstte kalıp şeridi, altta kullanıcının şeridi.
  static const double _blockTop = 14;
  static const double _blockHeight = 34;
  static const double _tapY = 86;
  static const double _tapRadius = 9;

  double get _blockBottom => _blockTop + _blockHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final total = shape.totalMs;
    double x(num ms) => (ms / total) * w;

    _paintGrid(canvas, size, x);
    _paintBlocks(canvas, x);
    _paintTaps(canvas, x);
    _paintPlayhead(canvas, size, x);
  }

  /// Vuruş ızgarası — kalıbın hangi zemine oturduğunu gösterir.
  void _paintGrid(Canvas canvas, Size size, double Function(num) x) {
    final line = Paint()..strokeWidth = 1;
    for (var beat = 0; beat <= shape.beats; beat++) {
      // Ölçü başları (4/4 varsayımı) daha belirgin: kullanıcı "nerede
      // başladık" sorusunu okumadan cevaplasın.
      final isBarStart = beat % 4 == 0;
      line
        ..color = isBarStart ? gridStrong : grid
        ..strokeWidth = isBarStart ? 1.6 : 1;
      final dx = x(beat * kRhythmBeatMs).clamp(0.5, size.width - 0.5);
      canvas.drawLine(Offset(dx, 4), Offset(dx, _tapY + 16), line);
    }

    // Kullanıcı şeridinin rayı — vuruşların üstüne düştüğü zemin.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _tapY - 2, size.width, 4),
        const Radius.circular(99),
      ),
      Paint()..color = rail,
    );
  }

  /// Sesler BLOK olarak: genişlik = bir sonraki sese kadar geçen süre.
  void _paintBlocks(Canvas canvas, double Function(num) x) {
    for (var i = 0; i < targetMs.length; i++) {
      final start = targetMs[i];
      final end = i + 1 < targetMs.length ? targetMs[i + 1] : shape.totalMs;
      final isActive = soundingIndex == i;
      final left = x(start) + 1.5;
      final right = (x(end) - 1.5).clamp(left + 6, double.infinity);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, _blockTop, right, _blockBottom),
        const Radius.circular(9),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isActive
              ? active
              : block.withValues(alpha: 0.32),
      );
      // Sesin BAŞLADIĞI an blok içindeki koyu şeritle işaretlenir: uzun bir
      // blok "uzun bir ses" demektir, "geç başlayan" değil.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, _blockTop, left + 5, _blockBottom),
          const Radius.circular(9),
        ),
        Paint()..color = isActive ? active : block.withValues(alpha: 0.85),
      );
      if (isActive) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = active.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
  }

  /// Kullanıcının vuruşları + cevaptan sonra hedefine bağlayan çizgiler.
  void _paintTaps(Canvas canvas, double Function(num) x) {
    if (tapMs.isEmpty || targetMs.isEmpty) return;
    // Hizalama karşılaştırmayla AYNI: her iki taraf da kendi ilk vuruşuna göre
    // sıfırlanır, yoksa "geç başladım" hatası gibi görünürdü.
    final base = tapMs.first;
    final anchor = targetMs.first;
    final result = comparison;

    for (var i = 0; i < tapMs.length; i++) {
      final tapX = x(tapMs[i] - base + anchor);
      final color = result == null
          ? active
          : (result.matches[i] ? ok : bad);

      // Bağlayıcı: vuruşundan hedefine. Sapma bir MESAFE olarak görünür.
      if (result != null && i < targetMs.length) {
        final targetX = x(targetMs[i]);
        canvas.drawLine(
          Offset(targetX, _blockBottom + 2),
          Offset(tapX, _tapY - _tapRadius),
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.drawCircle(Offset(tapX, _tapY), _tapRadius, Paint()..color = color);
      canvas.drawCircle(
        Offset(tapX, _tapY),
        _tapRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Gerçek zamanlı imleç — çalarken nabzı görünür kılar.
  void _paintPlayhead(Canvas canvas, Size size, double Function(num) x) {
    final ms = playheadMs;
    if (ms == null) return;
    final dx = x(ms).clamp(0.0, size.width);
    canvas.drawLine(
      Offset(dx, 4),
      Offset(dx, _tapY + 12),
      Paint()
        ..color = active.withValues(alpha: 0.9)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(dx, 4), 4.5, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_RhythmPainter old) =>
      old.playheadMs != playheadMs ||
      old.soundingIndex != soundingIndex ||
      old.tapMs.length != tapMs.length ||
      old.comparison != comparison ||
      !identical(old.targetMs, targetMs);
}
