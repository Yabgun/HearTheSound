import 'note.dart';

// -----------------------------------------------------------------------------
// MAJÖR TONALİTELER — işlev ve ilerleme içeriğinin taşınabilir armoni bağlamı
//
// İlk turda diyezli ve notasyon açısından açık üç merkez kullanılır. Model yeni
// tonaliteler eklemeye açıktır; derslerin dereceleri ve akorları C majörden bu
// merkeze blok halinde taşınır. Böylece Roman rakamı/işlev aynı kalır.
// -----------------------------------------------------------------------------

enum MajorKey {
  c('C', 'C Majör', 0),
  g('G', 'G Majör', 7),
  d('D', 'D Majör', 2);

  const MajorKey(this.tonicName, this.label, this.semitonesFromC);

  final String tonicName;
  final String label;

  /// Kanonik C majöre göre tonalite farkı. Yalnızca perde sınıfını taşır;
  /// kullanıcının ses aralığına göre oktav eşlemesi derste ayrıca yapılır.
  final int semitonesFromC;

  Note tonicAtOctave(int octave) => Note.fromName(tonicName, octave);
}
