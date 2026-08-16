import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/phrase_dots.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'chord_label.dart';
import 'harmony_lesson.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ — KALIBI ÇÖZ (dersler 6, 7, 8)
//
// Track'in kapanışı ve kuzey yıldızına en yakın ekran: bir akor kalıbı çalınır,
// kullanıcı onu DUYDUĞU SIRAYLA dizer. Yaptığı şey tam olarak bir şarkının
// akorlarını kulakla çıkarmaktır — "Şarkı Çöz" modunun çekirdeği de bu olacak.
//
// Cihaz testinde kullanıcının SEVDİĞİ tek mekanik buydu ("anlamlı ve amaçlı
// hissettiriyor"). Sebebi net: cevap duyduğu şeyin kendisi, işi onu geri
// kurmak. Bu yüzden zorluk yeni bir mekanikle değil, aynı mekaniğin
// basamaklarıyla büyür: iki akor → dört akor → hiç çalmamış "tuzak" akorların
// da bulunduğu palet.
//
// Taşa basınca akor ÇALAR ve sıradaki yuvaya girer; "geri al" ile çıkar. Yani
// kullanıcı ezberden değil KULAKLA eşleştirir: çal, karşılaştır, yerleştir.
// (Eko Oyunu'ndaki tuş davranışının aynısı — iki track tek bir alışkanlık
// öğretir.)
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class HarmonyPatternPage extends StatefulWidget {
  const HarmonyPatternPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onComplete,
    this.questionCount,
  });

  final HarmonyLesson lesson;
  final NotePlayer player;
  final void Function(LessonResult result) onComplete;

  /// Soru sayısını dersin varsayılanı yerine dışarıdan belirler (Sonsuz Pratik
  /// ve tekrar oturumu kısa turlar ister).
  final int? questionCount;

  @override
  State<HarmonyPatternPage> createState() => _HarmonyPatternPageState();
}

