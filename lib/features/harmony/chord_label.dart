import 'package:flutter/material.dart';

import '../../core/chord.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// AKOR ETİKETİ — sembol + KÖK OKTAVI (küçük punto)
//
// NEDEN OKTAV: cihaz testinde kullanıcı "bazı yerlerde F akoru C'den daha kalın
// çıkıyor" dedi ve haklıydı — egzersiz her soruda başka bir "ev"de
// çalınabildiği için aynı harf bir soruda daha pes, bir soruda daha tiz
// duyuluyordu; "C" ve "F" yazıları bunu söylemiyordu. (Sol majörde taş sırası
// G4·A4·C5·D5·E5 → harf sırası perde sırasını yanıltır.)
//
// NEDEN KÜÇÜK PUNTO: "Am4" tek parça yazılsaydı bir akor UZANTISI ("Am7") gibi
// okunurdu. Oktav görsel olarak geride durunca sembol sembol kalır, rakam da
// yalnızca "hangi yükseklikte" sorusunu cevaplar.
//
// Kalıbı Çöz dersleri ve Şarkı Çöz modu bunu paylaşır → akor yazımı uygulamada
// tek kaynaktan gelir.
// -----------------------------------------------------------------------------

class ChordLabel extends StatelessWidget {
  const ChordLabel(this.chord, {super.key, required this.color, this.style});

  final Chord chord;
  final Color color;

  /// Sembolün punto/ağırlığı; oktav rakamı bundan türetilir.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
      fontWeight: FontWeight.w800,
      color: color,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          text: shortChordName(chord),
          style: base,
          children: [
            TextSpan(
              text: '${chord.root.octave}',
              style: base?.copyWith(
                fontSize: (base.fontSize ?? 16) * 0.62,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
