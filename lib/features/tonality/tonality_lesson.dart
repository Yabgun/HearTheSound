import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// DİZİLER VE TONALİTE — seslerin bir "ev" notası etrafında anlam kazanması
//
// Bu track, aralık/akor işlevi/ilerleme derslerinin eksik köprüsüdür. Kullanıcı
// önce tek tek notaları değil, bir tonal merkez içindeki dereceleri duymayı öğrenir.
//
// i18n: derece adı/rolü GETTER'dır (aktif dile göre çözülür); ders listesi
// locale-anahtarlı önbellekten döner.
// -----------------------------------------------------------------------------

/// Majör dizide bir derece. Örn. 1 = tonik, 5 = dominant.
class ScaleDegree {
  final int number;
  final int semitonesFromTonic;

  const ScaleDegree({required this.number, required this.semitonesFromTonic});

  /// Derecenin adı — aktif dile göre (Tonic/Tonik...).
  String get name => switch (number) {
    1 => t(en: 'Tonic', tr: 'Tonik'),
    2 => t(en: 'Supertonic', tr: 'Süpertonik'),
    3 => t(en: 'Mediant', tr: 'Medyant'),
    4 => t(en: 'Subdominant', tr: 'Subdominant'),
    5 => t(en: 'Dominant', tr: 'Dominant'),
    6 => t(en: 'Submediant', tr: 'Submedyant'),
    7 => t(en: 'Leading tone', tr: 'Yeden'),
    _ => '$number',
  };

  /// Derecenin kulaktaki rolü — aktif dile göre.
  String get role => switch (number) {
    1 => t(en: 'home, center, arrival', tr: 'ev, merkez, varış'),
    2 => t(en: 'motion, preparation', tr: 'hareket, hazırlık'),
    3 => t(en: 'the shine of the major color', tr: 'majör rengin parıltısı'),
    4 => t(en: 'moving away from home', tr: 'evden uzaklaşma'),
    5 => t(en: 'tension, the pull home', tr: 'gerilim, eve dönüş isteği'),
    6 => t(
      en: 'soft color, door to the relative minor',
      tr: 'yumuşak renk, göreli minör kapısı',
    ),
    7 => t(
      en: 'longs to resolve to the tonic',
      tr: 'tonik notaya çözülmek ister',
    ),
    _ => '',
  };

  String get label => t(en: 'Degree $number', tr: '$number. derece');

  Note noteFrom(Note tonic) => Note(tonic.midi + semitonesFromTonic);

  @override
  bool operator ==(Object other) =>
      other is ScaleDegree && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

const List<ScaleDegree> majorScaleDegrees = [
  ScaleDegree(number: 1, semitonesFromTonic: 0),
  ScaleDegree(number: 2, semitonesFromTonic: 2),
  ScaleDegree(number: 3, semitonesFromTonic: 4),
  ScaleDegree(number: 4, semitonesFromTonic: 5),
  ScaleDegree(number: 5, semitonesFromTonic: 7),
  ScaleDegree(number: 6, semitonesFromTonic: 9),
  ScaleDegree(number: 7, semitonesFromTonic: 11),
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

/// Ders listesi — locale-anahtarlı önbellek: dil değişince yeni dilde kurulur.
final Map<String, List<TonalityLesson>> _lessonCache = {};

List<TonalityLesson> get tonalityLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildTonalityLessons);

List<TonalityLesson> _buildTonalityLessons() => [
  TonalityLesson(
    id: 'tn1',
    title: t(
      en: '1 · Tonic and the Major Scale',
      tr: '1 · Tonik ve Majör Dizi',
    ),
    pool: [degree(1), degree(3), degree(5)],
    concept: Concept(
      title: t(en: 'Tonic and the Major Scale', tr: 'Tonik ve Majör Dizi'),
      sections: [
        ConceptSection(
          t(
            en:
                'Tonality is notes gaining meaning around a center. We call '
                'that center note the tonic: the place where the ear says '
                '"we\'re home".',
            tr:
                'Tonalite, notaların bir merkez etrafında anlam kazanmasıdır. '
                'Bu merkez notaya tonik deriz: kulağın "eve geldik" dediği yer.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'The major scale', tr: 'Majör dizi'),
          t(
            en:
                'The major scale is like a seven-note path climbing from the '
                'tonic with fixed steps. In C major that path sounds as '
                'C-D-E-F-G-A-B-C.',
            tr:
                'Majör dizi tonikten başlayıp belirli aralıklarla yükselen yedi '
                'notalık bir yol gibidir. Do majörde bu yol C-D-E-F-G-A-B-C '
                'diye duyulur.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'In this lesson', tr: 'Bu derste'),
          t(
            en:
                'You will listen to degrees 1, 3 and 5. These three give the '
                'skeleton of the major key and a very clear sense of "home".',
            tr:
                '1, 3 ve 5. dereceleri dinleyeceksin. Bu üç derece majör '
                'tonalitenin iskeletini ve "ev" hissini çok net verir.',
          ),
        ),
      ],
    ),
  ),
  TonalityLesson(
    id: 'tn2',
    title: t(en: '2 · Degrees', tr: '2 · Dereceler'),
    pool: majorScaleDegrees,
    concept: Concept(
      title: t(en: 'What Is a Degree?', tr: 'Derece Nedir?'),
      sections: [
        ConceptSection(
          t(
            en:
                'A note\'s name can change, but its job inside the key can '
                'stay the same. We call that job a degree: degree 1, degree 2, '
                'degree 3...',
            tr:
                'Bir notanın adı değişebilir ama tonalitedeki görevi aynı '
                'kalabilir. Bu göreve derece deriz: 1. derece, 2. derece, '
                '3. derece...',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Why does it matter?', tr: 'Neden önemli?'),
          t(
            en:
                'Chord functions and progressions speak in degrees. When we '
                'say I, IV, V we really mean the chords built on degrees 1, 4 '
                'and 5.',
            tr:
                'Akor işlevi ve ilerlemeler derecelerle konuşur. I, IV, V '
                'dediğimizde aslında 1, 4 ve 5. derecelerin üstüne kurulan '
                'akorlardan söz ederiz.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'How to listen', tr: 'Nasıl dinle?'),
          t(
            en:
                'First hear the tonic reference, then the target degree. Does '
                'the target settle home, move away, or want to come back home?',
            tr:
                'Önce tonik referansı duy, sonra hedef dereceyi. Hedef ses eve '
                'mi oturuyor, uzaklaşıyor mu, yoksa eve dönmek mi istiyor?',
          ),
        ),
      ],
    ),
  ),
];
