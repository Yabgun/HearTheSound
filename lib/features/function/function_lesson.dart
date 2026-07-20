import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/major_key.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';

// -----------------------------------------------------------------------------
// AKOR İŞLEVİ — bir tonalitede akorun "görevi"
//
// Sadelik için kanonik Do majör tonalitesinde kurulur. Her derece bir akora,
// bir Roman rakamına ve bir işleve karşılık gelir. Bu ekranın amacı kullanıcıya
// akor adını ezberletmek değil; akorun "ev / hazırlık / gerilim" davranışını
// duydurmaktır.
//
// i18n: tüm öğretici metinler AKTİF DİLE göre kurulur (EN varsayılan, TR
// seçilebilir). Ders listeleri locale-anahtarlı önbellekten döner; dil
// değişince bir sonraki erişim yeni dilde kurar.
// -----------------------------------------------------------------------------

/// Armonik işlev ailesi.
enum HarmonicFunction { tonic, subdominant, dominant }

extension HarmonicFunctionLabel on HarmonicFunction {
  String get label => switch (this) {
    HarmonicFunction.tonic => t(en: 'Tonic', tr: 'Tonik'),
    HarmonicFunction.subdominant => t(en: 'Subdominant', tr: 'Subdominant'),
    HarmonicFunction.dominant => t(en: 'Dominant', tr: 'Dominant'),
  };

  String get listeningCue => switch (this) {
    HarmonicFunction.tonic => t(
      en: 'stays home — the sentence feels finished',
      tr: 'evde kalır, cümle bitmiş gibi oturur',
    ),
    HarmonicFunction.subdominant => t(
      en: 'moves away from home, starts motion',
      tr: 'evden uzaklaştırır, hareket başlatır',
    ),
    HarmonicFunction.dominant => t(
      en: 'builds tension, wants to return home',
      tr: 'gerilim kurar, eve dönmek ister',
    ),
  };
}

/// Bir derece = akor + Roman rakamı + işlev + öğrenme ipucu.
class DegreeChord {
  final Chord chord;
  final String roman;
  final HarmonicFunction function;

  /// Kart üstünde kısa ipucu: kullanıcının duyarken arayacağı his.
  final String roleHint;

  /// Daha uzun açıklama: bu akor neden o işlev ailesinde?
  final String why;

  const DegreeChord(
    this.chord,
    this.roman,
    this.function, {
    required this.roleHint,
    required this.why,
  });

  /// Derecenin teorik kimliğini koruyup akoru blok halinde taşır.
  /// Dersin öğren, söyle ve tanı safhaları aynı oktavı paylaşır.
  DegreeChord transposedBy(int semitones) => DegreeChord(
    Chord(
      Note(chord.root.midi + semitones),
      chord.quality,
      inversion: chord.inversion,
    ),
    roman,
    function,
    roleHint: roleHint,
    why: why,
  );
}

/// Do majör tonik referansı (ev). Hedef akordan önce çalınır.
final Chord tonicReference = Chord(Note.fromName('C', 4), ChordQuality.major);

/// Aynı ders havuzundaki I derecesi, o dersin tonik referansıdır. Böylece
/// ses aralığı için oktav kaydırılmış derslerde de "ev" aynı yerde kalır.
Chord tonicForDegrees(List<DegreeChord> degrees) => degrees
    .firstWhere((degree) => degree.roman == 'I', orElse: () => degrees.first)
    .chord;

/// Derece havuzunu tek bir tam-oktav offset'iyle kullanıcının ses aralığına
/// taşır. Tek tek nota taşınmaz; akorların ve derecelerin ilişkisi korunur.
List<DegreeChord> transposeDegreesForVoice(
  List<DegreeChord> degrees,
  VocalRange? range,
) {
  final offset = octaveOffsetFor(
    degrees.expand((degree) => degree.chord.notes).map((note) => note.midi),
    range,
  );
  return offset == 0
      ? List<DegreeChord>.from(degrees)
      : degrees.map((degree) => degree.transposedBy(offset)).toList();
}

DegreeChord _d(
  String root,
  ChordQuality q,
  String roman,
  HarmonicFunction f, {
  required String roleHint,
  required String why,
}) => DegreeChord(
  Chord(Note.fromName(root, 4), q),
  roman,
  f,
  roleHint: roleHint,
  why: why,
);

