import '../../core/chord.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// ARMONİ ÇEKİRDEĞİ — bir tonalitedeki akorlar ve yaygın kalıplar (saf, testli)
//
// KUZEY YILDIZI: "bir müzik duyunca akorlarını çıkarıp o şarkıyı çalabilmek."
// Bunun için gereken en pratik beceri BAS SESİ duymaktır: bas neredeyse her
// zaman akorun kökünü söyler, yani ilerlemenin iskeletini verir. Bu yüzden
// buradaki her şey basın nereye gittiğini ölçülebilir kılacak şekilde kuruldu.
//
// Bu dosya ETİKET üretmez (I, IV, V gibi Roma rakamları yok). Kaldırılan teori
// track'lerinin hatası tam olarak buydu: akorun ADINI sordurmak. Burada üretilen
// şey SES; kullanıcıdan istenen şey de o sesi bulmak/tekrarlamak.
// -----------------------------------------------------------------------------

/// Majör tonalitede bir derecenin akor niteliği.
/// 1-4-5 majör · 2-3-6 minör · 7 eksik. (Müziğin doğal düzeni; ezberletilmez,
/// kullanıcı bunu duyarak yaşar.)
ChordQuality majorKeyChordQuality(int degree) => switch (degree) {
  1 || 4 || 5 => ChordQuality.major,
  2 || 3 || 6 => ChordQuality.minor,
  7 => ChordQuality.diminished,
  _ => throw ArgumentError('Degree must be 1..7, got $degree'),
};

/// Bir tonalitede derecenin akoru.
Chord chordForDegree({
  required Note tonic,
  required int degree,
  int inversion = 0,
}) => Chord(
  Note(tonic.midi + majorDegreeSemitones(degree)),
  majorKeyChordQuality(degree),
  inversion: inversion,
);

/// Yaygın bir akor kalıbı — gerçek şarkıların iskeleti.
///
/// [id] dil-bağımsızdır (ilerleme kaydı ve karıştırma anahtarları için);
/// kullanıcıya gösterilen ad ders katmanında çevrilir.
class ProgressionPattern {
  final String id;

  /// Derece dizisi (1..7).
  final List<int> degrees;

  const ProgressionPattern(this.id, this.degrees);

  int get length => degrees.length;
}

/// Popüler müziğin iskeletini kuran kalıplar. "Dört akorla yüzlerce şarkı"
/// sözünün arkasındaki kalıplar bunlar.
const List<ProgressionPattern> kCommonProgressions = [
  ProgressionPattern('I-IV-V-I', [1, 4, 5, 1]),
  ProgressionPattern('I-V-vi-IV', [1, 5, 6, 4]),
  ProgressionPattern('I-vi-IV-V', [1, 6, 4, 5]),
  ProgressionPattern('vi-IV-I-V', [6, 4, 1, 5]),
  ProgressionPattern('I-IV-I-V', [1, 4, 1, 5]),
  ProgressionPattern('ii-V-I', [2, 5, 1]),
];

/// Derece dizisinden akor cümlesi üretir (her akor bir olay).
MusicalPhrase progressionPhrase({
  required Note tonic,
  required List<int> degrees,
  int beatsPerChord = 2,
}) => chordPhrase(
  tonic: tonic,
  chords: [
    for (final degree in degrees)
      chordForDegree(tonic: tonic, degree: degree).notes,
  ],
  beatsPerEvent: beatsPerChord,
);

/// İki akor arasında BASIN yönü: -1 indi · 0 aynı kaldı · +1 çıktı.
///
/// Kullanıcıdan istenen ilk armoni becerisi bu: akorun adını değil, basın
/// nereye gittiğini duymak.
int bassDirection(Chord from, Chord to) {
  final a = from.notes.map((n) => n.midi).reduce((x, y) => x < y ? x : y);
  final b = to.notes.map((n) => n.midi).reduce((x, y) => x < y ? x : y);
  return b.compareTo(a);
}

/// Cümledeki her akorun bas notası — "bası bul" alıştırmasının hedefi.
List<Note> bassLineOf(MusicalPhrase phrase) => [
  for (final event in phrase.events) event.lowest,
];
