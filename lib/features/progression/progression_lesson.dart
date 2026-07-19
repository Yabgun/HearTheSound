import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/major_key.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';
import '../function/function_lesson.dart';

// -----------------------------------------------------------------------------
// AKOR İLERLEMELERİ — akorların sırayla dizilişi
//
// Do majör derecelerinden (function_lesson'daki degI..degVII) diziler kurulur.
// Şarkıların "iskeleti"; kullanıcı diziyi dinleyip hangi kalıp olduğunu tanır.
// [Progression.name] Roman zinciridir ve dil-bağımsızdır; hikâye/ipucu metinleri
// aktif dile göre kurulur.
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

  /// Kalıp eşitliği Roman zincirine göredir (tonalite/oktav taşımasından
  /// etkilenmez) — tanıma ekranı şıkları bunu karşılaştırır.
  @override
  bool operator ==(Object other) => other is Progression && other.name == name;

  @override
  int get hashCode => name.hashCode;
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
}) => Progression(name, degrees, story: story, cadenceHint: cadenceHint);

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
        .map(
          (progression) => progression.transposedBy(targetKey.semitonesFromC),
        )
        .toList(),
    key: targetKey,
    concept: concept,
  );
}

// Ortak kalıplar — iki derste de kullanılır; tek yerde tanımlı.
Progression get _pIivVi => _p(
  'I – IV – V – I',
  [degI, degIV, degV, degI],
  story: t(
    en: 'Home → preparation → tension → return home',
    tr: 'Ev → hazırlık → gerilim → eve dönüş',
  ),
  cadenceHint: t(
    en: 'Gives a full sense of closure; the sentence settles home.',
    tr: 'Tam kapanış hissi verir; cümle eve oturur.',
  ),
);

Progression get _pIvViIv => _p(
  'I – V – vi – IV',
  [degI, degV, degVI, degIV],
  story: t(
    en: 'Home → tension → soft shadow → preparation',
    tr: 'Ev → gerilim → yumuşak gölge → hazırlık',
  ),
  cadenceHint: t(
    en: 'The loop stays open; it wants to circle back to the start.',
    tr: 'Döngü açık kalır; tekrar başa bağlanmak ister.',
  ),
);

/// Ders listesi — locale-anahtarlı önbellek.
final Map<String, List<ProgressionLesson>> _lessonCache = {};

List<ProgressionLesson> get progressionLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildProgressionLessons);

