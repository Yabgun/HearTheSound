import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/note.dart';

/// Bir ders = kimlik + başlık + üzerinde çalışılacak nota havuzu (+ kavram kartı).
/// [id] ilerleme kaydında beceri anahtarı ve kilit takibi için kullanılır.
class Lesson {
  final String id;
  final String title;
  final List<Note> pool;
  final Concept? concept; // öğretici kart — test'ten önce öğret

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir
  /// (bkz. lesson_intro_page.dart). Kullanıcının "neyi neden yapıyorum"
  /// sorusuna daha ilk ekranda cevap verir.
  final String? promise;

  const Lesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
    this.promise,
  });
}

/// Bir tanıma oturumunun sonucu.
///
/// [mistakes] karıştırma kayıtlarıdır: her yanlış cevap için dil-bağımsız bir
/// anahtar ('tip:beklenen>seçilen', ör. 'note:C>E', 'quality:major7>dominant7').
/// İlerleme denetleyicisi bunları toplayıp "en çok karıştırılanlar" içgörüsünü
/// besler — hangi çiftlerin ekstra çalışma istediğini gösterir.
class LessonResult {
  final int correct;
  final int total;
  final List<String> mistakes;
  const LessonResult(this.correct, this.total, {this.mistakes = const []});

  double get accuracy => total == 0 ? 0 : correct / total;
}

/// Bir tanıma oturumunu "geçme" barajı — dersi tamamlar (kilit açar), taç
/// yükseltir ve tamamlama ekranında kutlama/tekrar-dene ayrımını belirler.
/// Tek kaynak: hem akış sayfaları hem tamamlama ekranı bunu kullanır.
const double kPassAccuracy = 0.7;

List<Note> _oct(List<String> names, int octave) => [
  for (final n in names) Note.fromName(n, octave),
];

/// Müfredat — kolaydan zora büyüyen ders dizisi. Her ders aynı Duy→Söyle→Tanı
/// döngüsüyle çalışır; bir ders geçilince (≥%70) sonraki açılır.
/// Locale-anahtarlı önbellekten döner (i18n).
///
/// NOT: ilk dersin id'si 'first_notes' korunuyor ki mevcut ilerleme kaybolmasın.
final Map<String, List<Lesson>> _lessonCache = {};

List<Lesson> get lessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildLessons);

