import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/interval.dart';

/// Bir aralık dersi = kimlik + başlık + o derste çalışılan aralıklar (+ kavram
/// kartı). Nota/akor dersleri gibi ilerler; bir ders geçilince sonraki açılır.
///
/// [harmonic] true ise iki nota AYNI ANDA çalınır (harmonik aralık) ve akış
/// kısalır: Öğren → Kur → Tanı (yön/melodi/söyleme melodik kavramlar olduğu
/// için atlanır — aynı anda iki nota söylenemez).
class IntervalLesson {
  final String id;
  final String title;
  final List<MusicInterval> pool;
  final Concept? concept;
  final bool harmonic;
  const IntervalLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
    this.harmonic = false,
  });
}

/// Aralık müfredatı — kolaydan zora (geniş/açık aralıklardan dar/yakınlara).
/// Melodik (kök → üst, çıkıcı) çalınır. Locale-anahtarlı önbellekten döner.
final Map<String, List<IntervalLesson>> _lessonCache = {};

List<IntervalLesson> get intervalLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildIntervalLessons);

List<IntervalLesson> _buildIntervalLessons() => [
  IntervalLesson(
    id: 'iv1',
    title: t(en: '1 · First Intervals', tr: '1 · İlk Aralıklar'),
    pool: [iv(4), iv(7), iv(12)], // Büyük 3'lü, Tam 5'li, Oktav
    concept: Concept(
      title: t(en: 'What Is an Interval?', tr: 'Aralık Nedir?'),
      sections: [
        ConceptSection(
          t(
            en:
                'An interval is the distance between two notes. Melodies are '
                'woven from these distances (leaps).',
            tr:
                'Aralık, iki nota arasındaki mesafedir. Melodiler bu '
                'mesafelerden (atlamalardan) örülür.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'In this lesson', tr: 'Bu derste'),
          t(
            en:
                'Major 3rd, Perfect 5th and the Octave — all three are wide, '
                'open and easy to tell apart.',
            tr:
                'Büyük 3\'lü, Tam 5\'li ve Oktav — üçü de geniş, açık ve '
                'birbirinden kolay ayrılan aralıklar.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'How to listen', tr: 'Nasıl dinle?'),
          t(
            en:
                'You will hear the root, then the upper note right after. '
                'Focus on how big the "leap" between the two sounds is.',
            tr:
                'Önce kökü, hemen ardından üst notayı duyacaksın. İki ses '
                'arasındaki "atlama" ne kadar büyük — ona odaklan.',
          ),
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv2',
    title: t(en: '2 · Thirds', tr: '2 · Üçlüler'),
    pool: [iv(2), iv(3), iv(4)], // Büyük 2'li, Küçük 3'lü, Büyük 3'lü
    concept: Concept(
      title: t(
        en: 'Where Color Is Born: 3rds',
        tr: 'Renk Burada Doğar: 3\'lüler',
      ),
      sections: [
        ConceptSection(
          t(
            en:
                'Between the Minor 3rd (3 semitones) and the Major 3rd (4 '
                'semitones) there is only a half step — yet one sounds sad, '
                'the other bright.',
            tr:
                'Küçük 3\'lü (3 yarım ses) ile Büyük 3\'lü (4 yarım ses) '
                'arasında yalnızca bir yarım ses fark var — ama biri hüzünlü, '
                'biri parlak duyulur.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Why does it matter?', tr: 'Neden önemli?'),
          t(
            en:
                'The major/minor color of chords comes exactly from this '
                'third. Hearing this difference is the key to everything.',
            tr:
                'Akorların majör/minör rengi tam da bu üçlüden gelir. Bu farkı '
                'duyabilmek her şeyin anahtarıdır.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Major 2nd', tr: 'Büyük 2\'li'),
          t(
            en:
                'For comparison there is also the neighbor step (2nd) — '
                'narrower than the thirds.',
            tr:
                'Karşılaştırma için bir de komşu adım (2\'li) var — '
                'üçlülerden daha dar.',
          ),
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv3',
    title: t(
      en: '3 · Fourth · Tritone · Fifth',
      tr: '3 · Dörtlü · Triton · Beşli',
    ),
    pool: [iv(5), iv(6), iv(7)], // Tam 4'lü, Triton, Tam 5'li
    concept: Concept(
      title: t(en: 'Open and Tense', tr: 'Açık ve Gergin'),
      sections: [
        ConceptSection(
          t(
            en:
                'The Perfect 4th and Perfect 5th sound "open, stable, '
                'settled" — the sound of marches and hymns.',
            tr:
                'Tam 4\'lü ve Tam 5\'li "açık, kararlı, oturmuş" duyulur — '
                'marşların ve ilahilerin sesi.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tritone', tr: 'Triton'),
          t(
            en:
                'Sitting between the 4th and the 5th, the Tritone is tense, '
                'unstable and restless (it used to be called "the devil\'s '
                'interval").',
            tr:
                'Tam 4\'lü ile 5\'li arasında kalan Triton gergin, kararsız, '
                'huzursuz bir aralıktır (eskiden "şeytanın aralığı" denirdi).',
          ),
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv4',
    title: t(en: '4 · Mixed Intervals', tr: '4 · Karışık Aralıklar'),
    pool: [iv(2), iv(3), iv(4), iv(5), iv(7), iv(9), iv(12)],
    concept: Concept(
      title: t(en: 'Mixed Intervals', tr: 'Karışık Aralıklar'),
      sections: [
        ConceptSection(
          t(
            en:
                'The intervals you learned arrive on shuffled roots. Goal: '
                'recognize the distance purely by its "size", independent of '
                'the root.',
            tr:
                'Öğrendiğin aralıklar farklı köklerde karışık gelir. Amaç: '
                'mesafeyi kökten bağımsız, sadece "boyutundan" tanımak.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Match them to the openings of songs you know. The Perfect '
                '5th, for example, is the leap that opens "Twinkle Twinkle".',
            tr:
                'Bildiğin şarkıların başındaki atlamalarla eşleştir. Örneğin '
                'Tam 5\'li, "Twinkle Twinkle / Daha Dün Annemizin" '
                'başlangıcındaki sıçramadır.',
          ),
        ),
      ],
    ),
  ),
  // A7 — HARMONİK aralıklar: iki nota aynı anda (yepyeni duyum).
  IntervalLesson(
    id: 'iv5',
    title: t(en: '5 · Harmonic Intervals', tr: '5 · Harmonik Aralıklar'),
    harmonic: true,
    pool: [iv(3), iv(4), iv(7), iv(12)], // K3, B3, T5, Oktav
    concept: Concept(
      title: t(en: 'Two Notes at Once', tr: 'Aynı Anda İki Nota'),
      sections: [
        ConceptSection(
          t(
            en:
                'So far the two notes came one after another (melodic). Now '
                'they sound TOGETHER — that is a harmonic interval, and it is '
                'how intervals live inside chords.',
            tr:
                'Şimdiye dek iki nota art arda geliyordu (melodik). Artık AYNI '
                'ANDA tınlıyorlar — buna harmonik aralık denir ve aralıklar '
                'akorların içinde böyle yaşar.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'How to listen', tr: 'Nasıl dinle?'),
          t(
            en:
                'You can no longer follow a "leap". Instead, feel the blend: '
                'does the pair sound sweet, hollow, or completely fused?',
            tr:
                'Artık takip edilecek bir "atlama" yok. Karışımı hisset: çift '
                'tatlı mı, boşluklu mu, yoksa tamamen kaynaşmış mı tınlıyor?',
          ),
        ),
        ConceptSection(
          heading: t(en: 'In this lesson', tr: 'Bu derste'),
          t(
            en:
                'Minor 3rd (dark-sweet), Major 3rd (bright-sweet), Perfect '
                '5th (open, hollow) and the Octave (two notes that melt into '
                'one).',
            tr:
                'Küçük 3\'lü (koyu-tatlı), Büyük 3\'lü (parlak-tatlı), Tam '
                '5\'li (açık, boşluklu) ve Oktav (tek sese eriyen iki nota).',
          ),
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv6',
    title: t(en: '6 · Harmonic Mix', tr: '6 · Harmonik Karışık'),
    harmonic: true,
    pool: [iv(2), iv(3), iv(4), iv(5), iv(6), iv(7), iv(9), iv(12)],
    concept: Concept(
      title: t(en: 'The Harmonic Palette', tr: 'Harmonik Palet'),
      sections: [
        ConceptSection(
          t(
            en:
                'More colors join in: the rub of the Major 2nd, the tense '
                'Tritone, the warm Major 6th. All played together, on '
                'shuffled roots.',
            tr:
                'Palete yeni renkler katılıyor: Büyük 2\'linin sürtünmesi, '
                'gergin Triton, sıcak Büyük 6\'lı. Hepsi birlikte, farklı '
                'köklerde.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Rough/rubbing = 2nd or Tritone. Sweet = a 3rd or 6th. Open '
                'and hollow = 4th or 5th. Fused into one = Octave.',
            tr:
                'Pürüzlü/sürtünen = 2\'li ya da Triton. Tatlı = 3\'lü ya da '
                '6\'lı. Açık ve boşluklu = 4\'lü ya da 5\'li. Tek sese '
                'kaynaşan = Oktav.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Why it matters', tr: 'Neden önemli?'),
          t(
            en:
                'Chords are stacked harmonic intervals. Master this palette '
                'and chord colors stop being a mystery.',
            tr:
                'Akorlar üst üste konmuş harmonik aralıklardır. Bu paleti '
                'çözersen akor renkleri sır olmaktan çıkar.',
          ),
        ),
      ],
    ),
  ),
];
