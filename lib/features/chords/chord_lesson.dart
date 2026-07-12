import '../../core/chord.dart';
import '../../core/note.dart';

/// Bir akor dersinde tanıma (test) aşamasının neyi sorduğu.
enum ChordRecognizeBy {
  /// Spesifik akoru sor ("Bu hangi akor?" / notaları). Varsayılan.
  chord,

  /// Akorun niteliğini/rengini sor ("Bu ne niteliği?": majör/minör/eksik/artık).
  /// Kökten bağımsız renk kulağını eğitir.
  quality,
}

/// Bir akor dersi = kimlik + başlık + o derste öğretilen akorlar havuzu.
/// Nota dersleri gibi akor akor ilerler; bir ders geçilince sonraki açılır.
class ChordLesson {
  final String id;
  final String title;
  final List<Chord> pool;
  final ChordRecognizeBy recognizeBy;
  const ChordLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.recognizeBy = ChordRecognizeBy.chord,
  });
}

Chord _c(String root, ChordQuality quality, [int octave = 4]) =>
    Chord(Note.fromName(root, octave), quality);

/// Akor müfredatı — kolaydan zora, akor akor. (İleride tüm kök × nitelik ×
/// oktava genişletilecek — bkz. proje kapsam hedefi.)
final List<ChordLesson> chordLessons = [
  ChordLesson(
    id: 'ch1',
    title: '1 · C Majör & A Minör',
    pool: [_c('C', ChordQuality.major), _c('A', ChordQuality.minor)],
  ),
  ChordLesson(
    id: 'ch2',
    title: '2 · F & G Majör',
    pool: [_c('F', ChordQuality.major), _c('G', ChordQuality.major)],
  ),
  ChordLesson(
    id: 'ch3',
    title: '3 · D & E Minör',
    pool: [_c('D', ChordQuality.minor), _c('E', ChordQuality.minor)],
  ),
  ChordLesson(
    id: 'ch4',
    title: '4 · Karışık Akorlar',
    pool: [
      _c('C', ChordQuality.major),
      _c('A', ChordQuality.minor),
      _c('F', ChordQuality.major),
      _c('G', ChordQuality.major),
    ],
  ),
  // A1 — akor kapsamı: dört nitelik (renk) tanıma.
  ChordLesson(
    id: 'ch5',
    title: '5 · Eksik & Artık',
    recognizeBy: ChordRecognizeBy.quality,
    // Aynı kök (C) üstünde dört renk yan yana → kontrastı net duy.
    pool: [
      _c('C', ChordQuality.major),
      _c('C', ChordQuality.minor),
      _c('C', ChordQuality.diminished),
      _c('C', ChordQuality.augmented),
    ],
  ),
  ChordLesson(
    id: 'ch6',
    title: '6 · Renkleri Ayırt Et',
    recognizeBy: ChordRecognizeBy.quality,
    // Karışık kök × nitelik → rengi kökten bağımsız tanı.
    pool: [
      _c('C', ChordQuality.major),
      _c('G', ChordQuality.major),
      _c('A', ChordQuality.minor),
      _c('E', ChordQuality.minor),
      _c('B', ChordQuality.diminished),
      _c('D', ChordQuality.diminished),
      _c('F', ChordQuality.augmented),
      _c('C', ChordQuality.augmented),
    ],
  ),
];
