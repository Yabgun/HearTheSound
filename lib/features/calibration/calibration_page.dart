import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/note_player.dart';
import '../../audio/pitch_service.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';
import '../../core/vocal_range.dart';
import '../../state/progress_controller.dart';
import '../../ui/app_icons.dart';
import '../../ui/app_theme.dart';
import '../../ui/pitch_meter.dart';

// -----------------------------------------------------------------------------
// SES ARALIĞI KALİBRASYONU — rehberli tırmanış
//
// Amaç: kullanıcının RAHAT ([comfortLow, comfortHigh]) ve ZORLAYARAK ulaştığı
// ([stretchLow, stretchHigh]) aralığını ölçmek. Dersler bu aralığa göre kendi
// oktavına iner (bkz. octave_mapping.dart) → tiz notalarda zorlanma sorunu çözülür.
//
// Akış: güvenli bir orta notadan (çapa) başla.
//   1) AŞAĞI yürü: her adımda notayı çal → kullanıcı söyler → "nasıldı?" (Rahat /
//      Zorlandım / Çıkaramıyorum). En pes sınıra kadar in.
//   2) YUKARI yürü: çapanın bir üstünden başlayıp aynı şekilde en tize çık.
// Sınırlar kullanıcının kendi konfor beyanıyla belirlenir; perde tespiti sadece
// notayı gerçekten söylediğini doğrular (boş/yanlış onayı engeller).
// -----------------------------------------------------------------------------

/// Ekranın ana aşaması.
enum _Stage { intro, walk, result, permissionDenied }

/// Tırmanış yönü.
enum _Dir { down, up }

class CalibrationPage extends ConsumerStatefulWidget {
  const CalibrationPage({super.key});

