import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';

// -----------------------------------------------------------------------------
// EKO — uygulamanın maskotu
//
// Kulaklık takan, sesi "duyan" bir baloncuk. Tamamen kendi geometrimiz
// (daireler + yaylar + gradyan) → telif riski yok. CustomPaint ile çizilir,
// asset/bağımlılık gerektirmez. Boyut [size] ile ölçeklenir.
// -----------------------------------------------------------------------------

class EkoMascot extends StatelessWidget {
  const EkoMascot({super.key, this.size = 64, this.celebrate = false});

  final double size;

  /// Kutlama modu: gözler mutlu yay olur (ders tamamlama vb.).
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    // Dekoratif görsel: ekran okuyucuya gürültü olmasın (metinler zaten anlatıyor).
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _EkoPainter(celebrate: celebrate)),
      ),
    );
  }
}

class _EkoPainter extends CustomPainter {
  _EkoPainter({required this.celebrate});

  final bool celebrate;

  static const _dark = Color(0xFF2C2652);
  static const _cheek = Color(0xFFFF9AA0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120.0; // 120 birimlik tuvalde çiz, ölçekle
    canvas.scale(s);

    // Zemin gölgesi
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 108), width: 56, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );

    // Gövde (gradyan baloncuk)
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9C7DFF), AppColors.coral],
      ).createShader(const Rect.fromLTWH(20, 20, 80, 80));
    canvas.drawCircle(const Offset(60, 60), 40, body);

    // Kulaklık bandı (üstten yay)
    final band = Paint()
      ..color = _dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(60, 58), radius: 40),
      3.14159, // sol
      -3.14159, // üstten sağa
      false,
      band,
    );

    // Kulaklık yastıkları (yanlar)
    final cup = Paint()..color = _dark;
    canvas.drawRRect(
      RRect.fromLTRBR(12, 54, 26, 78, const Radius.circular(7)),
      cup,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(94, 54, 108, 78, const Radius.circular(7)),
      cup,
    );

    // Yanaklar
    final cheek = Paint()..color = _cheek.withValues(alpha: 0.65);
    canvas.drawCircle(const Offset(43, 70), 4.5, cheek);
    canvas.drawCircle(const Offset(79, 70), 4.5, cheek);

    // Gözler
    if (celebrate) {
      // Mutlu yay gözler ( ^ ^ )
      final happy = Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(49, 60), radius: 7),
        3.6,
        1.9,
        false,
        happy,
      );
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(71, 60), radius: 7),
        3.6,
        1.9,
        false,
        happy,
      );
    } else {
      final white = Paint()..color = Colors.white;
      final pupil = Paint()..color = AppColors.ink;
      canvas.drawCircle(const Offset(49, 58), 7, white);
      canvas.drawCircle(const Offset(71, 58), 7, white);
      canvas.drawCircle(const Offset(50, 59), 3.4, pupil);
      canvas.drawCircle(const Offset(72, 59), 3.4, pupil);
    }

    // Gülümseme
    final smile = Paint()
      ..color = _dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final mouth = Path()
      ..moveTo(50, 74)
      ..quadraticBezierTo(60, celebrate ? 86 : 83, 70, 74);
    canvas.drawPath(mouth, smile);
  }

  @override
  bool shouldRepaint(covariant _EkoPainter oldDelegate) =>
      oldDelegate.celebrate != celebrate;
}
