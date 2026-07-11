import '../../core/chord.dart';
import '../../core/note.dart';

/// Bir akor dersi = kimlik + başlık + o derste öğretilen akorlar havuzu.
/// Nota dersleri gibi akor akor ilerler; bir ders geçilince sonraki açılır.
class ChordLesson {
  final String id;
  final String title;
  final List<Chord> pool;
  const ChordLesson({required this.id, required this.title, required this.pool});
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
];
