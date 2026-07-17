import '../../core/chord.dart';
import '../../core/concept.dart';
import '../../core/major_key.dart';
import '../../core/note.dart';
import '../../core/octave_mapping.dart';
import '../../core/vocal_range.dart';

// -----------------------------------------------------------------------------
// AKOR İŞLEVİ — bir tonalitede akorun "görevi"
//
// Sadelik için sabit Do majör tonalitesinde çalışırız. Her derece bir akora,
// bir Roman rakamına ve bir işleve karşılık gelir. Bu ekranın amacı kullanıcıya
// akor adını ezberletmek değil; akorun "ev / hazırlık / gerilim" davranışını
// duydurmaktır.
// -----------------------------------------------------------------------------

/// Armonik işlev ailesi.
enum HarmonicFunction { tonic, subdominant, dominant }

extension HarmonicFunctionLabel on HarmonicFunction {
  String get label => switch (this) {
        HarmonicFunction.tonic => 'Tonik',
        HarmonicFunction.subdominant => 'Subdominant',
        HarmonicFunction.dominant => 'Dominant',
      };

  String get listeningCue => switch (this) {
        HarmonicFunction.tonic => 'evde kalır, cümle bitmiş gibi oturur',
        HarmonicFunction.subdominant => 'evden uzaklaştırır, hareket başlatır',
        HarmonicFunction.dominant => 'gerilim kurar, eve dönmek ister',
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
    .firstWhere(
      (degree) => degree.roman == 'I',
      orElse: () => degrees.first,
    )
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
}) =>
    DegreeChord(
      Chord(Note.fromName(root, 4), q),
      roman,
      f,
      roleHint: roleHint,
      why: why,
    );

/// Do majör dereceleri.
final DegreeChord degI = _d(
  'C',
  ChordQuality.major,
  'I',
  HarmonicFunction.tonic,
  roleHint: 'evin kendisi',
  why: 'C-E-G, Do majörün merkez akorudur. Duyunca cümle bitmiş gibi oturur.',
);
final DegreeChord degII = _d(
  'D',
  ChordQuality.minor,
  'ii',
  HarmonicFunction.subdominant,
  roleHint: 'IV’e akraba hazırlık',
  why: 'D-F-A, IV akoruyla F-A ortak seslerini paylaşır. Eve değil, harekete hazırlar.',
);
final DegreeChord degIII = _d(
  'E',
  ChordQuality.minor,
  'iii',
  HarmonicFunction.tonic,
  roleHint: 'I’e akraba sakin renk',
  why: 'E-G-B, I akoruyla E-G ortak seslerini paylaşır. Merkeze yakın ve daha sakindir.',
);
final DegreeChord degIV = _d(
  'F',
  ChordQuality.major,
  'IV',
  HarmonicFunction.subdominant,
  roleHint: 'evden uzaklaşma',
  why: 'F-A-C, tonikten uzaklaştırır ama sert gerilim kurmaz. V’ye gitmek için alan açar.',
);
final DegreeChord degV = _d(
  'G',
  ChordQuality.major,
  'V',
  HarmonicFunction.dominant,
  roleHint: 'eve dönmek ister',
  why: 'G-B-D içindeki B sesi C’ye çözülmek ister. Bu yüzden en güçlü dönüş hissini verir.',
);
final DegreeChord degVI = _d(
  'A',
  ChordQuality.minor,
  'vi',
  HarmonicFunction.tonic,
  roleHint: 'I’in yumuşak gölgesi',
  why: 'A-C-E, I akoruyla C-E ortak seslerini paylaşır. Evde kalır ama rengi daha hüzünlüdür.',
);
final DegreeChord degVII = _d(
  'B',
  ChordQuality.diminished,
  'vii°',
  HarmonicFunction.dominant,
  roleHint: 'V’nin keskin gerilimi',
  why: 'B-D-F, dominant gerilimin en çıplak halidir. B sesi C’ye çözülmek ister.',
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

final List<FunctionLesson> functionLessons = [
  FunctionLesson(
    id: 'fn1',
    title: '1 · Üç Temel İşlev',
    pool: [degI, degIV, degV], // birer temsilci: Tonik, Subdominant, Dominant
    key: MajorKey.c,
    concept: const Concept(
      title: 'Akorun İşlevi',
      sections: [
        ConceptSection(
          'Bir tonalitede her akorun bir görevi vardır. Do majörde önce C akorunu '
          'ev gibi düşünürüz. Sonra gelen akorun davranışını dinleriz: eve mi '
          'oturuyor, evden mi uzaklaştırıyor, yoksa eve dönmek için gerilim mi kuruyor?',
        ),
        ConceptSection(
          heading: 'Tonik (ev)',
          'Huzur, varış, dinlenme. Do majörde I (C akoru). Cümle burada bitmiş '
          'gibi hisseder.',
        ),
        ConceptSection(
          heading: 'Subdominant (yola çıkış)',
          'Evden uzaklaşma ve hazırlık. IV (F akoru) seni yola çıkarır; çoğu zaman '
          'dominanta doğru alan açar.',
        ),
        ConceptSection(
          heading: 'Dominant (eve dönüş isteği)',
          'Gerilim ve çözülme arzusu. V (G akoru) tonike dönmek ister; kulak '
          'arkasından bir C akoru bekler.',
        ),
        ConceptSection(
          heading: 'Nasıl dinle?',
          'Önce tonik çalınır, sonra hedef akor. Akor adını tahmin etmeye çalışma; '
          'davranışını seç: ev, hazırlık, gerilim.',
        ),
      ],
    ),
  ),
  FunctionLesson(
    id: 'fn2',
    title: '2 · Tüm Dereceler',
    pool: [degI, degII, degIII, degIV, degV, degVI, degVII],
    key: MajorKey.g,
    concept: const Concept(
      title: 'Yedi Derece, Üç İşlev',
      sections: [
        ConceptSection(
          'Do majörün yedi derece akoru vardır ama bu dersin amacı yedi ayrı '
          'etiketi ezberlemek değil. Amaç, akorları üç davranış ailesine ayırmak: '
          'evde kalanlar, evden uzaklaştıranlar, eve döndürmek isteyenler.',
        ),
        ConceptSection(
          heading: 'Tonik ailesi: I, iii, vi',
          'Bu akorlar I akoruyla ortak sesler paylaşır ve merkeze yakın duyulur. '
          'I evin kendisi, iii ve vi ise evin farklı renkleridir.',
        ),
        ConceptSection(
          heading: 'Subdominant ailesi: IV, ii',
          'Bu akorlar evden uzaklaştırır ve hareket başlatır. IV en net örnektir; '
          'ii, IV ile ortak sesler taşıdığı için aynı hazırlık ailesindedir.',
        ),
        ConceptSection(
          heading: 'Dominant ailesi: V, vii°',
          'Bu akorlar gerilim kurar ve tonike çözülmek ister. V güçlü dönüş hissidir; '
          'vii° bu gerilimin daha keskin halidir.',
        ),
        ConceptSection(
          heading: 'Testte ne yapıyorum?',
          'Akor adını değil davranışı seçiyorsun. Duyduğun akor "ev", "hazırlık" '
          'veya "gerilim/dönüş isteği" gibi mi hissettiriyor?',
        ),
      ],
    ),
  ),
];
