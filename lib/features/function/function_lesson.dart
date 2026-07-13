import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// AKOR İŞLEVİ — bir tonalitede akorun "görevi"
//
// Sadelik için sabit Do majör tonalitesinde çalışırız. Her derece bir akora,
// bir Roman rakamına ve bir işleve (Tonik / Subdominant / Dominant) karşılık gelir.
// Öğretimde önce TONİK (ev) çalınır, sonra hedef akor — kulak "çekimi" hisseder.
// -----------------------------------------------------------------------------

/// Armonik işlev (sınıf).
enum HarmonicFunction { tonic, subdominant, dominant }

extension HarmonicFunctionLabel on HarmonicFunction {
  String get label => switch (this) {
        HarmonicFunction.tonic => 'Tonik',
        HarmonicFunction.subdominant => 'Subdominant',
        HarmonicFunction.dominant => 'Dominant',
      };
}

/// Bir derece = akor + Roman rakamı + işlev.
class DegreeChord {
  final Chord chord;
  final String roman;
  final HarmonicFunction function;
  const DegreeChord(this.chord, this.roman, this.function);
}

/// Do majör tonik referansı (ev). Hedef akordan önce çalınır.
final Chord tonicReference = Chord(Note.fromName('C', 4), ChordQuality.major);

DegreeChord _d(String root, ChordQuality q, String roman, HarmonicFunction f) =>
    DegreeChord(Chord(Note.fromName(root, 4), q), roman, f);

/// Do majör dereceleri.
final DegreeChord degI = _d('C', ChordQuality.major, 'I', HarmonicFunction.tonic);
final DegreeChord degII =
    _d('D', ChordQuality.minor, 'ii', HarmonicFunction.subdominant);
final DegreeChord degIII =
    _d('E', ChordQuality.minor, 'iii', HarmonicFunction.tonic);
final DegreeChord degIV =
    _d('F', ChordQuality.major, 'IV', HarmonicFunction.subdominant);
final DegreeChord degV =
    _d('G', ChordQuality.major, 'V', HarmonicFunction.dominant);
final DegreeChord degVI =
    _d('A', ChordQuality.minor, 'vi', HarmonicFunction.tonic);
final DegreeChord degVII =
    _d('B', ChordQuality.diminished, 'vii°', HarmonicFunction.dominant);

class FunctionLesson {
  final String id;
  final String title;
  final List<DegreeChord> pool;
  final Concept? concept;
  const FunctionLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
  });
}

final List<FunctionLesson> functionLessons = [
  FunctionLesson(
    id: 'fn1',
    title: '1 · Üç Temel İşlev',
    pool: [degI, degIV, degV], // birer temsilci: Tonik, Subdominant, Dominant
    concept: const Concept(
      title: 'Akorun İşlevi',
      sections: [
        ConceptSection(
          'Bir tonalitede (ör. Do majör) her akorun bir "görevi" vardır: nereye '
          'ait, kulağı nereye çekiyor?',
        ),
        ConceptSection(
          heading: 'Tonik (ev)',
          'Huzur, varış, dinlenme. Do majör\'de I (C akoru).',
        ),
        ConceptSection(
          heading: 'Subdominant',
          'Evden uzaklaşma, hareket hissi. IV (F akoru).',
        ),
        ConceptSection(
          heading: 'Dominant',
          'Gerilim ve "eve dönme" isteği. V (G akoru) → tonike çözülmek ister.',
        ),
        ConceptSection(
          heading: 'Nasıl?',
          'Önce tonik (ev) çalınır, sonra hedef akor. Aradaki "çekimi" dinle.',
        ),
      ],
    ),
  ),
  FunctionLesson(
    id: 'fn2',
    title: '2 · Tüm Dereceler',
    pool: [degI, degII, degIII, degIV, degV, degVI, degVII],
    concept: const Concept(
      title: 'Yedi Derece, Üç İşlev',
      sections: [
        ConceptSection(
          'Do majör\'ün yedi akoru üç işlev ailesine ayrılır.',
        ),
        ConceptSection(
          heading: 'Aileler',
          'Tonik: I, iii, vi · Subdominant: IV, ii · Dominant: V, vii°.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Akoru, kökünü düşünmeden doğru işlev ailesine yerleştirmek.',
        ),
      ],
    ),
  ),
];
