import '../../core/chord.dart';
import '../../core/concept.dart';
import '../function/function_lesson.dart';

// -----------------------------------------------------------------------------
// AKOR İLERLEMELERİ — akorların sırayla dizilişi
//
// Do majör derecelerinden (function_lesson'daki degI..degVII) diziler kurulur.
// Şarkıların "iskeleti"; kullanıcı diziyi dinleyip hangi kalıp olduğunu tanır.
// -----------------------------------------------------------------------------

class Progression {
  final String name; // "I – IV – V – I"
  final List<Chord> chords;
  const Progression(this.name, this.chords);
}

Progression _p(String name, List<DegreeChord> degrees) =>
    Progression(name, [for (final d in degrees) d.chord]);

class ProgressionLesson {
  final String id;
  final String title;
  final List<Progression> pool;
  final Concept? concept;
  const ProgressionLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
  });
}

final List<ProgressionLesson> progressionLessons = [
  ProgressionLesson(
    id: 'pr1',
    title: '1 · Temel İlerlemeler',
    pool: [
      _p('I – IV – V – I', [degI, degIV, degV, degI]),
      _p('I – V – vi – IV', [degI, degV, degVI, degIV]),
    ],
    concept: const Concept(
      title: 'Akor İlerlemeleri',
      sections: [
        ConceptSection(
          'İlerleme, akorların belirli bir sırayla birbirini takip etmesidir — '
          'şarkıların "iskeleti".',
        ),
        ConceptSection(
          heading: 'I – IV – V – I',
          'En temel kalıp: evden uzaklaş (IV), geril (V), eve dön (I).',
        ),
        ConceptSection(
          heading: 'I – V – vi – IV',
          'Sayısız pop şarkısının döngüsü — bir kez duyunca her yerde tanırsın.',
        ),
        ConceptSection(
          heading: 'İpucu',
          'Tek tek akora değil, dizinin "hareketine" (ev → gerilim → dönüş) kulak ver.',
        ),
      ],
    ),
  ),
  ProgressionLesson(
    id: 'pr2',
    title: '2 · Daha Fazla İlerleme',
    pool: [
      _p('I – IV – V – I', [degI, degIV, degV, degI]),
      _p('I – V – vi – IV', [degI, degV, degVI, degIV]),
      _p('ii – V – I', [degII, degV, degI]),
      _p('I – vi – IV – V', [degI, degVI, degIV, degV]),
    ],
    concept: const Concept(
      title: 'Daha Fazla İlerleme',
      sections: [
        ConceptSection(
          'ii – V – I cazın temel taşıdır; I – vi – IV – V ise 50\'ler pop\'unun '
          'klasik döngüsü.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Kalıbı, dizideki akorların hareketinden (ve uzunluğundan) tanımak.',
        ),
      ],
    ),
  ),
];
