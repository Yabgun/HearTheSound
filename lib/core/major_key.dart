import 'content_locale.dart';
import 'note.dart';

// -----------------------------------------------------------------------------
// MAJÖR TONALİTELER — işlev ve ilerleme içeriğinin taşınabilir armoni bağlamı
//
// İlk turda diyezli ve notasyon açısından açık üç merkez kullanılır. Model yeni
// tonaliteler eklemeye açıktır; derslerin dereceleri ve akorları C majörden bu
// merkeze blok halinde taşınır. Böylece Roman rakamı/işlev aynı kalır.
// -----------------------------------------------------------------------------

enum MajorKey {
  c('C', 0),
  g('G', 7),
  d('D', 2);

  const MajorKey(this.tonicName, this.semitonesFromC);

  final String tonicName;

  /// Görünen ad — aktif içerik diline göre ("C Major" / "C Majör").
  String get label => '$tonicName ${t(en: 'Major', tr: 'Majör')}';

  /// Kanonik C majöre göre tonalite farkı. Yalnızca perde sınıfını taşır;
  /// kullanıcının ses aralığına göre oktav eşlemesi derste ayrıca yapılır.
  final int semitonesFromC;

  Note tonicAtOctave(int octave) => Note.fromName(tonicName, octave);
}
