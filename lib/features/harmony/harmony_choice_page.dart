import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../audio/phrase_player.dart';
import '../../core/content_locale.dart';
import '../../ui/app_theme.dart';
import '../../ui/phrase_dots.dart';
import '../../ui/play_button.dart';
import '../lesson/lesson.dart';
import 'harmony_lesson.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ — İKİ SEÇENEKLİ ALGI EKRANI (dersler 1, 2, 3)
//
// "Kaç ses? · Değişti mi? · Bas nereye gitti?" — üçü de aynı mekanik: dinle,
// iki şıktan birini seç.
//
// Bunun kaldırılan teori derslerinden farkı KRİTİK: burada sorulan şey bir
// YORUM değil ALGIdır ve cevabı çalan sesin İÇİNDEDİR. "Bu kaçıncı derece?"
// bilgi ister, "dinlendi mi?" yorum ister; "bas yukarı mı indi mi?" yalnızca
// kulak ister — hiçbir terim bilmeden, 6 yaşında bir çocuk da cevaplayabilir.
// (Cihaz testinde "dinlendi mi?" tipi soruların reddedilme sebebi tam olarak
// buydu; bkz. harmony_lesson.dart başlığı.) Şıklar ikonlu ki metin okunmadan
// da anlaşılsın.
// -----------------------------------------------------------------------------

enum _Phase { playing, answering, answered }

class HarmonyChoicePage extends StatefulWidget {
  const HarmonyChoicePage({
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
  State<HarmonyChoicePage> createState() => _HarmonyChoicePageState();
}

class _HarmonyChoicePageState extends State<HarmonyChoicePage> {
  final Random _rng = Random();
  late final PhrasePlayer _phrasePlayer = PhrasePlayer(widget.player);

  late ChoiceRound _round;
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
    _round = generateChoiceRound(
      drill: widget.lesson.drill,
      tonic: harmonyTonic(varyKey: widget.lesson.varyKey, rng: _rng),
      degrees: widget.lesson.degrees,
      rng: _rng,
    );
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
      // Cevap zaten verildiyse (tekrar dinleme) sonuç ekranında kal.
      if (_phase == _Phase.playing) _phase = _Phase.answering;
    });
  }

  void _pick(int index) {
    if (_phase != _Phase.answering) return;
    final keys = choiceKeysOf(widget.lesson.drill);
    setState(() {
      _picked = index;
      _phase = _Phase.answered;
      if (index == _round.answer) {
        _correct++;
      } else {
        // Dil-BAĞIMSIZ karıştırma anahtarı ('harmony:up>down'): kullanıcı dil
        // değiştirince "en çok karıştırdıkların" istatistiği bozulmasın.
        _mistakes.add('harmony:${keys[_round.answer]}>${keys[index]}');
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
            en: 'Question ${_index + 1} / $total',
            tr: 'Soru ${_index + 1} / $total',
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
                size: 96,
                iconSize: 42,
              ),
              const SizedBox(height: 12),
              PhraseDots(
                count: _round.phrase.events.length,
                activeIndex: _eventIndex,
                semanticsLabel: t(en: 'Sounds', tr: 'Sesler'),
              ),
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

  /// Ekranın üstündeki tek satırlık soru — her ders kendi cümlesini kullanır ki
  /// kullanıcı "şu an ne yapıyorum" sorusunu okumadan yaşasın.
  String _prompt() {
    if (_phase == _Phase.playing) return t(en: 'Listen…', tr: 'Dinle…');
    if (_phase == _Phase.answered) {
      return _isCorrect
          ? t(en: 'Exactly right!', tr: 'Tam isabet!')
          : t(en: 'Not this time — listen again', tr: 'Olmadı — tekrar dinle');
    }
    return switch (widget.lesson.drill) {
      HarmonyDrill.howMany => t(
        en: 'How many notes sounded together?',
        tr: 'Aynı anda kaç ses çaldı?',
      ),
      HarmonyDrill.changed => t(
        en: 'Did the second one change?',
        tr: 'İkincisi değişti mi?',
      ),
      HarmonyDrill.bassDirection => t(
        en: 'Where did the lowest note go?',
        tr: 'En pes ses nereye gitti?',
      ),
      _ => '',
    };
  }

  Widget _options(ThemeData theme) {
    final labels = choiceLabelsOf(widget.lesson.drill);
    final icons = choiceIconsOf(widget.lesson.drill);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _optionTile(theme, i, labels[i], icons[i]),
        ],
      ],
    );
  }

  Widget _optionTile(ThemeData theme, int index, String label, IconData icon) {
    final answered = _phase == _Phase.answered;
    // Cevaptan sonra DOĞRU şık her zaman yeşile döner (kullanıcı yanlış seçse
    // bile doğruyu görür); seçtiği yanlış şık kırmızıya.
    final isAnswer = index == _round.answer;
    final isPicked = index == _picked;

    final Color background;
    final Color foreground;
    if (answered && isAnswer) {
      background = context.colors.success;
      foreground = context.colors.onSuccess;
    } else if (answered && isPicked) {
      background = context.colors.danger;
      foreground = context.colors.onDanger;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = context.colors.ink;
    }

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _phase == _Phase.answering ? () => _pick(index) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      label,
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
