import 'package:flutter/material.dart';

import '../core/content_locale.dart';
import '../features/mascot/eko_mascot.dart';

// -----------------------------------------------------------------------------
// COACH-MARK TURU — ilk açılışta "nereye basacağım?" sorusunu çözen hafif overlay
//
// Karartılmış zemin + (varsa) hedef widget'ın etrafında spot ışığı deliği + Eko
// konuşma balonu + İleri/Atla. Harici paket YOK — Eko'yu elle çizdiğimiz gibi bu
// da kendi yazdığımız küçük bir parça (ethos: bağımlılık yerine kendi dilimiz).
//
// Kullanım: hedef göstermek istediğin widget'a bir GlobalKey ver, adımına geçir.
// Overlay'i ana ekranın ÜSTÜNE (tam ekran Stack) koy → nav çubuğu dahil her yeri
// kaplar. Hedefsiz adımlar ekran ortasında açıklanır.
// -----------------------------------------------------------------------------

/// Turun tek bir adımı. [targetKey] null ise adım ekran ortasında gösterilir.
class CoachStep {
  final String title;
  final String body;
  final GlobalKey? targetKey;
  const CoachStep({required this.title, required this.body, this.targetKey});
}

class CoachMarks extends StatefulWidget {
  const CoachMarks({super.key, required this.steps, required this.onDone});

  final List<CoachStep> steps;

  /// Tur bitince ya da atlanınca çağrılır (çağıran tutorialSeen'i işaretler).
  final VoidCallback onDone;

  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks> {
  int _i = 0;
  Rect? _hole; // mevcut adımın hedef dikdörtgeni (global koordinat)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Mevcut adımın hedefini ölç (yerleşim tamamlandıktan sonra).
  void _measure() {
    final ctx = widget.steps[_i].targetKey?.currentContext;
    Rect? r;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        r = (box.localToGlobal(Offset.zero) & box.size).inflate(8);
      }
    }
    if (mounted) setState(() => _hole = r);
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _i++;
      _hole = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final isLast = _i + 1 >= widget.steps.length;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Karartma + spot ışığı; tüm ekrana tıklama = "ileri".
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(painter: _SpotlightPainter(_hole)),
            ),
          ),
          _card(context, step, isLast),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, CoachStep step, bool isLast) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context).size;
    final hole = _hole;

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 26),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EkoMascot(size: 44, celebrate: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${_i + 1} / ${widget.steps.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onDone,
                child: Text(t(en: 'Skip', tr: 'Atla')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _next,
                child: Text(
                  isLast
                      ? t(en: 'Got it', tr: 'Anladım')
                      : t(en: 'Next', tr: 'İleri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (hole == null) return Center(child: card);

    // Hedef ekranın alt yarısındaysa kartı üstüne, değilse altına yerleştir.
    final holeBelow = hole.center.dy > media.height / 2;
    return Positioned(
      left: 0,
      right: 0,
      top: holeBelow ? null : hole.bottom + 16,
      bottom: holeBelow ? (media.height - hole.top + 16) : null,
      child: Align(alignment: Alignment.topCenter, child: card),
    );
  }
}

/// Tam ekranı karartır; [hole] verilirse o dikdörtgeni "keser" (spot ışığı).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final screen = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(screen, paint);
      return;
    }
    final full = Path()..addRect(screen);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(16)));
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