class _HarmonyPatternPageState extends State<HarmonyPatternPage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);

  late PatternRound _round;
  final List<Chord> _attempt = [];
  List<bool>? _matches;

  _Phase _phase = _Phase.playing;
  int? _eventIndex;
  int _index = 0;
  int _correct = 0;
  final List<String> _mistakes = [];

  int get _total => widget.questionCount ?? widget.lesson.questionCount;

  bool get _isPerfect => _matches != null && _matches!.every((m) => m);

  @override
  void initState() {
    super.initState();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playPhrase());
  }

  @override
  void dispose() {
    _phrasePlayer.cancel();
    super.dispose();
  }

  void _newRound() {
    _round = generatePatternRound(
      tonic: harmonyTonic(varyKey: widget.lesson.varyKey, rng: _rng),
      rng: _rng,
      length: widget.lesson.patternLength,
      decoyCount: widget.lesson.decoyCount,
    );
    _attempt.clear();
    _matches = null;
    _phase = _Phase.playing;
    _eventIndex = null;
  }

  Future<void> _playPhrase() async {
    setState(() {
      _eventIndex = null;
      if (_phase != _Phase.answered) _phase = _Phase.playing;
    });
    await _phrasePlayer.play(
      _round.phrase,
      onEvent: (i) {
        if (mounted) setState(() => _eventIndex = i);
      },
    );
    if (!mounted) return;
    setState(() {
      _eventIndex = null;
      if (_phase == _Phase.playing) _phase = _Phase.answering;
    });
  }

  /// Palet taşı: akoru çalar ve sıradaki boş yuvaya yerleştirir.
  Future<void> _place(Chord chord) async {
    if (_phase != _Phase.answering ||
        _attempt.length >= _round.sequence.length) {
      return;
    }
    setState(() => _attempt.add(chord));
    await widget.player.playChord(bandVoicing(chord));
    if (_attempt.length == _round.sequence.length) _evaluate();
  }

  void _undo() {
    if (_phase != _Phase.answering || _attempt.isEmpty) return;
    setState(_attempt.removeLast);
  }

  void _evaluate() {
    final matches = [
      for (var i = 0; i < _round.sequence.length; i++)
        i < _attempt.length && _attempt[i] == _round.sequence[i],
    ];
    for (var i = 0; i < matches.length; i++) {
      if (!matches[i] && i < _attempt.length) {
        // Dil-BAĞIMSIZ karıştırma anahtarı (akor sembolleri çevrilmez).
        _mistakes.add(
          'progression:${shortChordName(_round.sequence[i])}'
          '>${shortChordName(_attempt[i])}',
        );
      }
    }
    setState(() {
      _matches = matches;
      _phase = _Phase.answered;
      if (matches.every((m) => m)) _correct++;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _attempt.clear();
      _matches = null;
      _phase = _Phase.playing;
    });
    await _playPhrase();
  }

  Future<void> _next() async {
    if (_index + 1 >= _total) {
      widget.onComplete(LessonResult(_correct, _total, mistakes: _mistakes));
      return;
    }
    setState(() {
      _index++;
      _newRound();
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) _playPhrase();
  }

  // --- Görünüm ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final progress = (_index + (_phase == _Phase.answered ? 1 : 0)) / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Pattern ${_index + 1} / $total',
            tr: 'Kalıp ${_index + 1} / $total',
          ),
        ),
        actions: [
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
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                _prompt(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              PlayButton(
                onTap: _playPhrase,
                playing: _phase == _Phase.playing,
                size: 84,
                iconSize: 36,
              ),
              const SizedBox(height: 8),
              PhraseDots(
                count: _round.phrase.events.length,
                activeIndex: _eventIndex,
                semanticsLabel: t(en: 'Pattern', tr: 'Kalıp'),
              ),
              const SizedBox(height: 14),
              _slotRow(theme),
              const Spacer(),
              if (_phase == _Phase.answered)
                _resultArea(theme)
              else
                _paletteArea(theme),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt() => switch (_phase) {
    _Phase.playing => t(en: 'Listen…', tr: 'Dinle…'),
    _Phase.answering => t(
      en: 'Lay the chords out in order',
      tr: 'Akorları sırayla diz',
    ),
    _Phase.answered => _isPerfect
        ? t(en: 'You cracked it!', tr: 'Çözdün!')
        : t(en: 'Close — listen again', tr: 'Az kaldı — tekrar dinle'),
  };

  /// Dört yuva: kullanıcının dizdiği sıra (cevaptan sonra renklenir).
  Widget _slotRow(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _round.sequence.length; i++)
            Container(
              width: 64,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _slotColor(theme, i),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: i < _attempt.length
                  ? ChordLabel(
                      _attempt[i],
                      color: _matches != null ? Colors.white : AppColors.ink,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Color _slotColor(ThemeData theme, int index) {
    final matches = _matches;
    if (matches != null) {
      return matches[index] ? AppColors.success : AppColors.danger;
    }
    if (index < _attempt.length) return AppColors.grapeSoft;
    return theme.colorScheme.surfaceContainerHighest;
  }

  Widget _paletteArea(ThemeData theme) {
    final palette = _round.palette;
    // Palet 2 ile 6 taş arasında değişir (tuzaklı derste en kalabalık). Tek
    // sıraya sıkıştırmak yerine satır başına en fazla 4 taş: altı taş tek
    // sırada dokunma hedefini parmak ucundan küçük yapardı.
    const spacing = 6.0;
    final perRow = palette.length <= 4 ? palette.length : 3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: [
                for (final chord in palette)
                  SizedBox(width: width, child: _paletteTile(theme, chord)),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _attempt.isEmpty ? null : _undo,
          icon: const Icon(Icons.backspace_outlined, size: 18),
          label: Text(t(en: 'Undo', tr: 'Geri al')),
        ),
      ],
    );
  }

  Widget _paletteTile(ThemeData theme, Chord chord) {
    return Semantics(
      button: true,
      label: fullChordName(chord),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering ? () => _place(chord) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: ChordLabel(chord, color: AppColors.ink),
          ),
        ),
      ),
    );
  }

  Widget _resultArea(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isPerfect)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              t(
                en: 'It was: '
                    '${_round.sequence.map(fullChordName).join(' · ')}',
                tr: 'Kalıp şuydu: '
                    '${_round.sequence.map(fullChordName).join(' · ')}',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(t(en: 'Try again', tr: 'Tekrar dene')),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _next,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _index + 1 >= _total
                        ? t(en: 'Finish', tr: 'Bitir')
                        : t(en: 'Next', tr: 'Sonraki'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
