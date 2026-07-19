import 'package:flutter/material.dart';

import '../../core/concept.dart';
import '../../core/content_locale.dart';

// -----------------------------------------------------------------------------
// KAVRAM KARTI — öğretici içeriği gösteren ortak parça
//
// [showConceptSheet]: alttan açılan, kaydırılabilir kart (modal). [ConceptCardButton]:
// öğren ekranının üstüne konulan "Bu ders ne anlatıyor?" düğmesi. İkisi de aynı
// [Concept]'i gösterir.
// -----------------------------------------------------------------------------

Future<void> showConceptSheet(BuildContext context, Concept concept) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  concept.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final s in concept.sections) ...[
                  if (s.heading != null) ...[
                    Text(
                      s.heading!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    s.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(t(en: 'Got it', tr: 'Anladım')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Öğren ekranının üstüne konulan "Bu ders ne anlatıyor?" kartı.
class ConceptCardButton extends StatelessWidget {
  const ConceptCardButton({super.key, required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showConceptSheet(context, concept),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        en: "What's this lesson about?",
                        tr: 'Bu ders ne anlatıyor?',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      concept.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
