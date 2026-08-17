import 'dart:math';

import '../../core/chord.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// AKOR SORU ÜRETİMİ — saf, testli
//
// TRACK'İN TEK KAZANIMI: **duyduğun akoru çalabilmek.**
//
// ⚠️ CİHAZ TESTİNİN DERSİ (2026-08-17): ilk yeniden kurulumda cevap sesin
// içindeydi ama AMAÇ görevde değildi. Kullanıcı: *"seçenekleri doğru bulur ama
// neden bulduğunu bilmiyor, bulunca ne kazanacağını nerede kullanacağını
// anlayamıyor."* Teşhis: "üçlüyü bul", "tepe sesini bul" birer ANALİZ
// alt-becerisiydi — Melodi/Armoni/Ritim'de görev kendi anlamını taşırken
// ("duyduğunu geri kur") burada taşımıyordu.
//
// Ayrıca üç somut kusur bildirildi ve üçü de burada kapandı:
//   • "Tepe Sesi" dersi KALDIRILDI — çevrimde tepe kökten bir oktav yukarı
//     çıkabiliyordu ve tuş sırası (kök..kök+11) o sesi hiç içermiyordu; doğru
//     cevap ekranda görünmüyordu. Gerçek bir hata, dersin de amacı zayıftı.
//   • "Rengi Bul" (üçlüyü tek başına bul) KALDIRILDI — üçlü artık akoru
//     KURARKEN öğreniliyor, tek başına aranan bir bilmece olarak değil.
//   • "Akoru Kur"da tarif öğretilmiyordu → artık akor TARİFİ (kökten kaç tuş)
//     ders içeriğinin parçası; önce rehberli kurulur, sonra rehber kalkar.
//
// Kalan her ders ya "duyduğun akoru kur" ya da onu mümkün kılan tek adımlık
// bir ayrım. Sorular TERİM sormaz; terim en sonda rozet olur.
// -----------------------------------------------------------------------------

/// Akor derslerinin soru tipleri.
enum ChordDrill {
  /// Eşleştir — Eko bir akor çalar, iki DİNLENEBİLİR şıktan aynısını seç.
  /// Görev kendini anlatır: "aynı sesi bul". Hiçbir terim gerekmez.
  match,

  /// Parlak mı hüzünlü mü — tek akor, karşılaştırma koltuk değneği yok.
  color,

  /// Üç mü dört mü — akorun üstüne bir ses daha binmiş mi (yedililer).
  countTones,

  /// Akoru kur — kullanıcı akoru ses ses ÜRETİR. Track'in kalbi.
  build,
}

/// Ders havuzlarındaki kökler.
const List<String> kChordRoots = ['C', 'D', 'E', 'F', 'G', 'A'];

/// Üçlü akorların rengi → dil-bağımsız anahtar. Sözcükler TERİM değil HİS.
String colorKeyOf(ChordQuality quality) => switch (quality) {
  ChordQuality.major || ChordQuality.major7 || ChordQuality.dominant7 =>
    'bright',
  ChordQuality.minor || ChordQuality.minor7 => 'dark',
  ChordQuality.diminished ||
  ChordQuality.diminished7 ||
  ChordQuality.halfDiminished7 => 'tense',
  ChordQuality.augmented => 'floating',
};

/// Akorun TARİFİ: kökten sonra kaç tuş, sonra kaç tuş daha.
///
/// Kullanıcıya "majör akor 1-3-5'tir" demek bir tanımdır, tarif değil.
/// Kromatik tuş sırasında "kökten 4 tuş, sonra 3 tuş" SAYILABİLİR bir
/// talimattır — 6 yaşındaki de uygular. Track bunu ekranda gösterir.
List<int> chordRecipe(ChordQuality quality) {
  final intervals = quality.intervals;
  return [
    for (var i = 1; i < intervals.length; i++) intervals[i] - intervals[i - 1],
  ];
}

/// Tek bir akoru çalınabilir cümleye çevirir.
///
/// Armoni'deki `bandVoicing`in aksine bas İKİLENMEZ: orada mesele bası
/// duyurmaktı, burada mesele yığının RENGİ.
MusicalPhrase chordSoundPhrase(Chord chord, {int beats = 3}) => MusicalPhrase(
  events: [PhraseEvent(chord.notes, beats: beats)],
  tonic: chord.root,
);

/// Algı sorusu.
class ChordChoiceRound {
  /// Eko'nun çaldığı ses.
  final MusicalPhrase phrase;

  /// Seçeneklerin dil-bağımsız anahtarları.
  final List<String> optionKeys;

  /// Doğru cevabın indisi.
  final int answer;