/// Do majör dereceleri — aktif dile göre kurulur (getter: dil değişimini izler).
DegreeChord get degI => _d(
  'C',
  ChordQuality.major,
  'I',
  HarmonicFunction.tonic,
  roleHint: t(en: 'home itself', tr: 'evin kendisi'),
  why: t(
    en:
        'C-E-G is the central chord of C major. When it sounds, the sentence '
        'feels finished.',
    tr: 'C-E-G, Do majörün merkez akorudur. Duyunca cümle bitmiş gibi oturur.',
  ),
);
DegreeChord get degII => _d(
  'D',
  ChordQuality.minor,
  'ii',
  HarmonicFunction.subdominant,
  roleHint: t(en: 'preparation, kin of IV', tr: 'IV’e akraba hazırlık'),
  why: t(
    en:
        'D-F-A shares the notes F-A with the IV chord. It prepares motion, '
        'not home.',
    tr:
        'D-F-A, IV akoruyla F-A ortak seslerini paylaşır. Eve değil, harekete '
        'hazırlar.',
  ),
);
DegreeChord get degIII => _d(
  'E',
  ChordQuality.minor,
  'iii',
  HarmonicFunction.tonic,
  roleHint: t(en: 'calm color, kin of I', tr: 'I’e akraba sakin renk'),
  why: t(
    en:
        'E-G-B shares E-G with the I chord. It sits close to the center and '
        'sounds calmer.',
    tr:
        'E-G-B, I akoruyla E-G ortak seslerini paylaşır. Merkeze yakın ve daha '
        'sakindir.',
  ),
);
DegreeChord get degIV => _d(
  'F',
  ChordQuality.major,
  'IV',
  HarmonicFunction.subdominant,
  roleHint: t(en: 'moving away from home', tr: 'evden uzaklaşma'),
  why: t(
    en:
        'F-A-C moves you away from the tonic without harsh tension. It opens '
        'space to reach V.',
    tr:
        'F-A-C, tonikten uzaklaştırır ama sert gerilim kurmaz. V’ye gitmek '
        'için alan açar.',
  ),
);
DegreeChord get degV => _d(
  'G',
  ChordQuality.major,
  'V',
  HarmonicFunction.dominant,
  roleHint: t(en: 'wants to come home', tr: 'eve dönmek ister'),
  why: t(
    en:
        'Inside G-B-D, the note B longs to resolve to C. That is why it gives '
        'the strongest pull home.',
    tr:
        'G-B-D içindeki B sesi C’ye çözülmek ister. Bu yüzden en güçlü dönüş '
        'hissini verir.',
  ),
);
DegreeChord get degVI => _d(
  'A',
  ChordQuality.minor,
  'vi',
  HarmonicFunction.tonic,
  roleHint: t(en: 'soft shadow of I', tr: 'I’in yumuşak gölgesi'),
  why: t(
    en:
        'A-C-E shares C-E with the I chord. It stays home, but with a sadder '
        'color.',
    tr:
        'A-C-E, I akoruyla C-E ortak seslerini paylaşır. Evde kalır ama rengi '
        'daha hüzünlüdür.',
  ),
);
DegreeChord get degVII => _d(
  'B',
  ChordQuality.diminished,
  'vii°',
  HarmonicFunction.dominant,
  roleHint: t(en: 'sharp tension of V', tr: 'V’nin keskin gerilimi'),
  why: t(
    en:
        'B-D-F is dominant tension at its barest. The note B longs to resolve '
        'to C.',
    tr:
        'B-D-F, dominant gerilimin en çıplak halidir. B sesi C’ye çözülmek '
        'ister.',
  ),
);

class FunctionLesson {
  final String id;
  final String title;
  final List<DegreeChord> pool;
  final MajorKey key;
  final Concept? concept;

  const FunctionLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.key = MajorKey.c,
    this.concept,
  });

  /// Kanonik Do majör dersini başka bir majör merkeze taşır. Derece numarası,
  /// akor niteliği ve işlev ailesi değişmez; yalnızca duyulan mutlak notalar
  /// değişir.
  FunctionLesson inKey(MajorKey targetKey) => FunctionLesson(
    id: id,
    title: title,
    pool: pool
        .map((degree) => degree.transposedBy(targetKey.semitonesFromC))
        .toList(),
    key: targetKey,
    concept: concept,
  );
}

/// Ders listesi — locale-anahtarlı önbellek: dil değişince yeni dilde kurulur.
final Map<String, List<FunctionLesson>> _lessonCache = {};

List<FunctionLesson> get functionLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildFunctionLessons);

// ---------------------------------------------------------------------------
// TONALİTE YOLCULUĞU (§1C) — beşler çemberindeki yeni merkezler için ÜRETİLEN
// işlev dersleri. El yazımı fn1–fn3 (C/G/D) girişten sonra gelen ustalık
// transferi: her ders TÜM 7 dereceyi içerir (C-kanonik havuz; akış inKey ile
// hedef merkeze taşır). Kimlikler benzersiz ('fn_j_<tonik>') → çakışmaz.
// El yazımı içerik dokunulmaz; hacim "bedava" büyür.
// ---------------------------------------------------------------------------

