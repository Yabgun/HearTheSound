import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../../ui/app_icons.dart';
import '../../ui/app_theme.dart';
import '../mascot/player_eko.dart';

// -----------------------------------------------------------------------------
// DERS GİRİŞİ — "bu dersten sonra şunu yapabileceksin"
//
// Kullanıcının en temel şikâyeti "neyi neden yaptığımı anlamıyorum"du. Bu ekran
// derse GİRMEDEN önce tek cümlelik somut bir kazanım verir; Eko de yanında
// durur. Kısa ve öz olması bilinçli: uzun kavram kartları denendi, işe yaramadı.
//
// Tüm track'ler bunu paylaşır → ders girişi uygulama genelinde tek bir deneyim.
// -----------------------------------------------------------------------------

class LessonIntroPage extends StatelessWidget {
  const LessonIntroPage({
    super.key,
    required this.title,
    required this.promise,
    required this.onStart,
    this.howItWorks,
  });

  /// Dersin başlığı (AppBar).
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" cümlesi.
  final String promise;

  /// İsteğe bağlı tek satırlık "nasıl oynanır" açıklaması.
  final String? howItWorks;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: PlayerEko(size: 104)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.grapeSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(AppIcons.promise, color: AppColors.grape),
                        const SizedBox(width: 10),
                        Text(
                          t(en: 'After this lesson', tr: 'Bu dersten sonra'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.grape,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promise,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (howItWorks != null) ...[
                const SizedBox(height: 20),
                Text(
                  howItWorks!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t(en: "Let's go", tr: 'Hadi başlayalım')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
