import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../core/interval.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// ARALIĞI KUR — "Kur" adımı
//
// Kullanıcı aralığı sadece duymadan önce, kök notadan hedef notaya nasıl
// inşa edildiğini görür: C4 + 4 yarım ses = E4 = Büyük 3'lü gibi.
// -----------------------------------------------------------------------------

class IntervalBuildPage extends StatefulWidget {
  const IntervalBuildPage({
    super.key,
    required this.pool,
    required this.player,
    required this.onComplete,
  });

  final List<MusicInterval> pool;
  final NotePlayer player;
  final VoidCallback onComplete;

  @override
  State<IntervalBuildPage> createState() => _IntervalBuildPageState();
}

class _IntervalBuildPageState extends State<IntervalBuildPage> {
  static final Note _root = Note.fromName('C', 4);
  static final List<Note> _keys = noteRange(_root, Note(_root.midi + 12));

  late final List<MusicInterval> _toBuild = _pick();

  int _index = 0;
  Note? _selected;
  bool _answeredCorrectly = false;
  bool _playing = false;

  List<MusicInterval> _pick() {
    final shuffled = List<MusicInterval>.from(widget.pool)..shuffle();
    final count = widget.pool.length <= 5 ? widget.pool.length : 5;
    return shuffled.take(count).toList();
  }

  MusicInterval get _interval => _toBuild[_index];
  Note get _target => _interval.topFrom(_root);

  Future<void> _playTarget() async {
    if (_playing) return;
    setState(() => _playing = true);
    await widget.player.play(_root);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await widget.player.play(_target);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _choose(Note note) async {
    if (_answeredCorrectly || _playing) return;
    setState(() {
      _selected = note;
      _answeredCorrectly = note == _target;
    });
    if (_answeredCorrectly) {
      await _playTarget();
    } else {
      await widget.player.play(note);
    }
  }

  void _next() {
    if (_index + 1 >= _toBuild.length) {
      widget.onComplete();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answeredCorrectly = false;
      _playing = false;
    });
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final wrong = selected != null && !_answeredCorrectly;

    return Scaffold(
      appBar: AppBar(
        title: Text('Aralığı Kur · ${_index + 1}/${_toBuild.length}'),
        actions: [TextButton(onPressed: _skip, child: const Text('Geç'))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kökten hedefi kur', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Kök nota C4. ${_interval.name} kurmak için üst notayı seç. '
                'Yarım ses merdivenini görerek aralığın şeklini oturt.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _targetPanel(theme, wrong),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  children: [for (final note in _keys) _keyButton(theme, note)],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _playing ? null : _playTarget,
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Doğru cevabı dinle'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _answeredCorrectly ? _next : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _index + 1 >= _toBuild.length ? 'Devam' : 'Sonraki aralık',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetPanel(ThemeData theme, bool wrong) {
    final color = _answeredCorrectly
        ? const Color(0xFF56C271)
        : wrong
            ? const Color(0xFFD25872)
            : theme.colorScheme.primary;
    final selected = _selected;
    final status = _answeredCorrectly
        ? 'Doğru: ${_root.label} → ${_target.label}'
        : wrong
            ? '${selected!.label} değil; ${_interval.semitones} yarım ses yukarıyı ara.'
            : '${_interval.semitones} yarım ses yukarı';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${_interval.semitones}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _interval.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyButton(ThemeData theme, Note note) {
    final selected = _selected == note;
    final isTarget = _answeredCorrectly && note == _target;
    final isRoot = note == _root;

    Color bg = theme.colorScheme.surface;
    Color fg = theme.colorScheme.onSurface;
    if (isRoot) {
      bg = theme.colorScheme.secondaryContainer;
      fg = theme.colorScheme.onSecondaryContainer;
    }
    if (selected && !_answeredCorrectly) {
      bg = const Color(0xFF9E3B4E);
      fg = Colors.white;
    }
    if (isTarget) {
      bg = const Color(0xFF2E7D4F);
      fg = Colors.white;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isRoot ? null : () => _choose(note),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isRoot ? 'kök' : '${note.midi - _root.midi} ys',
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