/// Yolculuğun geçtiği yeni merkezler (C/G/D handwritten; bunlar üretilir).
/// İlerleme yolculuğu da (progression_lesson.dart) aynı sırayı kullanır.
const List<MajorKey> journeyKeys = [MajorKey.a, MajorKey.e, MajorKey.f];

Concept _journeyFunctionConcept() => Concept(
  title: t(en: 'Key Journey · Functions', tr: 'Tonalite Yolculuğu · İşlevler'),
  sections: [
    ConceptSection(
      t(
        en:
            'The same seven functions (I–vii°) you learned in C — now heard from '
            'a new home key. The Roman numerals and their feelings stay '
            'identical; only the absolute pitches move.',
        tr:
            'C’de öğrendiğin aynı yedi işlev (I–vii°) — şimdi yeni bir ev '
            'tonaliteden. Roman rakamları ve hisleri birebir aynı; yalnızca '
            'mutlak perdeler kayar.',
      ),
    ),
    ConceptSection(
      heading: t(en: 'Why', tr: 'Neden'),
      t(
        en:
            'Recognizing function independent of the key is real harmonic '
            'hearing — here it becomes portable across the whole circle.',
        tr:
            'İşlevi tonaliteden bağımsız tanımak gerçek armonik duyuştur — burada '
            'tüm çember boyunca taşınabilir hale gelir.',
      ),
    ),
  ],
);

final Map<String, List<FunctionLesson>> _journeyCache = {};

/// Üretilen işlev yolculuğu dersleri (locale-anahtarlı önbellek).
List<FunctionLesson> get functionJourneyLessons =>
    _journeyCache.putIfAbsent(ContentLocale.code, _buildFunctionJourney);

List<FunctionLesson> _buildFunctionJourney() => [
  for (final key in journeyKeys)
    FunctionLesson(
      id: 'fn_j_${key.tonicName.toLowerCase()}',
      title: t(
        en: 'Functions in ${key.tonicName} Major',
        tr: '${key.tonicName} Majörde İşlevler',
      ),
      // Tüm 7 derece (C-kanonik); akış inKey(key) ile hedefe taşır.
      pool: [degI, degII, degIII, degIV, degV, degVI, degVII],
      key: key,
      concept: _journeyFunctionConcept(),
    ),
];

