import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';

/// Bir hedef notanın, kullanıcının rahat aralığına göre durumunu gösteren küçük
/// rozet. Rahat aralıktaysa (ya da henüz kalibre edilmemişse) hiçbir şey
/// göstermez — sadece rahat aralığı aşan (esneme/dışı) hedeflerde belirir.
///
/// İçerik zaten kullanıcının aralığına transpoze edildiğinden çoğu hedef rahat
/// aralıktadır; bu rozet yalnızca aralığın dar olduğu (bir akor tam sığmadığı)
/// durumlarda ortaya çıkar.
class ReachBadge extends StatelessWidget {
  const ReachBadge({super.key, required this.target, required this.range});

  final Note target;
  final VocalRange? range;

  @override
  Widget build(BuildContext context) {
    final r = range;
    if (r == null) return const SizedBox.shrink();
    final zone = reachZoneFor(target.midi, r);
    if (zone == ReachZone.comfort) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final above = target.midi > r.comfortHigh;
    final beyond = zone == ReachZone.beyond;
    final color = beyond ? theme.colorScheme.error : const Color(0xFFE0912B);
    final text = beyond
        ? (above
              ? t(en: 'above your range', tr: 'aralığının üstünde')
              : t(en: 'below your range', tr: 'aralığının altında'))
        : (above
              ? t(
                  en: 'a bit high — you can reach it if you push',
                  tr: 'biraz tiz — zorlarsan çıkar',
                )
              : t(
                  en: 'a bit low — you can reach it if you push',
                  tr: 'biraz pes — zorlarsan çıkar',
                ));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            above ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
