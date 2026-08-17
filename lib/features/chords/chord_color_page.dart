import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/phrase_dots.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'chord_lesson.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKOR RENGİ — ALGI EKRANI (dersler 1, 2, 6, 7, 8)
//
// "Hangisi parlak? · Parlak mı hüzünlü mü? · Gergin renkler · Üç mü dört mü?"
// Hepsi aynı mekanik: dinle, şıklardan birini seç.
//
// KALDIRILAN ESKİ EKRANDAN FARKI: soru artık bir TERİM sormuyor. Eskiden
// "Bu hangi nitelik?" deyip Majör/Minör/Eksik/Artık şıkları veriliyordu —
// kullanıcı önce kelimeyi öğrenmek zorundaydı. Şimdi "parlak mı, hüzünlü mü"
// diye soruluyor; kelime dersin SONUNDA rozet olarak geliyor. Aynı algı, ama
// önce yaşanıyor sonra adlandırılıyor.
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class ChordColorPage extends StatefulWidget {
  const ChordColorPage({
    super.key,
    required this.lesson,
    required this.player,
    required this.onComplete,
    this.questionCount,
  });

  final ChordLesson lesson;
  final NotePlayer player;
  final void Function(LessonResult result) onComplete;

  /// Soru sayısını dersin varsayılanı yerine dışarıdan belirler (Sonsuz Pratik
  /// ve tekrar oturumu kısa turlar ister).
  final int? questionCount;

  @override
  State<ChordColorPage> createState() => _ChordColorPageState();
}

class _ChordColorPageState extends State<ChordColorPage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);

  late ChordChoiceRound _round;
  _Phase _phase = _Phase.playing;
  int? _eventIndex;
  int? _picked;

  int _index = 0;
  int _correct = 0;
  final List<String> _mistakes = [];

  int get _total => widget.questionCount ?? widget.lesson.questionCount;

  bool get _isCorrect => _picked == _round.answer;

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
    _round = generateChordChoice(drill: widget.lesson.drill, rng: _rng);
    _phase = _Phase.playing;
    _eventIndex = null;
    _picked = null;
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

  void _pick(int index) {
    if (_phase != _Phase.answering) return;
    setState(() {
      _picked = index;
      _phase = _Phase.answered;
      if (index == _round.answer) {
        _correct++;
      } else {
        // Dil-BAĞIMSIZ karıştırma anahtarı ('color:bright>dark').
        _mistakes.add(
          'color:${_round.optionKeys[_round.answer]}>${_round.optionKeys[index]}',
        );
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final progress = (_index + (_phase == _Phase.answered ? 1 : 0)) / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            en: 'Chord ${_index + 1} / $total',
            tr: 'Akor ${_index + 1} / $total',
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
              const SizedBox(height: 16),
              PlayButton(
                onTap: _playPhrase,
                playing: _phase == _Phase.playing,
                size: 92,
                iconSize: 40,
              ),
              // Tek akorlu sorularda nokta göstermek bilgi taşımaz; yalnızca
              // iki akorun karşılaştırıldığı derste "hangisindeyiz" lazım.
              if (_round.phrase.events.length > 1) ...[
                const SizedBox(height: 12),
                PhraseDots(
                  count: _round.phrase.events.length,
                  activeIndex: _eventIndex,
                  semanticsLabel: t(en: 'Chords', tr: 'Akorlar'),
                ),
              ],
              const Spacer(),
              _options(theme),
              const SizedBox(height: 12),
              if (_phase == _Phase.answered) _resultArea(theme),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt() {
    if (_phase == _Phase.playing) return t(en: 'Listen…', tr: 'Dinle…');
    if (_phase == _Phase.answered) {
      return _isCorrect
          ? t(en: 'Exactly right!', tr: 'Tam isabet!')
          : t(en: 'Not this time — listen again', tr: 'Olmadı — tekrar dinle');
    }
    return switch (widget.lesson.drill) {
      ChordDrill.brighter => t(
        en: 'Which one sounded brighter?',
        tr: 'Hangisi daha parlak duyuldu?',
      ),
      ChordDrill.countTones => t(
        en: 'How many notes were stacked up?',
        tr: 'Üst üste kaç ses vardı?',
      ),
      _ => t(en: 'What did that chord feel like?', tr: 'Bu akor nasıl geldi?'),
    };
  }

  /// Şıklar: iki tanesi alt alta, dört tanesi 2×2 ızgara. Metin okunmadan da
  /// anlaşılsın diye her şıkta ikon var.
  Widget _options(ThemeData theme) {
    final keys = _round.optionKeys;
    if (keys.length <= 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _optionTile(theme, i, keys[i]),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row * 2 < keys.length; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 10),
                Expanded(
                  child: row * 2 + col < keys.length
                      ? _optionTile(theme, row * 2 + col, keys[row * 2 + col])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _optionTile(ThemeData theme, int index, String key) {
    final answered = _phase == _Phase.answered;
    // Cevaptan sonra DOĞRU şık her zaman yeşile döner (kullanıcı yanlış seçse
    // bile doğruyu görür); seçtiği yanlış şık kırmızıya.
    final isAnswer = index == _round.answer;
    final isPicked = index == _picked;

    final Color background;
    final Color foreground;
    if (answered && isAnswer) {
      background = AppColors.success;
      foreground = Colors.white;
    } else if (answered && isPicked) {
      background = AppColors.danger;
      foreground = Colors.white;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = AppColors.ink;
    }

    return Semantics(
      button: true,
      label: chordOptionLabel(key),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering ? () => _pick(index) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(chordOptionIcon(key), color: foreground, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      chordOptionLabel(key),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultArea(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _playPhrase,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t(en: 'Hear it again', tr: 'Tekrar dinle')),
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
    );
  }
}