List<FunctionLesson> _buildFunctionLessons() => [
  FunctionLesson(
    id: 'fn1',
    title: t(en: '1 · Three Core Functions', tr: '1 · Üç Temel İşlev'),
    pool: [degI, degIV, degV], // birer temsilci: Tonik, Subdominant, Dominant
    key: MajorKey.c,
    concept: Concept(
      title: t(en: 'A Chord\'s Function', tr: 'Akorun İşlevi'),
      sections: [
        ConceptSection(
          t(
            en:
                'In a key, every chord has a job. In C major we first treat the '
                'C chord as home. Then we listen to how the next chord behaves: '
                'does it settle home, move away from home, or build tension to '
                'return home?',
            tr:
                'Bir tonalitede her akorun bir görevi vardır. Do majörde önce C '
                'akorunu ev gibi düşünürüz. Sonra gelen akorun davranışını '
                'dinleriz: eve mi oturuyor, evden mi uzaklaştırıyor, yoksa eve '
                'dönmek için gerilim mi kuruyor?',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tonic (home)', tr: 'Tonik (ev)'),
          t(
            en:
                'Peace, arrival, rest. In C major this is I (the C chord). The '
                'sentence feels finished here.',
            tr:
                'Huzur, varış, dinlenme. Do majörde I (C akoru). Cümle burada '
                'bitmiş gibi hisseder.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'Subdominant (setting out)',
            tr: 'Subdominant (yola çıkış)',
          ),
          t(
            en:
                'Moving away from home and preparing. IV (the F chord) sets you '
                'on the road; it usually opens space toward the dominant.',
            tr:
                'Evden uzaklaşma ve hazırlık. IV (F akoru) seni yola çıkarır; '
                'çoğu zaman dominanta doğru alan açar.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'Dominant (the pull home)',
            tr: 'Dominant (eve dönüş isteği)',
          ),
          t(
            en:
                'Tension and the desire to resolve. V (the G chord) wants to '
                'return to the tonic; the ear expects a C chord right after.',
            tr:
                'Gerilim ve çözülme arzusu. V (G akoru) tonike dönmek ister; '
                'kulak arkasından bir C akoru bekler.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'How to listen', tr: 'Nasıl dinle?'),
          t(
            en:
                'First the tonic plays, then the target chord. Don\'t try to '
                'guess the chord\'s name; choose its behavior: home, '
                'preparation, tension.',
            tr:
                'Önce tonik çalınır, sonra hedef akor. Akor adını tahmin etmeye '
                'çalışma; davranışını seç: ev, hazırlık, gerilim.',
          ),
        ),
      ],
    ),
  ),
  FunctionLesson(
    id: 'fn2',
    title: t(en: '2 · All the Degrees', tr: '2 · Tüm Dereceler'),
    pool: [degI, degII, degIII, degIV, degV, degVI, degVII],
    key: MajorKey.g,
    concept: Concept(
      title: t(
        en: 'Seven Degrees, Three Functions',
        tr: 'Yedi Derece, Üç İşlev',
      ),
      sections: [
        ConceptSection(
          t(
            en:
                'C major has seven degree chords, but the goal of this lesson '
                'is not to memorize seven separate labels. The goal is to sort '
                'chords into three behavior families: those that stay home, '
                'those that move away, and those that pull you back home.',
            tr:
                'Do majörün yedi derece akoru vardır ama bu dersin amacı yedi '
                'ayrı etiketi ezberlemek değil. Amaç, akorları üç davranış '
                'ailesine ayırmak: evde kalanlar, evden uzaklaştıranlar, eve '
                'döndürmek isteyenler.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'Tonic family: I, iii, vi',
            tr: 'Tonik ailesi: I, iii, vi',
          ),
          t(
            en:
                'These chords share notes with the I chord and sound close to '
                'the center. I is home itself; iii and vi are different shades '
                'of home.',
            tr:
                'Bu akorlar I akoruyla ortak sesler paylaşır ve merkeze yakın '
                'duyulur. I evin kendisi, iii ve vi ise evin farklı renkleridir.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'Subdominant family: IV, ii',
            tr: 'Subdominant ailesi: IV, ii',
          ),
          t(
            en:
                'These chords move away from home and start motion. IV is the '
                'clearest example; ii shares notes with IV, so it belongs to '
                'the same preparation family.',
            tr:
                'Bu akorlar evden uzaklaştırır ve hareket başlatır. IV en net '
                'örnektir; ii, IV ile ortak sesler taşıdığı için aynı hazırlık '
                'ailesindedir.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'Dominant family: V, vii°',
            tr: 'Dominant ailesi: V, vii°',
          ),
          t(
            en:
                'These chords build tension and want to resolve to the tonic. '
                'V is the strong pull home; vii° is the sharper edge of that '
                'same tension.',
            tr:
                'Bu akorlar gerilim kurar ve tonike çözülmek ister. V güçlü '
                'dönüş hissidir; vii° bu gerilimin daha keskin halidir.',
          ),
        ),
        ConceptSection(
          heading: t(
            en: 'What do I do in the test?',
            tr: 'Testte ne yapıyorum?',
          ),
          t(
            en:
                'You choose the behavior, not the chord name. Does the chord '
                'you hear feel like "home", "preparation", or "tension / the '
                'pull to return"?',
            tr:
                'Akor adını değil davranışı seçiyorsun. Duyduğun akor "ev", '
                '"hazırlık" veya "gerilim/dönüş isteği" gibi mi hissettiriyor?',
          ),
        ),
      ],
    ),
  ),
  // A9 — üçüncü tonal merkez: D Majör (beceri transferinin kanıtı).
  FunctionLesson(
    id: 'fn3',
    title: t(en: '3 · Functions in D Major', tr: '3 · D Majörde İşlevler'),
    pool: [degI, degII, degIII, degIV, degV, degVI, degVII],
    key: MajorKey.d,
    concept: Concept(
      title: t(en: 'The Skill Travels', tr: 'Beceri Taşınır'),
      sections: [
        ConceptSection(
          t(
            en:
                'New home: D major. Every absolute note changes, yet I is '
                'still home, IV still prepares, V still pulls back. If you '
                'can hear that HERE too, you own the skill — not the key.',
            tr:
                'Yeni ev: D Majör. Duyulan tüm mutlak notalar değişiyor ama I '
                'hâlâ ev, IV hâlâ hazırlık, V hâlâ dönüş çağrısı. Bunu BURADA '
                'da duyabiliyorsan beceri senindir — tonalitenin değil.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Why D major?', tr: 'Neden D Majör?'),
          t(
            en:
                'Two sharps (F# and C#) give the ear a noticeably brighter '
                'landscape than C or G — a real transfer test.',
            tr:
                'İki diyez (F# ve C#) kulağa C ve G\'den belirgin biçimde daha '
                'parlak bir manzara verir — gerçek bir transfer sınavı.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'How to listen', tr: 'Nasıl dinle?'),
          t(
            en:
                'Exactly as before: first home (the D chord), then the '
                'target. Choose the behavior, never the letter names.',
            tr:
                'Aynı eskisi gibi: önce ev (D akoru), sonra hedef. Harf '
                'adlarını değil davranışı seç.',
          ),
        ),
      ],
    ),
  ),
];