List<Lesson> _buildLessons() => [
  Lesson(
    id: 'first_notes',
    title: t(en: '1 · First Notes', tr: '1 · İlk Notalar'),
    pool: _oct(['C', 'E', 'G'], 4),
    promise: t(
      en: 'You will tell three clearly different notes apart by ear — and sing '
          'them back.',
      tr: 'Birbirinden net ayrılan üç sesi kulağınla ayırt edecek ve sesinle '
          'söyleyebileceksin.',
    ),
    concept: Concept(
      title: t(en: 'Notes and Pitch', tr: 'Notalar ve Perde'),
      sections: [
        ConceptSection(
          t(
            en:
                'A "note" is a sound at a specific height (pitch). Every note '
                'has a name: C, D, E, F, G, A, B. (C = "Do".)',
            tr:
                'Bir "nota", belirli tizlikteki (perde) bir sestir. Her '
                'notanın bir adı vardır: C, D, E, F, G, A, B. (C = "Do".)',
          ),
        ),
        ConceptSection(
          heading: t(en: 'In this lesson', tr: 'Bu derste'),
          t(
            en:
                'We start with three well-separated notes: C, E, G. First '
                'listen and learn the names, then sing them, then recognize '
                'them without hints.',
            tr:
                'Birbirinden iyi ayrışan üç notayla başlıyoruz: C, E, G. Önce '
                'dinleyip adıyla tanı, sonra söyle, sonra ipuçsuz tanı.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Tip', tr: 'İpucu'),
          t(
            en:
                'Rather than memorizing the name, try to feel how "high" the '
                'sound sits.',
            tr: 'İsmi ezberlemekten çok sesin "yüksekliğini" hissetmeye çalış.',
          ),
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l2_cde',
    title: t(en: '2 · Neighbors', tr: '2 · Komşular'),
    pool: _oct(['C', 'D', 'E'], 4),
    promise: t(
      en: 'You will separate notes that sit close together — small steps stop '
          'blurring into each other.',
      tr: 'Birbirine yakın sesleri ayırabileceksin — küçük adımlar artık '
          'birbirine karışmayacak.',
    ),
    concept: Concept(
      title: t(en: 'Neighbor Notes', tr: 'Komşu Notalar'),
      sections: [
        ConceptSection(
          t(
            en:
                'C, D and E are neighbors. Because the distance between them '
                'is small, they are a bit harder to tell apart.',
            tr:
                'C, D, E birbirine komşu notalar. Aralarındaki mesafe küçük '
                'olduğu için ayırt etmesi biraz daha zordur.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'Separate nearby pitches without mixing them up — the ear '
                'gets used to hearing small steps.',
            tr:
                'Yakın perdeleri karıştırmadan ayırabilmek — kulağın küçük '
                'adımları duymaya alışır.',
          ),
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l3_penta',
    title: t(en: '3 · Five Notes', tr: '3 · Beşli'),
    pool: _oct(['C', 'D', 'E', 'F', 'G'], 4),
    promise: t(
      en: 'You will pick the right note among five — the range most simple '
          'melodies live in.',
      tr: 'Beş ses arasından doğrusunu seçebileceksin — basit melodilerin çoğu '
          'bu aralıkta yaşar.',
    ),
    concept: Concept(
      title: t(en: 'Five Notes', tr: 'Beş Nota'),
      sections: [
        ConceptSection(
          t(
            en:
                'C-D-E-F-G: the first five notes of the major scale '
                '(do-re-mi-fa-sol).',
            tr: 'C-D-E-F-G: majör dizinin ilk beş notası (do-re-mi-fa-sol).',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en:
                'The pool has grown — pick fast and accurately among five '
                'notes.',
            tr: 'Havuz büyüdü — beş nota arasında hızlı ve doğru seçim yapmak.',
          ),
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l4_diatonic',
    title: t(en: '4 · C Major', tr: '4 · Do Majör'),
    pool: _oct(['C', 'D', 'E', 'F', 'G', 'A', 'B'], 4),
    promise: t(
      en: 'You will recognize all seven notes of a major scale — the alphabet '
          'nearly every song is written in.',
      tr: 'Bir majör dizinin yedi sesini de tanıyabileceksin — neredeyse her '
          'şarkının yazıldığı alfabe.',
    ),
    concept: Concept(
      title: t(en: 'The C Major Scale', tr: 'Do Majör Dizisi'),
      sections: [
        ConceptSection(
          t(
            en:
                'The C major scale has seven notes: C-D-E-F-G-A-B '
                '(do-re-mi-fa-sol-la-si). The white keys of the piano.',
            tr:
                'Do majör dizisi yedi notadır: C-D-E-F-G-A-B '
                '(do-re-mi-fa-sol-la-si). Piyanodaki beyaz tuşlar.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Why does it matter?', tr: 'Neden önemli?'),
          t(
            en:
                'Most melodies and chords grow from this scale; it is like '
                'the "alphabet" of music.',
            tr:
                'Çoğu melodi ve akor bu diziden doğar; müziğin "alfabesi" '
                'gibidir.',
          ),
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l5_chromatic',
    title: t(en: '5 · Chromatic', tr: '5 · Kromatik'),
    pool: noteRange(Note.fromName('C', 4), Note.fromName('B', 4)),
    promise: t(
      en: 'You will hear all 12 notes — including the black keys. Nothing in '
          'music will be outside your ear after this.',
      tr: '12 sesin hepsini duyabileceksin — siyah tuşlar dahil. Bundan sonra '
          'müzikte kulağının dışında kalan ses olmayacak.',
    ),
    concept: Concept(
      title: t(en: 'Chromatic — 12 Notes', tr: 'Kromatik — 12 Nota'),
      sections: [
        ConceptSection(
          t(
            en:
                'All 12 notes within an octave: the black keys join the white '
                'ones (sharps/flats: C#, D#, F#, G#, A#).',
            tr:
                'Bir oktav içindeki tüm 12 nota: beyaz tuşlara ek olarak '
                'siyah tuşlar (diyez/bemol: C#, D#, F#, G#, A#).',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Half step', tr: 'Yarım ses'),
          t(
            en:
                'The smallest distance between two adjacent notes is called a '
                '"half step". The chromatic scale is half steps from start to '
                'end.',
            tr:
                'Ardışık iki nota arasındaki en küçük mesafeye "yarım ses" '
                'denir. Kromatik dizi baştan sona yarım ses adımlardan oluşur.',
          ),
        ),
        ConceptSection(
          heading: t(en: 'Goal', tr: 'Amaç'),
          t(
            en: 'The toughest distinction: telling all 12 pitches apart.',
            tr: 'En zorlu ayrım: 12 perdenin hepsini birbirinden ayırmak.',
          ),
        ),
      ],
    ),
  ),
];
