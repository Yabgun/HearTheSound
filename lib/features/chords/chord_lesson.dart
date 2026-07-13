import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/note.dart';

/// Bir akor dersinde tanıma (test) aşamasının neyi sorduğu.
enum ChordRecognizeBy {
  /// Spesifik akoru sor ("Bu hangi akor?" / notaları). Varsayılan.
  chord,

  /// Akorun niteliğini/rengini sor ("Bu ne niteliği?": majör/minör/eksik/artık).
  /// Kökten bağımsız renk kulağını eğitir.
  quality,

  /// Akorun çevrimini sor ("Bu kaçıncı çevrim?": kapalı/1./2.).
  inversion,
}

/// Bir akor dersi = kimlik + başlık + o derste öğretilen akorlar havuzu.
/// Nota dersleri gibi akor akor ilerler; bir ders geçilince sonraki açılır.
class ChordLesson {
  final String id;
  final String title;
  final List<Chord> pool;
  final ChordRecognizeBy recognizeBy;
  final Concept? concept; // öğretici kart — test'ten önce öğret
  const ChordLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.recognizeBy = ChordRecognizeBy.chord,
    this.concept,
  });
}

Chord _c(String root, ChordQuality quality, [int octave = 4]) =>
    Chord(Note.fromName(root, octave), quality);

Chord _ci(String root, ChordQuality quality, int inversion, [int octave = 4]) =>
    Chord(Note.fromName(root, octave), quality, inversion: inversion);

