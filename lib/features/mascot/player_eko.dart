import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/progress_controller.dart';
import 'eko_mascot.dart';

// -----------------------------------------------------------------------------
// PLAYER EKO — kullanıcının SEÇTİĞİ renkteki Eko
//
// `EkoMascot` bilerek saf/renk-bilmez kalır (onboarding, coach turu gibi "seçim
// öncesi" ya da "uygulama kişiliği" anlarında düz Eko lazım). Bu sarmalayıcı,
// profildeki `avatarId`'yi okuyup paleti geçirir.
//
// Kullanıcı-yüzü her yerde (ana ekran, ders bitişi, pratik, günlük, profil)
// bunu kullan → seçilen avatar uygulamanın her yerinde canlanır. `.select` ile
// yalnızca avatarId değişince yeniden çizilir (gereksiz rebuild yok).
// -----------------------------------------------------------------------------

class PlayerEko extends ConsumerWidget {
  const PlayerEko({super.key, this.size = 64, this.celebrate = false});

  final double size;
  final bool celebrate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarId = ref.watch(
      progressProvider.select((p) => p.profile.avatarId),
    );
    return EkoMascot(
      size: size,
      celebrate: celebrate,
      palette: ekoPaletteFor(avatarId),
    );
  }
}
