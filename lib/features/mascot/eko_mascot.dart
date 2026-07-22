import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';

// -----------------------------------------------------------------------------
// EKO — uygulamanın maskotu
//
// Kulaklık takan, sesi "duyan" bir baloncuk. Tamamen kendi geometrimiz
// (daireler + yaylar + gradyan) → telif riski yok. CustomPaint ile çizilir,
// asset/bağımlılık gerektirmez. Boyut [size] ile ölçeklenir.
// -----------------------------------------------------------------------------

/// Eko'nun renk varyantı — profil avatarı olarak seçilebilir.
///
/// [id] KALICIDIR: `PlayerProfile.avatarId` bunu saklar, dolayısıyla yayına
/// çıkmış bir id değiştirilmemelidir (ders id'leriyle aynı disiplin —
/// bkz. PROJECT.md §17.2). Yeni varyant eklemek serbesttir.
class EkoPalette {
  final String id;
  final Color from;
  final Color to;

  /// Seçicide okunacak ad — dile duyarlı olsun diye fonksiyon değil, çağıran
  /// `t()` ile kendi etiketini verir; burada renk kimliğinden fazlası yok.
  const EkoPalette({required this.id, required this.from, required this.to});
}

/// Seçilebilir avatarlar. İlk eleman VARSAYILAN'dır (bilinmeyen id buraya düşer).
const List<EkoPalette> kEkoPalettes = [
  EkoPalette(id: 'grape', from: Color(0xFF9C7DFF), to: AppColors.coral),
  EkoPalette(id: 'ocean', from: Color(0xFF56CCF2), to: Color(0xFF2F80ED)),
  EkoPalette(id: 'forest', from: Color(0xFF7BE495), to: Color(0xFF129A74)),
  EkoPalette(id: 'sunset', from: Color(0xFFFFC371), to: Color(0xFFFF5F6D)),
  EkoPalette(id: 'berry', from: Color(0xFFFF9AA0), to: Color(0xFFB24592)),
  EkoPalette(id: 'mono', from: Color(0xFFB8C0D9), to: Color(0xFF5C6484)),
];

/// [id]'ye karşılık gelen palet; bilinmeyen/eksikse varsayılan.
///
/// Eski bir sürüm, yeni eklenmiş bir varyantı tanımasa da çökmez — sessizce
/// varsayılanı çizer.
EkoPalette ekoPaletteFor(String? id) => kEkoPalettes.firstWhere(
  (p) => p.id == id,
  orElse: () => kEkoPalettes.first,
);

class EkoMascot extends StatefulWidget {
  const EkoMascot({
    super.key,
    this.size = 64,
    this.celebrate = false,
    this.palette,
  });

  final double size;

  /// Kutlama modu: gözler mutlu yay olur VE Eko sevinçle zıplayıp sallanır
  /// ("dans"). Kutlama olmayan yerlerde (ana ekran vb.) sabit durur.
  final bool celebrate;

  /// Renk varyantı; null = varsayılan (uygulamanın her yerindeki Eko).
  final EkoPalette? palette;

  @override
  State<EkoMascot> createState() => _EkoMascotState();
}

class _EkoMascotState extends State<EkoMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dance;

  @override
  void initState() {
    super.initState();
    // Bir zıplama-sallanma döngüsü; reverse ile yumuşak gidip gelir.
    _dance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _syncDance();
  }

  /// Kutlama açıkken döndür, kapalıyken durdur ve dinlenme pozuna al. Böylece
  /// sabit Eko'lar hiç animasyon zamanlayıcısı çalıştırmaz (performans + test).
  void _syncDance() {
    if (widget.celebrate) {
      _dance.repeat(reverse: true);
    } else {
      _dance
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(EkoMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celebrate != widget.celebrate) _syncDance();
  }

  @override
  void dispose() {
    _dance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eko = CustomPaint(
      painter: _EkoPainter(
        celebrate: widget.celebrate,
        palette: widget.palette ?? kEkoPalettes.first,
      ),
    );

    // Dekoratif görsel: ekran okuyucuya gürültü olmasın (metinler zaten anlatıyor).
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.celebrate
            ? AnimatedBuilder(
                animation: _dance,
                builder: (context, child) {
                  // 0..1..0 arası: yukarı zıpla + hafifçe sağa-sola sallan.
                  final t = Curves.easeInOut.transform(_dance.value);
                  return Transform.translate(
                    offset: Offset(0, -widget.size * 0.08 * t),
                    child: Transform.rotate(
                      angle: (t - 0.5) * 0.12, // ±~3.5° salınım
                      child: child,
                    ),
                  );
                },
                child: eko,
              )
            : eko,
      ),
    );
  }
}

class _EkoPainter extends CustomPainter {
  _EkoPainter({required this.celebrate, required this.palette});

  final bool celebrate;
  final EkoPalette palette;

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
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.from, palette.to],
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
      oldDelegate.celebrate != celebrate || oldDelegate.palette.id != palette.id;
}
