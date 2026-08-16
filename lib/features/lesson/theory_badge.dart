import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../mascot/player_eko.dart';

// -----------------------------------------------------------------------------
// TEORİ ROZETİ — "önce yaşat, sonra adını koy"
//
// Kaldırılan teori track'lerinin kök hatası kavramı ÖNCE anlatıp sonra
// sordurmaktı; kullanıcı terimi anlamadığı için ders de anlamsız kalıyordu.
// Burada sıra tersine çevrilir: kullanıcı beceriyi kazanır, ders SONUNDA
// "az önce yaptığın şeyin adı buymuş" denir. Terim bir sınav değil ÖDÜLdür.
//
// Melodi ve Armoni track'leri bunu paylaşır → yeni bir yetenek track'i açmak
// rozet ekranını yeniden yazmayı gerektirmez.
// -----------------------------------------------------------------------------

/// Ders sonunda verilen teori rozeti — yaşanmış bir sezgiye ad koyar.
class TheoryBadge {
  /// Terimin kendisi (ör. "Tonik", "Bas").
  final String term;

  /// "Şunu fark ettin, adı buymuş" cümlesi.
  final String insight;

  const TheoryBadge({required this.term, required this.insight});
}

/// Rozet ekranı — ders akışında tanıma/üretme bittikten SONRA gösterilir.
class TheoryBadgePage extends StatelessWidget {
  const TheoryBadgePage({
    super.key,
    required this.badge,
    required this.onContinue,
  });

  final TheoryBadge badge;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          // Rozet metni dile ve terime göre uzayabilir; kaydırılabilir olması
          // küçük ekran + büyük yazı tipi birleşiminde taşmayı engeller.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      const PlayerEko(size: 96, celebrate: true),
                      const SizedBox(height: 20),
                      Text(
                        t(
                          en: 'You just earned a word',
                          tr: 'Bir kelime kazandın',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge.term,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.grape,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        badge.insight,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t(en: 'Got it', tr: 'Anladım')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