  @override
  ConsumerState<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends ConsumerState<CalibrationPage> {
  // Çapa: çoğu eğitimsiz ses için rahat bir orta nokta (A3 = 220 Hz).
  static final int _anchor = Note.fromName('A', 3).midi;
  // Adım boyu: tam ton (2 yarım-ses) — yürüyüşü kısa tutar, oktav eşleme için
  // bu çözünürlük yeterli (nasılsa tam oktavlarla kaydırıyoruz).
  static const int _step = 2;
  // Güvenlik sınırları: bu notaların ötesine yürümeyi otomatik durdur.
  static final int _floor = Note.fromName('C', 2).midi; // 36
  static final int _ceil = Note.fromName('C', 6).midi; // 84
  // Doğru notayı bu kadar süre tutunca "söyledi" sayılır.
  static const Duration _holdTarget = Duration(milliseconds: 900);

  static const Color _green = AppColors.success;

  final PitchService _pitch = PitchService();
  final NotePlayer _player = createNotePlayer();

  _Stage _stage = _Stage.intro;
  _Dir _dir = _Dir.down;
  int _target = 0;

  // Ölçülen sınırlar (MIDI). Çapa her ikisine de dahil sayılır (geçerli taban).
  late int _comfortLow;
  late int _comfortHigh;
  late int _stretchLow;
  late int _stretchHigh;

  bool _micActive = false;
  bool _matched = false; // kullanıcı hedef notayı söylemeyi başardı mı
  bool _busy = false; // referans çalıp mikrofonu başlatma arası
  NoteReading? _reading;
  double _hold = 0;
  DateTime? _lastTick;

  VocalRange get _measured => VocalRange.clamped(
    comfortLow: _comfortLow,
    comfortHigh: _comfortHigh,
    stretchLow: _stretchLow,
    stretchHigh: _stretchHigh,
    calibratedAt: DateTime.now(),
  );

  // ---- Akış kontrolü --------------------------------------------------------

  /// "Başla" — izni tetikle, sınırları çapaya ata, aşağı yürüyüşü başlat.
  Future<void> _begin() async {
    _comfortLow = _comfortHigh = _anchor;
    _stretchLow = _stretchHigh = _anchor;
    _dir = _Dir.down;
    _target = _anchor;
    setState(() => _stage = _Stage.walk);
    await _startStep();
  }

  /// Bir adım: referansı çal (mikrofon kapalı), bitince mikrofonu başlat.
  Future<void> _startStep() async {
    if (!mounted) return;
    setState(() {
      _matched = false;
      _reading = null;
      _hold = 0;
      _micActive = false;
      _busy = true;
    });
    await _player.play(Note(_target));
    // Referans notasının bitmesini bekle, sonra çalmayı kesip mikrofonu aç
    // (aynı anda hem çalıp hem dinleyince ses hattı çakışıyor).
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    await _startListening();
  }

  Future<void> _startListening() async {
    await _player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final ok = await _pitch.start(_onReading);
    if (!ok) {
      if (mounted) setState(() => _stage = _Stage.permissionDenied);
      return;
    }
    _lastTick = null;
    if (mounted) {
      setState(() {
        _micActive = true;
        _busy = false;
        _hold = 0;
      });
    }
  }

  /// Referansı tekrar çal (mikrofonu kısa süre durdurup).
  Future<void> _replay() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_micActive) await _pitch.stop();
    if (mounted) setState(() => _micActive = false);
    await _player.play(Note(_target));
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    if (_matched) {
      setState(() => _busy = false); // eşleşmişti, dinlemeye dönme
    } else {
      await _startListening();
    }
  }

  void _onReading(NoteReading? r) {
    if (!_micActive || _matched || !mounted) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds /
              _holdTarget.inMilliseconds;
    _lastTick = now;
    final match = r != null && r.note.midi == _target;
    setState(() {
      _reading = r;
      _hold = (_hold + (match ? dt : -dt * 0.5)).clamp(0.0, 1.0);
    });
    if (_hold >= 1.0) _onMatched();
  }

  /// Hedef nota yeterince tutuldu → "söyledi" say, konfor sorusuna geç.
  Future<void> _onMatched() async {
    if (_matched) return;
    setState(() {
      _matched = true;
      _micActive = false;
    });
    await _pitch.stop();
  }

  /// "Rahat" — bu notayı hem rahat hem esneme sınırı olarak kaydet, dışarı yürü.
  void _answerComfortable() {
    if (_dir == _Dir.down) {
      _comfortLow = _target < _comfortLow ? _target : _comfortLow;
      _stretchLow = _target < _stretchLow ? _target : _stretchLow;
    } else {
      _comfortHigh = _target > _comfortHigh ? _target : _comfortHigh;
      _stretchHigh = _target > _stretchHigh ? _target : _stretchHigh;
    }
    _advance();
  }

  /// "Zorlandım ama çıktı" — sadece esneme sınırı; bu yönü burada bitir.
  void _answerStrain() {
    if (_dir == _Dir.down) {
      _stretchLow = _target < _stretchLow ? _target : _stretchLow;
    } else {
      _stretchHigh = _target > _stretchHigh ? _target : _stretchHigh;
    }
    _endDirection();
  }

  /// "Çıkaramıyorum" — mevcut notayı kaydetme, bu yönü bitir.
  void _answerCantReach() => _endDirection();

  /// Bir sonraki (dışarı) notaya geç; sınıra dayandıysak yönü bitir.
  Future<void> _advance() async {
    final next = _dir == _Dir.down ? _target - _step : _target + _step;
    final past = _dir == _Dir.down ? next < _floor : next > _ceil;
    if (past) {
      _endDirection();
      return;
    }
    _target = next;
    await _startStep();
  }

  /// Bu yönü bitir: aşağıysa yukarıya geç, yukarıysa sonucu göster.
  Future<void> _endDirection() async {
    await _pitch.stop();
    if (!mounted) return;
    if (_dir == _Dir.down) {
      _dir = _Dir.up;
      _target = _anchor + _step;
      if (_target > _ceil) {
        _toResult();
      } else {
        await _startStep();
      }
    } else {
      _toResult();
    }
  }

  void _toResult() {
    setState(() {
      _stage = _Stage.result;
      _micActive = false;
    });
  }

  Future<void> _save() async {
    final range = _measured;
    ref.read(progressProvider.notifier).setVocalRange(range);
    if (mounted) Navigator.of(context).pop(range);
  }

  @override
  void dispose() {
    _pitch.dispose();
    _player.dispose();
    super.dispose();
  }

  // ---- Arayüz ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(en: 'Your vocal range', tr: 'Ses aralığın')),
        actions: [
          if (_stage == _Stage.walk)
            TextButton(
              onPressed: _endDirection,
              child: Text(t(en: "That's enough", tr: 'Bu kadar')),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.intro => _buildIntro(context),
          _Stage.walk => _buildWalk(context),
          _Stage.result => _buildResult(context),
          _Stage.permissionDenied => _buildPermissionDenied(context),
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.graphic_eq_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            t(en: "Let's get to know your voice", tr: 'Sesini tanıyalım'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            t(
              en:
                  "I'll play you notes and you'll sing them back. Each time "
                  "I'll ask “was that comfortable, or a strain?” That way I "
                  'can set your lessons in exactly the octave you sing '
                  'comfortably — no choking on the high notes.',
              tr:
                  'Sana notalar çalacağım, sen de tekrar söyleyeceksin. Her '
                  'seferinde “rahat mıydı, zorlandın mı?” diye soracağım. '
                  'Böylece dersleri tam senin rahat söyleyebildiğin oktavda '
                  'hazırlarım — tiz notalarda boğulmazsın.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              en: 'Takes ~1 minute in a quiet spot, with mic permission.',
              tr: 'Sessiz bir yerde, mikrofon izniyle ~1 dakika sürer.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _begin,
              icon: const Icon(Icons.mic_rounded),
              label: Text(t(en: 'Start', tr: 'Başla')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(en: 'Skip for now', tr: 'Şimdilik atla')),
          ),
        ],
      ),
    );
  }

  Widget _buildWalk(BuildContext context) {
    final theme = Theme.of(context);
    final target = Note(_target);
    final goalText = _dir == _Dir.down
        ? t(en: 'FINDING YOUR LOWEST NOTE', tr: 'EN PES NOTANI BULUYORUZ')
        : t(en: 'FINDING YOUR HIGHEST NOTE', tr: 'EN TİZ NOTANI BULUYORUZ');

    final exact = _reading != null && _reading!.note.midi == _target;
    final ringColor = (_matched || exact) ? _green : theme.colorScheme.primary;

    final String status;
    if (_matched) {
      status = t(
        en: 'You sang it ✓  So how did it feel?',
        tr: 'Söyledin ✓  Peki nasıl geldi?',
      );
    } else if (_busy) {
      status = t(en: 'Listen…', tr: 'Dinle…');
    } else if (exact) {
      status = t(en: 'spot on — hold it!', tr: 'tam — böyle tut!');
    } else if (_reading != null) {
      status = t(
        en: 'I hear: ${_reading!.note.label}',
        tr: 'duyduğum: ${_reading!.note.label}',
      );
    } else {
      status = t(en: 'now you sing it 👇', tr: 'şimdi sen söyle 👇');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            goalText,
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            t(en: 'SING THIS NOTE', tr: 'BU NOTAYI SÖYLE'),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            target.label,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 76,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _replay,
            icon: const Icon(Icons.volume_up_rounded),
            label: Text(t(en: 'Listen again', tr: 'Tekrar dinle')),
          ),
          const Spacer(),
          SizedBox(
            width: 148,
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: CircularProgressIndicator(
                    value: _matched ? 1 : _hold,
                    strokeWidth: 9,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(ringColor),
                  ),
                ),
                Icon(
                  _matched ? Icons.check_rounded : Icons.mic_rounded,
                  size: 54,
                  color: _matched
                      ? _green
                      : (_micActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            status,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: (_matched || exact)
                  ? _green
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Canlı perde ibresi — derslerin "söyle" ekranlarıyla AYNI çubuk.
          // Söylenen sesin hedefe göre tam nerede olduğunu (cent sapması) ve
          // hangi notaya denk geldiğini canlı gösterir; kalibrasyonu derslerle
          // aynı netliğe taşır (kullanıcı geri bildirimi: bu çubuk çok daha anlaşılır).
          PitchMeter(target: target, reading: _reading, active: _micActive),
          const Spacer(flex: 2),
          // Eylem alanı: notayı söyleyene kadar sadece "çıkaramıyorum";
          // söyledikten sonra konfor sorusu.
          if (_matched) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _answerComfortable,
                    icon: const Icon(AppIcons.comfortable, size: 20),
                    label: Text(t(en: 'Comfortable', tr: 'Rahattı')),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _answerStrain,
                    icon: const Icon(AppIcons.strained, size: 20),
                    label: Text(t(en: 'It was hard', tr: 'Zorlandım')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _answerCantReach,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _dir == _Dir.down
                      ? t(en: "Can't go this low", tr: 'Bu notaya inemiyorum')
                      : t(
                          en: "Can't go this high",
                          tr: 'Bu notaya çıkamıyorum',
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final r = _measured;
    final hasStretch =
        r.stretchLow < r.comfortLow || r.stretchHigh > r.comfortHigh;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.check_circle_rounded, size: 64, color: _green),
          const SizedBox(height: 20),
          Text(
            t(en: 'Your vocal range is ready', tr: 'Ses aralığın hazır'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _rangeRow(
            theme,
            t(en: 'Comfortable', tr: 'Rahat'),
            '${r.comfortLowNote.label} – ${r.comfortHighNote.label}',
          ),
          if (hasStretch) ...[
            const SizedBox(height: 10),
            _rangeRow(
              theme,
              t(en: 'Pushing it', tr: 'Zorlayarak'),
              '${Note(r.stretchLow).label} – ${Note(r.stretchHigh).label}',
            ),
          ],
          const SizedBox(height: 20),
          Text(
            t(
              en:
                  "I'll build your lessons around this range. You can "
                  're-measure anytime from Settings.',
              tr:
                  'Dersleri bu aralığa göre hazırlayacağım. İstediğin zaman '
                  'Ayarlar’dan yeniden ölçebilirsin.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(t(en: 'Save', tr: 'Kaydet')),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _begin,
            child: Text(t(en: 'Measure again', tr: 'Baştan ölç')),
          ),
        ],
      ),
    );
  }

  Widget _rangeRow(ThemeData theme, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              t(
                en: 'Calibration needs microphone permission.',
                tr: 'Kalibrasyon için mikrofon izni gerekli.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() => _stage = _Stage.walk);
                _startStep();
              },
              child: Text(
                t(en: 'Allow and try again', tr: 'İzin ver ve tekrar dene'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(en: 'Cancel', tr: 'Vazgeç')),
            ),
          ],
        ),
      ),
    );
  }
}
