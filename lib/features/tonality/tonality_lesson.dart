import '../../core/concept.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// DİZİLER VE TONALİTE — seslerin bir "ev" notası etrafında anlam kazanması
//
// Bu track, aralık/akor işlevi/ilerleme derslerinin eksik köprüsüdür. Kullanıcı
// önce tek tek notaları değil, bir tonal merkez içindeki dereceleri duymayı öğrenir.
// -----------------------------------------------------------------------------

/// Majör dizide bir derece. Örn. 1 = tonik, 5 = dominant.
class ScaleDegree {
  final int number;
  final int semitonesFromTonic;
  final String name;
  final String role;

  const ScaleDegree({
    required this.number,
    required this.semitonesFromTonic,
    required this.name,
    required this.role,
  });

  String get label => '$number. derece';

  Note noteFrom(Note tonic) => Note(tonic.midi + semitonesFromTonic);

  @override
  bool operator ==(Object other) =>
      other is ScaleDegree && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

const List<ScaleDegree> majorScaleDegrees = [
  ScaleDegree(
    number: 1,
    semitonesFromTonic: 0,
    name: 'Tonik',
    role: 'ev, merkez, varış',
  ),
  ScaleDegree(
    number: 2,
    semitonesFromTonic: 2,
    name: 'Süpertonik',
    role: 'hareket, hazırlık',
  ),
  ScaleDegree(
    number: 3,
    semitonesFromTonic: 4,
    name: 'Medyant',
    role: 'majör rengin parıltısı',
  ),
  ScaleDegree(
    number: 4,
    semitonesFromTonic: 5,
    name: 'Subdominant',
    role: 'evden uzaklaşma',
  ),
  ScaleDegree(
    number: 5,
    semitonesFromTonic: 7,
    name: 'Dominant',
    role: 'gerilim, eve dönüş isteği',
  ),
  ScaleDegree(
    number: 6,
    semitonesFromTonic: 9,
    name: 'Submedyant',
    role: 'yumuşak renk, göreli minör kapısı',
  ),
  ScaleDegree(
    number: 7,
    semitonesFromTonic: 11,
    name: 'Yeden',
    role: 'tonik notaya çözülmek ister',
  ),
];

ScaleDegree degree(int number) =>
    majorScaleDegrees.firstWhere((d) => d.number == number);

List<Note> majorScaleFrom(Note tonic) => [
      for (final degree in majorScaleDegrees) degree.noteFrom(tonic),
      Note(tonic.midi + 12),
    ];

class TonalityLesson {
  final String id;
  final String title;
  final List<ScaleDegree> pool;
  final Concept concept;

  const TonalityLesson({
    required this.id,
    required this.title,
    required this.pool,
    required this.concept,
  });
}

final List<TonalityLesson> tonalityLessons = [
  TonalityLesson(
    id: 'tn1',
    title: '1 · Tonik ve Majör Dizi',
    pool: [degree(1), degree(3), degree(5)],
    concept: const Concept(
      title: 'Tonik ve Majör Dizi',
      sections: [
        ConceptSection(
          'Tonalite, notaların bir merkez etrafında anlam kazanmasıdır. Bu merkez '
          'notaya tonik deriz: kulağın "eve geldik" dediği yer.',
        ),
        ConceptSection(
          heading: 'Majör dizi',
          'Majör dizi tonikten başlayıp belirli aralıklarla yükselen yedi notalık '
          'bir yol gibidir. Do majörde bu yol C-D-E-F-G-A-B-C diye duyulur.',
        ),
        ConceptSection(
          heading: 'Bu derste',
          '1, 3 ve 5. dereceleri dinleyeceksin. Bu üç derece majör tonalitenin '
          'iskeletini ve "ev" hissini çok net verir.',
        ),
      ],
    ),
  ),
  TonalityLesson(
    id: 'tn2',
    title: '2 · Dereceler',
    pool: majorScaleDegrees,
    concept: const Concept(
      title: 'Derece Nedir?',
      sections: [
        ConceptSection(
          'Bir notanın adı değişebilir ama tonalitedeki görevi aynı kalabilir. '
          'Bu göreve derece deriz: 1. derece, 2. derece, 3. derece...',
        ),
        ConceptSection(
          heading: 'Neden önemli?',
          'Akor işlevi ve ilerlemeler derecelerle konuşur. I, IV, V dediğimizde '
          'aslında 1, 4 ve 5. derecelerin üstüne kurulan akorlardan söz ederiz.',
        ),
        ConceptSection(
          heading: 'Nasıl dinle?',
          'Önce tonik referansı duy, sonra hedef dereceyi. Hedef ses eve mi oturuyor, '
          'uzaklaşıyor mu, yoksa eve dönmek mi istiyor?',
        ),
      ],
    ),
  ),
];