/// Akor müfredatı — kolaydan zora, akor akor. (İleride tüm kök × nitelik ×
/// oktava genişletilecek — bkz. proje kapsam hedefi.)
final List<ChordLesson> chordLessons = [
  ChordLesson(
    id: 'ch1',
    title: '1 · C Majör & A Minör',
    pool: [_c('C', ChordQuality.major), _c('A', ChordQuality.minor)],
    concept: const Concept(
      title: 'Akor Nedir? Majör & Minör',
      sections: [
        ConceptSection(
          'Akor = aynı anda çalınan (en az) üç nota. Tek bir ses değil, bir '
          '"renk"tir.',
        ),
        ConceptSection(
          heading: 'Majör',
          'Parlak, neşeli, "açık" duyulur. Örnek — C majör: C-E-G.',
        ),
        ConceptSection(
          heading: 'Minör',
          'Daha koyu, hüzünlü, "kapalı" duyulur. Örnek — A minör: A-C-E.',
        ),
        ConceptSection(
          heading: 'İpucu',
          'Notaları tek tek çözmeye çalışma; akorun genel "havasını" dinle.',
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch2',
    title: '2 · F & G Majör',
    pool: [_c('F', ChordQuality.major), _c('G', ChordQuality.major)],
    concept: const Concept(
      title: 'Daha Fazla Majör',
      sections: [
        ConceptSection(
          'F ve G majör — aynı "parlak majör" hissi, farklı köklerde. Kök '
          'değişse de renk aynı kalır.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Majör rengini kökten bağımsız tanımaya başlamak.',
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch3',
    title: '3 · D & E Minör',
    pool: [_c('D', ChordQuality.minor), _c('E', ChordQuality.minor)],
    concept: const Concept(
      title: 'Minör Akorlar',
      sections: [
        ConceptSection(
          'D ve E minör — minör rengi farklı köklerde. Koyu, hüzünlü his.',
        ),
        ConceptSection(
          heading: 'Karşılaştır',
          'Majör ile minör arasındaki fark aslında ortadaki (üçlü) notadadır — '
          'sadece yarım ses. Ama duygu tamamen değişir.',
        ),
      ],
    ),
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
    concept: const Concept(
      title: 'Karışık: Majör mü Minör mü?',
      sections: [
        ConceptSection(
          'Farklı köklerde majör ve minör akorlar karışık gelir.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Kökü bilmeden yalnızca renkten (parlak mı, hüzünlü mü) ayırmak.',
        ),
      ],
    ),
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
    concept: const Concept(
      title: 'Eksik & Artık Akorlar',
      sections: [
        ConceptSection(
          'Majör ve minör dışında iki "renk" daha var. Bunları akorun en üstteki '
          '(beşli) notasını kaydırarak elde ederiz.',
        ),
        ConceptSection(
          heading: 'Eksik (dim)',
          'Gergin, kararsız, biraz "tekinsiz" duyulur. İki minör üçlü üst üste: '
          'kök + 3 + 3 yarım ses (ör. C-Eb-Gb).',
        ),
        ConceptSection(
          heading: 'Artık (aug)',
          'Rüya gibi, "asılı kalan", çözülmemiş bir his. İki majör üçlü üst üste: '
          'kök + 4 + 4 yarım ses (ör. C-E-G#).',
        ),
        ConceptSection(
          heading: 'İpucu',
          'Majör/minör "oturmuş" duyulur; eksik/artık "bir yere gitmek isteyen", '
          'huzursuz duyulur.',
        ),
      ],
    ),
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
    concept: const Concept(
      title: 'Dört Rengi Ayırt Et',
      sections: [
        ConceptSection(
          'Majör, minör, eksik, artık — dördü de farklı köklerde karışık gelir.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Rengi tamamen kökten bağımsız, sadece "his"ten tanımak.',
        ),
        ConceptSection(
          heading: 'Hatırlatma',
          'Majör: parlak · Minör: hüzünlü · Eksik: gergin · Artık: asılı/rüyamsı.',
        ),
      ],
    ),
  ),
  // A4 — yedili akorlar (4 nota).
  ChordLesson(
    id: 'ch7',
    title: '7 · Yedili Akorlar',
    recognizeBy: ChordRecognizeBy.quality,
    pool: [
      _c('C', ChordQuality.dominant7),
      _c('C', ChordQuality.major7),
      _c('C', ChordQuality.minor7),
    ],
    concept: const Concept(
      title: 'Yedili Akorlar',
      sections: [
        ConceptSection(
          'Üçlü akora bir nota daha (7\'li) eklenince renk zenginleşir — cazın ve '
          'pop\'un dokusu buradan gelir.',
        ),
        ConceptSection(
          heading: 'Dominant 7',
          'Gergin, "çözülmek isteyen" bir ses (V7 → I). Örnek C7: C-E-G-Bb.',
        ),
        ConceptSection(
          heading: 'Majör 7',
          'Yumuşak, parlak, hülyalı. Örnek Cmaj7: C-E-G-B.',
        ),
        ConceptSection(
          heading: 'Minör 7',
          'Kadifemsi, yumuşak minör. Örnek Cm7: C-Eb-G-Bb.',
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch8',
    title: '8 · Yedili Renkler',
    recognizeBy: ChordRecognizeBy.quality,
    pool: [
      _c('C', ChordQuality.dominant7),
      _c('G', ChordQuality.dominant7),
      _c('F', ChordQuality.major7),
      _c('C', ChordQuality.major7),
      _c('D', ChordQuality.minor7),
      _c('A', ChordQuality.minor7),
      _c('B', ChordQuality.halfDiminished7),
      _c('D', ChordQuality.diminished7),
    ],
    concept: const Concept(
      title: 'Yedili Renkleri',
      sections: [
        ConceptSection(
          'Yedililer farklı köklerde karışık gelir. Ayrıca iki koyu renk katılıyor: '
          'Yarım Eksik 7 (gergin ama yumuşak) ve Tam Eksik 7 (en kararsız, "sürünen").',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Beş yedili rengini kökten bağımsız ayırmak — caz kulağının temeli.',
        ),
      ],
    ),
  ),
  // A3 — akor çevrimleri (aynı notalar, farklı bas).
  ChordLesson(
    id: 'ch9',
    title: '9 · Akor Çevrimleri',
    recognizeBy: ChordRecognizeBy.inversion,
    // Tek akor (C majör) üç çevrimde → değişkeni yalnızca çevrim yap.
    pool: [
      _ci('C', ChordQuality.major, 0),
      _ci('C', ChordQuality.major, 1),
      _ci('C', ChordQuality.major, 2),
    ],
    concept: const Concept(
      title: 'Akor Çevrimleri',
      sections: [
        ConceptSection(
          'Bir akorun notaları aynı kalır; ama en alttaki (bas) notayı '
          'değiştirebiliriz. Buna "çevrim" denir.',
        ),
        ConceptSection(
          heading: 'Kapalı',
          'Kök en altta — C majör: C-E-G.',
        ),
        ConceptSection(
          heading: '1. çevrim',
          '3\'lü en altta — E-G-C.',
        ),
        ConceptSection(
          heading: '2. çevrim',
          '5\'li en altta — G-C-E.',
        ),
        ConceptSection(
          heading: 'İpucu',
          'Akorun rengi aynı; en PES notaya kulak ver — taban nerede?',
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch10',
    title: '10 · Karışık Çevrimler',
    recognizeBy: ChordRecognizeBy.inversion,
    pool: [
      _ci('C', ChordQuality.major, 0),
      _ci('G', ChordQuality.major, 1),
      _ci('F', ChordQuality.major, 2),
      _ci('A', ChordQuality.minor, 1),
      _ci('D', ChordQuality.minor, 0),
      _ci('E', ChordQuality.minor, 2),
    ],
    concept: const Concept(
      title: 'Karışık Çevrimler',
      sections: [
        ConceptSection(
          'Farklı akorlar, farklı çevrimlerde gelir. Amaç akorun kendisini değil, '
          'yalnızca ÇEVRİMİNİ (bası) tanımak.',
        ),
        ConceptSection(
          heading: 'Hatırlatma',
          'Kapalı = kök bası · 1. çevrim = 3\'lü bası · 2. çevrim = 5\'li bası.',
        ),
      ],
    ),
  ),
];
