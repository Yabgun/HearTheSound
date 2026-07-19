import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/content_locale.dart';
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

/// Akor müfredatı — kolaydan zora, akor akor. Locale-anahtarlı önbellekten
/// döner (i18n); dil değişince bir sonraki erişim yeni dilde kurar.
final Map<String, List<ChordLesson>> _lessonCache = {};

List<ChordLesson> get chordLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildChordLessons);

List<ChordLesson> _buildChordLessons() => [
  ChordLesson(
    id: 'ch1',
    title: t(en: '1 · C Major & A Minor', tr: '1 · C Majör & A Minör'),
    pool: [_c('C', ChordQuality.major), _c('A', ChordQuality.minor)],
    concept: Concept(
      title: t(
        en: 'What Is a Chord? Major & Minor',
        tr: 'Akor Nedir? Majör & Minör',
      ),
      sections: [
        ConceptSection(
          t(
            en:
                'A chord is (at least) three notes played at once. It is not a '
                'single sound but a "color".',
            tr:
                'Akor = aynı anda çalınan (en az) üç nota. Tek bir ses değil, '
                'bir "renk"tir.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Major', tr: 'Majör'),
          t(
            en: 'Bright, cheerful, "open". Example — C major: C-E-G.',
            tr: 'Parlak, neşeli, "açık" duyulur. Örnek — C majör: C-E-G.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Minor', tr: 'Minör'),
          t(
            en: 'Darker, sadder, more "closed". Example — A minor: A-C-E.',
            tr: 'Daha koyu, hüzünlü, "kapalı" duyulur. Örnek — A minör: A-C-E.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Don\'t try to pick apart the notes; listen to the chord\'s '
                'overall mood.',
            tr:
                'Notaları tek tek çözmeye çalışma; akorun genel "havasını" '
                'dinle.',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch2',
    title: t(en: '2 · F & G Major', tr: '2 · F & G Majör'),
    pool: [_c('F', ChordQuality.major), _c('G', ChordQuality.major)],
    concept: Concept(
      title: t(en: 'More Major', tr: 'Daha Fazla Majör'),
      sections: [
        ConceptSection(
          t(
            en:
                'F and G major — the same "bright major" feel on different '
                'roots. The root changes; the color stays.',
            tr:
                'F ve G majör — aynı "parlak majör" hissi, farklı köklerde. '
                'Kök değişse de renk aynı kalır.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en: 'Start recognizing the major color independent of the root.',
            tr: 'Majör rengini kökten bağımsız tanımaya başlamak.',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch3',
    title: t(en: '3 · D & E Minor', tr: '3 · D & E Minör'),
    pool: [_c('D', ChordQuality.minor), _c('E', ChordQuality.minor)],
    concept: Concept(
      title: t(en: 'Minor Chords', tr: 'Minör Akorlar'),
      sections: [
        ConceptSection(
          t(
            en:
                'D and E minor — the minor color on different roots. Dark, '
                'melancholic feel.',
            tr: 'D ve E minör — minör rengi farklı köklerde. Koyu, hüzünlü his.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Compare', tr: 'Karşılaştır'),
          t(
            en:
                'The difference between major and minor lives in the middle '
                '(third) note — just a half step. Yet the emotion completely '
                'changes.',
            tr:
                'Majör ile minör arasındaki fark aslında ortadaki (üçlü) '
                'notadadır — sadece yarım ses. Ama duygu tamamen değişir.',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch4',
    title: t(en: '4 · Mixed Chords', tr: '4 · Karışık Akorlar'),
    pool: [
      _c('C', ChordQuality.major),
      _c('A', ChordQuality.minor),
      _c('F', ChordQuality.major),
      _c('G', ChordQuality.major),
    ],
    concept: Concept(
      title: t(en: 'Mixed: Major or Minor?', tr: 'Karışık: Majör mü Minör mü?'),
      sections: [
        ConceptSection(
          t(
            en: 'Major and minor chords arrive shuffled across different roots.',
            tr: 'Farklı köklerde majör ve minör akorlar karışık gelir.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Tell them apart purely by color (bright vs. sad) without '
                'knowing the root.',
            tr:
                'Kökü bilmeden yalnızca renkten (parlak mı, hüzünlü mü) '
                'ayırmak.',
          ),
        ),
      ],
    ),
  ),
  // A1 — akor kapsamı: dört nitelik (renk) tanıma.
  ChordLesson(
    id: 'ch5',
    title: t(en: '5 · Diminished & Augmented', tr: '5 · Eksik & Artık'),
    recognizeBy: ChordRecognizeBy.quality,
    // Aynı kök (C) üstünde dört renk yan yana → kontrastı net duy.
    pool: [
      _c('C', ChordQuality.major),
      _c('C', ChordQuality.minor),
      _c('C', ChordQuality.diminished),
      _c('C', ChordQuality.augmented),
    ],
    concept: Concept(
      title: t(
        en: 'Diminished & Augmented Chords',
        tr: 'Eksik & Artık Akorlar',
      ),
      sections: [
        ConceptSection(
          t(
            en:
                'Beyond major and minor there are two more "colors". We get '
                'them by shifting the top (fifth) note of the chord.',
            tr:
                'Majör ve minör dışında iki "renk" daha var. Bunları akorun en '
                'üstteki (beşli) notasını kaydırarak elde ederiz.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Diminished (dim)', tr: 'Eksik (dim)'),
          t(
            en:
                'Tense, unstable, slightly "eerie". Two minor thirds stacked: '
                'root + 3 + 3 semitones (e.g. C-Eb-Gb).',
            tr:
                'Gergin, kararsız, biraz "tekinsiz" duyulur. İki minör üçlü '
                'üst üste: kök + 3 + 3 yarım ses (ör. C-Eb-Gb).',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Augmented (aug)', tr: 'Artık (aug)'),
          t(
            en:
                'Dreamlike, "suspended", unresolved. Two major thirds stacked: '
                'root + 4 + 4 semitones (e.g. C-E-G#).',
            tr:
                'Rüya gibi, "asılı kalan", çözülmemiş bir his. İki majör üçlü '
                'üst üste: kök + 4 + 4 yarım ses (ör. C-E-G#).',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Major/minor sound "settled"; diminished/augmented sound '
                'restless, like they want to go somewhere.',
            tr:
                'Majör/minör "oturmuş" duyulur; eksik/artık "bir yere gitmek '
                'isteyen", huzursuz duyulur.',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch6',
    title: t(en: '6 · Tell the Colors Apart', tr: '6 · Renkleri Ayırt Et'),
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
    concept: Concept(
      title: t(en: 'Four Colors, Apart', tr: 'Dört Rengi Ayırt Et'),
      sections: [
        ConceptSection(
          t(
            en:
                'Major, minor, diminished, augmented — all four arrive '
                'shuffled across different roots.',
            tr:
                'Majör, minör, eksik, artık — dördü de farklı köklerde karışık '
                'gelir.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Recognize the color purely by feel, fully independent of the '
                'root.',
            tr: 'Rengi tamamen kökten bağımsız, sadece "his"ten tanımak.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Reminder', tr: 'Hatırlatma'),
          t(
            en:
                'Major: bright · Minor: sad · Diminished: tense · Augmented: '
                'suspended/dreamy.',
            tr:
                'Majör: parlak · Minör: hüzünlü · Eksik: gergin · Artık: '
                'asılı/rüyamsı.',
          ),
        ),
      ],
    ),
  ),
  // A4 — yedili akorlar (4 nota).
  ChordLesson(
    id: 'ch7',
    title: t(en: '7 · Seventh Chords', tr: '7 · Yedili Akorlar'),
    recognizeBy: ChordRecognizeBy.quality,
    pool: [
      _c('C', ChordQuality.dominant7),
      _c('C', ChordQuality.major7),
      _c('C', ChordQuality.minor7),
    ],
    concept: Concept(
      title: t(en: 'Seventh Chords', tr: 'Yedili Akorlar'),
      sections: [
        ConceptSection(
          t(
            en:
                'Add one more note (the 7th) to a triad and the color gets '
                'richer — the texture of jazz and pop comes from here.',
            tr:
                'Üçlü akora bir nota daha (7\'li) eklenince renk zenginleşir — '
                'cazın ve pop\'un dokusu buradan gelir.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Dominant 7', tr: 'Dominant 7'),
          t(
            en: 'Tense, "wants to resolve" (V7 → I). Example C7: C-E-G-Bb.',
            tr:
                'Gergin, "çözülmek isteyen" bir ses (V7 → I). Örnek C7: '
                'C-E-G-Bb.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Major 7', tr: 'Majör 7'),
          t(
            en: 'Soft, bright, dreamy. Example Cmaj7: C-E-G-B.',
            tr: 'Yumuşak, parlak, hülyalı. Örnek Cmaj7: C-E-G-B.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Minor 7', tr: 'Minör 7'),
          t(
            en: 'Velvety, mellow minor. Example Cm7: C-Eb-G-Bb.',
            tr: 'Kadifemsi, yumuşak minör. Örnek Cm7: C-Eb-G-Bb.',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch8',
    title: t(en: '8 · Seventh Colors', tr: '8 · Yedili Renkler'),
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
    concept: Concept(
      title: t(en: 'Seventh Colors', tr: 'Yedili Renkleri'),
      sections: [
        ConceptSection(
          t(
            en:
                'Sevenths arrive shuffled across roots. Two darker colors join '
                'in: Half-diminished 7 (tense but soft) and Diminished 7 (the '
                'most unstable, "crawling").',
            tr:
                'Yedililer farklı köklerde karışık gelir. Ayrıca iki koyu renk '
                'katılıyor: Yarım Eksik 7 (gergin ama yumuşak) ve Tam Eksik 7 '
                '(en kararsız, "sürünen").',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Tell the five seventh colors apart independent of root — the '
                'foundation of a jazz ear.',
            tr:
                'Beş yedili rengini kökten bağımsız ayırmak — caz kulağının '
                'temeli.',
          ),
        ),
      ],
    ),
  ),
  // A3 — akor çevrimleri (aynı notalar, farklı bas).
  ChordLesson(
    id: 'ch9',
    title: t(en: '9 · Chord Inversions', tr: '9 · Akor Çevrimleri'),
    recognizeBy: ChordRecognizeBy.inversion,
    // Tek akor (C majör) üç çevrimde → değişkeni yalnızca çevrim yap.
    pool: [
      _ci('C', ChordQuality.major, 0),
      _ci('C', ChordQuality.major, 1),
      _ci('C', ChordQuality.major, 2),
    ],
    concept: Concept(
      title: t(en: 'Chord Inversions', tr: 'Akor Çevrimleri'),
      sections: [
        ConceptSection(
          t(
            en:
                'A chord\'s notes stay the same, but we can change which one '
                'is at the bottom (the bass). That is called an "inversion".',
            tr:
                'Bir akorun notaları aynı kalır; ama en alttaki (bas) notayı '
                'değiştirebiliriz. Buna "çevrim" denir.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Root position', tr: 'Kapalı'),
          t(
            en: 'Root at the bottom — C major: C-E-G.',
            tr: 'Kök en altta — C majör: C-E-G.',
          ),
        ),
        ConceptSection(
          heading: t(en: '1st inversion', tr: '1. çevrim'),
          t(
            en: 'The third at the bottom — E-G-C.',
            tr: '3\'lü en altta — E-G-C.',
          ),
        ),
        ConceptSection(
          heading: t(en: '2nd inversion', tr: '2. çevrim'),
          t(
            en: 'The fifth at the bottom — G-C-E.',
            tr: '5\'li en altta — G-C-E.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'The color stays the same; listen for the LOWEST note — where '
                'is the floor?',
            tr: 'Akorun rengi aynı; en PES notaya kulak ver — taban nerede?',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch10',
    title: t(en: '10 · Mixed Inversions', tr: '10 · Karışık Çevrimler'),
    recognizeBy: ChordRecognizeBy.inversion,
    pool: [
      _ci('C', ChordQuality.major, 0),
      _ci('G', ChordQuality.major, 1),
      _ci('F', ChordQuality.major, 2),
      _ci('A', ChordQuality.minor, 1),
      _ci('D', ChordQuality.minor, 0),
      _ci('E', ChordQuality.minor, 2),
    ],
    concept: Concept(
      title: t(en: 'Mixed Inversions', tr: 'Karışık Çevrimler'),
      sections: [
        ConceptSection(
          t(
            en:
                'Different chords arrive in different inversions. The goal is '
                'to recognize only the INVERSION (the bass), not the chord '
                'itself.',
            tr:
                'Farklı akorlar, farklı çevrimlerde gelir. Amaç akorun '
                'kendisini değil, yalnızca ÇEVRİMİNİ (bası) tanımak.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Reminder', tr: 'Hatırlatma'),
          t(
            en:
                'Root position = root in bass · 1st inversion = third in bass '
                '· 2nd inversion = fifth in bass.',
            tr:
                'Kapalı = kök bası · 1. çevrim = 3\'lü bası · 2. çevrim = '
                '5\'li bası.',
          ),
        ),
      ],
    ),
  ),
  // A8 — kök kapsamı genişler: yeni kökler A ve E, iki nitelikle.
  ChordLesson(
    id: 'ch11',
    title: t(en: '11 · New Roots: A & E', tr: '11 · Yeni Kökler: A & E'),
    pool: [
      _c('A', ChordQuality.major),
      _c('A', ChordQuality.minor),
      _c('E', ChordQuality.major),
      _c('E', ChordQuality.minor),
    ],
    concept: Concept(
      title: t(en: 'Same Colors, New Homes', tr: 'Aynı Renkler, Yeni Evler'),
      sections: [
        ConceptSection(
          t(
            en:
                'A and E now appear as BOTH major and minor. The root is the '
                'same; only the middle (third) note decides the color.',
            tr:
                'A ve E artık HEM majör HEM minör olarak geliyor. Kök aynı; '
                'rengi yalnızca ortadaki (üçlü) nota belirliyor.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Hear root and color as two separate answers: first "which '
                'letter is home?", then "bright or sad?".',
            tr:
                'Kökü ve rengi iki ayrı cevap gibi duy: önce "ev hangi harf?", '
                'sonra "parlak mı hüzünlü mü?".',
          ),
        ),
      ],
    ),
  ),
  ChordLesson(
    id: 'ch12',
    title: t(en: '12 · Root Mix-Up', tr: '12 · Kök Karmaşası'),
    pool: [
      _c('A', ChordQuality.major),
      _c('E', ChordQuality.major),
      _c('D', ChordQuality.major),
      _c('A', ChordQuality.minor),
      _c('E', ChordQuality.minor),
      _c('B', ChordQuality.minor),
    ],
    concept: Concept(
      title: t(en: 'Six Chords, Full Answer', tr: 'Altı Akor, Tam Cevap'),
      sections: [
        ConceptSection(
          t(
            en:
                'D major and B minor join the family. Six chords, shuffled — '
                'and the answer needs BOTH the root and the color.',
            tr:
                'D majör ve B minör aileye katılıyor. Altı akor karışık geliyor '
                '— cevap artık HEM kökü HEM rengi istiyor.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Catch the bass note first (the home letter), then let the '
                'mood tell you major or minor.',
            tr:
                'Önce bas notayı yakala (ev harfi), sonra havasına bak: majör '
                'mü minör mü?',
          ),
        ),
      ],
    ),
  ),
];