List<ProgressionLesson> _buildProgressionLessons() => [
  ProgressionLesson(
    id: 'pr1',
    title: t(en: '1 · Core Progressions', tr: '1 · Temel İlerlemeler'),
    key: MajorKey.c,
    pool: [_pIivVi, _pIvViIv],
    concept: Concept(
      title: t(en: 'Chord Progressions', tr: 'Akor İlerlemeleri'),
      sections: [
        ConceptSection(
          t(
            en:
                'A progression is chords following each other in a set order '
                '— the "skeleton" of songs.',
            tr:
                'İlerleme, akorların belirli bir sırayla birbirini takip '
                'etmesidir — şarkıların "iskeleti".',
          ),
        ),
        ConceptSection(
          heading: 'I – IV – V – I',
          t(
            en:
                'The most fundamental pattern: leave home (IV), build tension '
                '(V), come home (I).',
            tr: 'En temel kalıp: evden uzaklaş (IV), geril (V), eve dön (I).',
          ),
        ),
        ConceptSection(
          heading: 'I – V – vi – IV',
          t(
            en:
                'The loop behind countless pop songs — hear it once and you '
                'will recognize it everywhere.',
            tr:
                'Sayısız pop şarkısının döngüsü — bir kez duyunca her yerde '
                'tanırsın.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Listen to the MOTION of the sequence (home → tension → '
                'return), not to each chord alone.',
            tr:
                'Tek tek akora değil, dizinin "hareketine" (ev → gerilim → '
                'dönüş) kulak ver.',
          ),
        ),
      ],
    ),
  ),
  ProgressionLesson(
    id: 'pr2',
    title: t(en: '2 · More Progressions', tr: '2 · Daha Fazla İlerleme'),
    key: MajorKey.g,
    pool: [
      _pIivVi,
      _pIvViIv,
      _p(
        'ii – V – I',
        [degII, degV, degI],
        story: t(
          en: 'Preparation → tension → resolving home',
          tr: 'Hazırlık → gerilim → eve çözülme',
        ),
        cadenceHint: t(
          en: 'Gives a very clear ii–V–I resolution.',
          tr: 'Çok net bir ii–V–I çözülmesi verir.',
        ),
      ),
      _p(
        'I – vi – IV – V',
        [degI, degVI, degIV, degV],
        story: t(
          en: 'Home → soft shadow → preparation → tension',
          tr: 'Ev → yumuşak gölge → hazırlık → gerilim',
        ),
        cadenceHint: t(
          en: 'It ends on V; the ear waits for the next I.',
          tr: 'Sonda V kalır; kulak bir sonraki I’i bekler.',
        ),
      ),
    ],
    concept: Concept(
      title: t(en: 'More Progressions', tr: 'Daha Fazla İlerleme'),
      sections: [
        ConceptSection(
          t(
            en:
                'ii – V – I is the cornerstone of jazz; I – vi – IV – V is '
                'the classic loop of 50s pop.',
            tr:
                'ii – V – I cazın temel taşıdır; I – vi – IV – V ise 50\'ler '
                'pop\'unun klasik döngüsü.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Recognize the pattern from the motion (and length) of the '
                'chord sequence.',
            tr:
                'Kalıbı, dizideki akorların hareketinden (ve uzunluğundan) '
                'tanımak.',
          ),
        ),
      ],
    ),
  ),
  // A9 — üçüncü tonal merkez: D Majör (kalıplar yeni evde de tanınmalı).
  ProgressionLesson(
    id: 'pr3',
    title: t(
      en: '3 · Progressions in D Major',
      tr: '3 · D Majörde İlerlemeler',
    ),
    key: MajorKey.d,
    pool: [
      _pIivVi,
      _pIvViIv,
      _p(
        'ii – V – I',
        [degII, degV, degI],
        story: t(
          en: 'Preparation → tension → resolving home',
          tr: 'Hazırlık → gerilim → eve çözülme',
        ),
        cadenceHint: t(
          en: 'Gives a very clear ii–V–I resolution.',
          tr: 'Çok net bir ii–V–I çözülmesi verir.',
        ),
      ),
      _p(
        'I – vi – IV – V',
        [degI, degVI, degIV, degV],
        story: t(
          en: 'Home → soft shadow → preparation → tension',
          tr: 'Ev → yumuşak gölge → hazırlık → gerilim',
        ),
        cadenceHint: t(
          en: 'It ends on V; the ear waits for the next I.',
          tr: 'Sonda V kalır; kulak bir sonraki I’i bekler.',
        ),
      ),
    ],
    concept: Concept(
      title: t(en: 'Patterns in a New Home', tr: 'Yeni Evde Kalıplar'),
      sections: [
        ConceptSection(
          t(
            en:
                'The same four patterns, now living in D major. Absolute '
                'notes are brighter and higher, but I–IV–V–I still walks the '
                'same road: home, away, tension, home.',
            tr:
                'Aynı dört kalıp, artık D Majörde. Mutlak notalar daha parlak '
                've daha tiz; ama I–IV–V–I hâlâ aynı yolu yürüyor: ev, '
                'uzaklaşma, gerilim, ev.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Prove the pattern lives in your ear, not in one key: '
                'recognize the motion no matter which home it starts from.',
            tr:
                'Kalıbın tek tonalitede değil kulağında yaşadığını kanıtla: '
                'hangi evden başlarsa başlasın hareketi tanı.',
          ),
        ),
      ],
    ),
  ),
];
