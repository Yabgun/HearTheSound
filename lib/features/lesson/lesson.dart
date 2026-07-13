import '../../core/concept.dart';
import '../../core/note.dart';

/// Bir ders = kimlik + başlık + üzerinde çalışılacak nota havuzu (+ kavram kartı).
/// [id] ilerleme kaydında beceri anahtarı ve kilit takibi için kullanılır.
class Lesson {
  final String id;
  final String title;
  final List<Note> pool;
  final Concept? concept; // öğretici kart — test'ten önce öğret
  const Lesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
  });
}

/// Bir tanıma oturumunun sonucu.
class LessonResult {
  final int correct;
  final int total;
  const LessonResult(this.correct, this.total);

  double get accuracy => total == 0 ? 0 : correct / total;
}

List<Note> _oct(List<String> names, int octave) =>
    [for (final n in names) Note.fromName(n, octave)];

/// Müfredat — kolaydan zora büyüyen ders dizisi. Her ders aynı Duy→Söyle→Tanı
/// döngüsüyle çalışır; bir ders geçilince (≥%70) sonraki açılır.
///
/// NOT: ilk dersin id'si 'first_notes' korunuyor ki mevcut ilerleme kaybolmasın.
final List<Lesson> lessons = [
  Lesson(
    id: 'first_notes',
    title: '1 · İlk Notalar',
    pool: _oct(['C', 'E', 'G'], 4),
    concept: const Concept(
      title: 'Notalar ve Perde',
      sections: [
        ConceptSection(
          'Bir "nota", belirli tizlikteki (perde) bir sestir. Her notanın bir '
          'adı vardır: C, D, E, F, G, A, B. (C = "Do".)',
        ),
        ConceptSection(
          heading: 'Bu derste',
          'Birbirinden iyi ayrışan üç notayla başlıyoruz: C, E, G. Önce dinleyip '
          'adıyla tanı, sonra söyle, sonra ipuçsuz tanı.',
        ),
        ConceptSection(
          heading: 'İpucu',
          'İsmi ezberlemekten çok sesin "yüksekliğini" hissetmeye çalış.',
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l2_cde',
    title: '2 · Komşular',
    pool: _oct(['C', 'D', 'E'], 4),
    concept: const Concept(
      title: 'Komşu Notalar',
      sections: [
        ConceptSection(
          'C, D, E birbirine komşu notalar. Aralarındaki mesafe küçük olduğu için '
          'ayırt etmesi biraz daha zordur.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Yakın perdeleri karıştırmadan ayırabilmek — kulağın küçük adımları '
          'duymaya alışır.',
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l3_penta',
    title: '3 · Beşli',
    pool: _oct(['C', 'D', 'E', 'F', 'G'], 4),
    concept: const Concept(
      title: 'Beş Nota',
      sections: [
        ConceptSection(
          'C-D-E-F-G: majör dizinin ilk beş notası (do-re-mi-fa-sol).',
        ),
        ConceptSection(
          heading: 'Amaç',
          'Havuz büyüdü — beş nota arasında hızlı ve doğru seçim yapmak.',
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l4_diatonic',
    title: '4 · Do Majör',
    pool: _oct(['C', 'D', 'E', 'F', 'G', 'A', 'B'], 4),
    concept: const Concept(
      title: 'Do Majör Dizisi',
      sections: [
        ConceptSection(
          'Do majör dizisi yedi notadır: C-D-E-F-G-A-B (do-re-mi-fa-sol-la-si). '
          'Piyanodaki beyaz tuşlar.',
        ),
        ConceptSection(
          heading: 'Neden önemli?',
          'Çoğu melodi ve akor bu diziden doğar; müziğin "alfabesi" gibidir.',
        ),
      ],
    ),
  ),
  Lesson(
    id: 'l5_chromatic',
    title: '5 · Kromatik',
    pool: noteRange(Note.fromName('C', 4), Note.fromName('B', 4)),
    concept: const Concept(
      title: 'Kromatik — 12 Nota',
      sections: [
        ConceptSection(
          'Bir oktav içindeki tüm 12 nota: beyaz tuşlara ek olarak siyah tuşlar '
          '(diyez/bemol: C#, D#, F#, G#, A#).',
        ),
        ConceptSection(
          heading: 'Yarım ses',
          'Ardışık iki nota arasındaki en küçük mesafeye "yarım ses" denir. '
          'Kromatik dizi baştan sona yarım ses adımlardan oluşur.',
        ),
        ConceptSection(
          heading: 'Amaç',
          'En zorlu ayrım: 12 perdenin hepsini birbirinden ayırmak.',
        ),
      ],
    ),
  ),
];
