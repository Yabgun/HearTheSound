import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/note.dart';
import '../dev/pitch_spike_page.dart';
import '../lesson/lesson.dart';

// -----------------------------------------------------------------------------
// TANI AŞAMASI — Nota Tanıma testi (sabit uzunlukta oturum)
//
// Uygulama bir nota çalar, kullanıcı şıklardan doğru notayı seçer. [questionCount]
// soru sonunda oturum biter ve [onComplete] ile sonuç (doğru/toplam) döner.
// "Nazik ustalık": yanlışta ceza yok — doğru gösterilir, devam edilir.
// -----------------------------------------------------------------------------

class NoteRecognitionPage extends StatefulWidget {
  const NoteRecognitionPage({
    super.key,
    required this.pool,
    required this.player,
    required this.questionCount,
    this.onComplete,
    this.onRelearn,
  });

  final List<Note> pool;
  final NotePlayer player;
  final int questionCount;
  final void Function(LessonResult result)? onComplete;
  final VoidCallback? onRelearn;

  @override
  State<NoteRecognitionPage> createState() => _NoteRecognitionPageState();
}

class _NoteRecognitionPageState extends State<NoteRecognitionPage> {
  static const int _maxOptions = 4;
  final Random _rng = Random();

  late Note _target;
  late List<Note> _options;
  Note? _selected;
  bool _answered = false;
  int _index = 0; // 0-tabanlı soru numarası
  int _correct = 0; // doğru sayısı
  int _streak = 0; // ders içi seri (ateş göstergesi)

  @override
  void initState() {
    super.initState();
    _pick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTarget());
  }

  void _pick() {
    final pool = widget.pool;
    final target = pool[_rng.nextInt(pool.length)];
    final options = <Note>{target};
    final limit = min(_maxOptions, pool.length);
    while (options.length < limit) {
      options.add(pool[_rng.nextInt(pool.length)]);
    }
    _target = target;
    _options = options.toList()..shuffle(_rng);
    _selected = null;
    _answered = false;
  }

  Future<void> _next() async {
    setState(() {
      _index++;
      _pick();
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _playTarget();
  }

  Future<void> _playTarget() => widget.player.play(_target);

  void _answer(Note choice) {
    if (_answered) return;
    setState(() {
      _selected = choice;
      _answered = true;
      if (choice == _target) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
  }

  void _finish() {
    widget.onComplete?.call(LessonResult(_correct, widget.questionCount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _answered && _selected == _target;
    final cols = _options.length <= 3 ? _options.length : 2;
    final isLast = _index >= widget.questionCount - 1;
    final progress = (_index + (_answered ? 1 : 0)) / widget.questionCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${_index + 1} / ${widget.questionCount}'),
        actions: [
          if (widget.onRelearn != null)
            IconButton(
              icon: const Icon(Icons.school_rounded),
              tooltip: 'Tekrar öğren',
              onPressed: widget.onRelearn,
            ),
          IconButton(
            icon: const Icon(Icons.graphic_eq_rounded),
            tooltip: 'Perde tespiti (geliştirici)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PitchSpikePage()),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '★ $_correct',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 4),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                _streak > 1 ? '🔥 $_streak seri' : 'Çalınan notayı bul',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PlayButton(onTap: _playTarget),
              const SizedBox(height: 12),
              Text(
                'dinlemek için dokun',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(flex: 2),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 2 ? 2.1 : 1.4,
                children: _options.map(_optionButton).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 84,
                child: _answered
                    ? Column(
                        children: [
                          Text(
                            correct
                                ? 'Doğru! ✓  ${_target.label}'
                                : 'Bu ${_target.label} idi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correct
                                  ? const Color(0xFF56C271)
                                  : const Color(0xFFD25872),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: isLast ? _finish : _next,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                            ),
                            child: Text(isLast ? 'Bitir' : 'Sonraki'),
                          ),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionButton(Note note) {
    final theme = Theme.of(context);
    Color bg = theme.colorScheme.surfaceContainerHighest;
    Color fg = theme.colorScheme.onSurface;

    if (_answered) {
      if (note == _target) {
        bg = const Color(0xFF2E7D4F);
        fg = Colors.white;
      } else if (note == _selected) {
        bg = const Color(0xFF9E3B4E);
        fg = Colors.white;
      } else {
        bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
        fg = theme.colorScheme.onSurfaceVariant;
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _answered ? null : () => _answer(note),
        child: Center(
          child: Text(
            note.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyük dairesel "çal" düğmesi.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.volume_up_rounded,
          size: 54,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
