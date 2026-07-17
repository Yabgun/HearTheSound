import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/major_key.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../function/function_lesson.dart';

// -----------------------------------------------------------------------------
// AKOR İLERLEMELERİ — akorların sırayla dizilişi
//
// Do majör derecelerinden (function_lesson'daki degI..degVII) diziler kurulur.
// Şarkıların "iskeleti"; kullanıcı diziyi dinleyip hangi kalıp olduğunu tanır.
// -----------------------------------------------------------------------------

class Progression {
  final String name; // "I – IV – V – I"
  final List<DegreeChord> degrees;

  /// Kullanıcının kulakla arayacağı dramatik hareket.
  final String story;

  /// İlerleme sonunda cümlenin kapanıp kapanmadığını anlatan kısa ipucu.
  final String cadenceHint;

  const Progression(
    this.name,
    this.degrees, {
    required this.story,
    required this.cadenceHint,
  });

  List<Chord> get chords => [for (final d in degrees) d.chord];

  String get chordChain => chords.map((c) => c.root.name).join(' – ');

  String get functionPath => degrees.map((d) => d.function.label).join(' → ');

  Progression transposedBy(int semitones) => Progression(
        name,
        degrees.map((degree) => degree.transposedBy(semitones)).toList(),
        story: story,
        cadenceHint: cadenceHint,
      );
}

/// Bir dersin tüm ilerlemelerini tek oktav offset'iyle taşır. Böylece öğren,
/// kur, arpejle ve tanı safhalarındaki sesler aynı yerde kalır.
List<Progression> transposeProgressionsForVoice(
  List<Progression> progressions,
  VocalRange? range,
) {
  final offset = octaveOffsetFor(
    progressions
        .expand((progression) => progression.chords)
        .expand((chord) => chord.notes)
        .map((note) => note.midi),
    range,
  );
  return offset == 0
      ? List<Progression>.from(progressions)
      : progressions
          .map((progression) => progression.transposedBy(offset))
          .toList();
}

Progression _p(
  String name,
  List<DegreeChord> degrees, {
  required String story,
  required String cadenceHint,
}) =>
    Progression(
      name,
      degrees,
      story: story,
      cadenceHint: cadenceHint,
    );

class ProgressionLesson {
  final String id;
  final String title;
  final List<Progression> pool;
  final MajorKey key;
  final Concept? concept;
  const ProgressionLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.key = MajorKey.c,
    this.concept,
  });

  ProgressionLesson inKey(MajorKey targetKey) => ProgressionLesson(
        id: id,
        title: title,
        pool: pool
            .map((progression) => progression.transposedBy(targetKey.semitonesFromC))
            .toList(),
        key: targetKey,
        concept: concept,
      );
}

final List<ProgressionLesson> progressionLessons = [
  ProgressionLesson(
    id: 'pr1',
    title: '1 · Temel İlerlemeler',
    key: MajorKey.c,
    pool: [
      _p(
        'I – IV – V – I',
        [degI, degIV, degV, degI],
        story: 'Ev → hazırlık → gerilim → eve dönüş',
        cadenceHint: 'Tam kapanış hissi verir; cümle eve oturur.',
      ),
      _p(
        'I – V – vi – IV',
        [degI, degV, degVI, degIV],
        story: 'Ev → gerilim → yumuşak gölge → hazırlık',
        cadenceHint: 'Döngü açık kalır; tekrar başa bağlanmak ister.',
      ),
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
    key: MajorKey.g,
    pool: [
      _p(
        'I – IV – V – I',
        [degI, degIV, degV, degI],
        story: 'Ev → hazırlık → gerilim → eve dönüş',
        cadenceHint: 'Tam kapanış hissi verir; cümle eve oturur.',
      ),
      _p(
        'I – V – vi – IV',
        [degI, degV, degVI, degIV],
        story: 'Ev → gerilim → yumuşak gölge → hazırlık',
        cadenceHint: 'Döngü açık kalır; tekrar başa bağlanmak ister.',
      ),
      _p(
        'ii – V – I',
        [degII, degV, degI],
        story: 'Hazırlık → gerilim → eve çözülme',
        cadenceHint: 'Çok net bir ii–V–I çözülmesi verir.',
      ),
      _p(
        'I – vi – IV – V',
        [degI, degVI, degIV, degV],
        story: 'Ev → yumuşak gölge → hazırlık → gerilim',
        cadenceHint: 'Sonda V kalır; kulak bir sonraki I’i bekler.',
      ),
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
