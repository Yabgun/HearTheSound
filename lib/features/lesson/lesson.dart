import '../../core/note.dart';

/// Bir ders = kimlik + başlık + üzerinde çalışılacak nota havuzu.
/// [id] ilerleme kaydında beceri anahtarı ve kilit takibi için kullanılır.
class Lesson {
  final String id;
  final String title;
  final List<Note> pool;
  const Lesson({required this.id, required this.title, required this.pool});
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
  Lesson(id: 'first_notes', title: '1 · İlk Notalar', pool: _oct(['C', 'E', 'G'], 4)),
  Lesson(id: 'l2_cde', title: '2 · Komşular', pool: _oct(['C', 'D', 'E'], 4)),
  Lesson(id: 'l3_penta', title: '3 · Beşli', pool: _oct(['C', 'D', 'E', 'F', 'G'], 4)),
  Lesson(
    id: 'l4_diatonic',
    title: '4 · Do Majör',
    pool: _oct(['C', 'D', 'E', 'F', 'G', 'A', 'B'], 4),
  ),
  Lesson(
    id: 'l5_chromatic',
    title: '5 · Kromatik',
    pool: noteRange(Note.fromName('C', 4), Note.fromName('B', 4)),
  ),
];