  /// Şıklar DİNLENEBİLİRSE (eşleştirme dersi) her şıkkın akoru.
  /// null ise şıklar yalnızca metindir.
  final List<Chord>? optionChords;

  const ChordChoiceRound({
    required this.phrase,
    required this.optionKeys,
    required this.answer,
    this.optionChords,
  });
}

/// Akor kurma sorusu.
class ChordProduceRound {
  /// Kurulacak akor.
  final Chord chord;

  /// Eko'nun çaldığı: hedef akorun kendisi (kulakla çözülecek) ya da yalnızca
  /// kök (renk kullanıcıya söylenir).
  final MusicalPhrase phrase;

  /// Sırayla üretilecek sesler.
  final List<Note> targets;

  /// Kullanıcı akorun rengini KULAĞIYLA mı bulacak? false ise ekranda yazar.
  final bool colorIsHeard;

  const ChordProduceRound({
    required this.chord,
    required this.phrase,
    required this.targets,
    required this.colorIsHeard,
  });
}

Chord _randomChord(
  Random rng, {
  required List<ChordQuality> qualities,
}) => Chord(
  Note.fromName(kChordRoots[rng.nextInt(kChordRoots.length)], 4),
  qualities[rng.nextInt(qualities.length)],
);

/// Algı sorusu üretir.
ChordChoiceRound generateChordChoice({
  required ChordDrill drill,
  required List<ChordQuality> qualities,
  required Random rng,
}) {
  switch (drill) {
    // Eşleştir: Eko bir akor çalar, iki dinlenebilir şıktan aynısı seçilir.
    // Şıklar AYNI KÖKTE majör/minör → fark tek nota, ama görev "aynısını bul"
    // olduğu için kullanıcı ne yaptığını ilk saniyeden biliyor.
    case ChordDrill.match:
      final root = Note.fromName(
        kChordRoots[rng.nextInt(kChordRoots.length)],
        4,
      );
      final major = Chord(root, ChordQuality.major);
      final minor = Chord(root, ChordQuality.minor);
      final majorFirst = rng.nextBool();
      final options = majorFirst ? [major, minor] : [minor, major];
      final targetIsMajor = rng.nextBool();
      final target = targetIsMajor ? major : minor;
      return ChordChoiceRound(
        phrase: chordSoundPhrase(target),
        optionKeys: const ['soundA', 'soundB'],
        answer: options.indexOf(target),
        optionChords: options,
      );

    case ChordDrill.color:
      final chord = _randomChord(rng, qualities: qualities);
      const options = ['bright', 'dark'];
      return ChordChoiceRound(
        phrase: chordSoundPhrase(chord),
        optionKeys: options,
        answer: options.indexOf(colorKeyOf(chord.quality)),
      );

    case ChordDrill.countTones:
      final chord = _randomChord(rng, qualities: qualities);
      const options = ['three', 'four'];
      return ChordChoiceRound(
        phrase: chordSoundPhrase(chord),
        optionKeys: options,
        answer: chord.quality.isSeventh ? 1 : 0,
      );

    case ChordDrill.build:
      throw ArgumentError('$drill is a production drill');
  }
}

/// Akor kurma sorusu üretir.
///
/// [colorIsHeard] false → yalnızca KÖK çalar, renk ekranda yazar (rehberli
/// öğrenme). true → akorun tamamı çalar, rengi kullanıcı kulağıyla bulur ve
/// aynısını kurar. Track'in kazanımı budur: duy → çal.
ChordProduceRound generateChordProduce({
  required List<ChordQuality> qualities,
  required bool colorIsHeard,
  required Random rng,
}) {
  final chord = _randomChord(rng, qualities: qualities);
  return ChordProduceRound(
    chord: chord,
    phrase: colorIsHeard
        ? chordSoundPhrase(chord)
        : MusicalPhrase(
            events: [
              PhraseEvent([chord.root], beats: 3),
            ],
            tonic: chord.root,
          ),
    targets: chord.notes,
    colorIsHeard: colorIsHeard,
  );
}

/// Kurma ekranındaki tuş sırası: kökten başlayan kromatik bir oktav + oktav
/// sesi (13 tuş).
///
/// Kromatik olması şart: minör üçlü çoğu tonda dizinin dışında kalır. Oktavın
/// dahil olması da şart — dört sesli akorlarda üst ses kök+10/11'e kadar
/// çıkabilir ve aranan ses tuşta YOKSA soru çözülemez hâle gelir (cihazda
/// bildirilen "cevap şıklarda yok" hatası tam olarak buydu).
List<Note> chromaticPadsFrom(Note root) => [
  for (var semitone = 0; semitone <= 12; semitone++) Note(root.midi + semitone),
];
