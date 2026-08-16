import 'dart:math';

import '../../core/chord.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';
import 'harmony_chords.dart';

// -----------------------------------------------------------------------------
// ARMONİ SORU ÜRETİMİ — Armoni Kulağı derslerinin malzemesi (saf, testli)
//
// TEK KURAL (cihaz testinde pahalıya öğrenildi):
//   CEVAP, AZ ÖNCE ÇALAN SESİN İÇİNDE OLMALI — ve kullanıcının işi onu GERİ
//   KURMAK olmalı.
//
// İlk sürümde üç ders bu kuralı çiğniyordu ve kullanıcı hepsini "ne yaptığımı
// anlamıyorum" diye reddetti:
//   • "Ev Neresi?"     → "ev" duyulan bir şey değil, çıkarsanan bir YORUM.
//   • "Dinlendi mi?"   → aynı yorum problemi; üstelik bu, daha önce denenip
//                        başarısız olmuş "Bitti mi?" mekaniğinin ta kendisiydi.
//   • "Sıradaki Akor"  → hiç çalmamış bir sesi soruyordu; kullanıcının doğru
//                        olduğunu anlamasının bir yolu yoktu (tahmin ≠ kulak).
// Aynı kullanıcı "Kalıbı Çöz"ü çok sevdi: orada cevap duyduğu şeyin kendisidir.
// Bu yüzden track artık TEK bir yay: duy → geri kur, adım adım büyüyerek.
//
// Sesler her soruda yeniden üretilir → ezberlenemez, gerçekten dinlenir.
// (test/harmony_round_test.dart hem seslerin hem CEVAPLARIN çeşitliliğini
// kilitler; dengesiz cevap dağılımı dinlemeden geçmeye izin verirdi.)
// -----------------------------------------------------------------------------

/// Armoni derslerinin soru tipleri. Hepsinin ortak sözleşmesi: doğru cevap
/// çalınan cümlenin İÇİNDEDİR.
enum HarmonyDrill {
  /// 1 · Kaç Ses? — tek ses mi, aynı anda iki ses mi? (harmonik aralıkların evi)
  howMany,

  /// 2 · Değişti mi? — ikinci akor birincinin aynısı mı, başkası mı?
  changed,

  /// 3 · Bas Nereye Gitti? — akor değişince en pes ses çıktı mı, indi mi?
  bassDirection,

  /// 4 · Bası Bul — duyulan akorun bas sesini kullanıcı ÜRETİR.
  findBass,

  /// 5 · Bas Hattını Çıkar — bir dizinin BÜTÜN bas seslerini sırayla üretir.
  bassLine,

  /// 6-8 · Kalıbı Çöz — duyulan akorları sırayla dizer (transkripsiyon).
  /// Uzunluk ve "tuzak" akor sayısı ders tarafından belirlenir.
  pattern,
}

/// Bir soruda kullanıcının seçebileceği iki cevabın DİL-BAĞIMSIZ anahtarları.
///
/// Görünen metin ders katmanında çevrilir; buradaki anahtarlar karıştırma
/// sayaçlarına ('harmony:up>down') yazıldığı için dil değişse de bozulmamalı.
/// İndis sırası UI'daki seçenek sırasıyla birebir aynıdır.
List<String> choiceKeysOf(HarmonyDrill drill) => switch (drill) {
  HarmonyDrill.howMany => const ['one', 'two'],
  HarmonyDrill.changed => const ['same', 'changed'],
  HarmonyDrill.bassDirection => const ['up', 'down'],
  _ => const [],
};

/// Ev değişen derslerde kullanılacak merkezler (C4'ten yarım ses uzaklık).
const List<int> kHarmonyKeyShifts = [0, 2, 4, 5, 7, -2, -4];

/// Bir sorunun "evi". [varyKey] açıkken her soruda değişir → beceri tek bir
/// tona yapışmaz, kullanıcı ilişkiyi öğrenir.
Note harmonyTonic({required bool varyKey, required Random rng}) => Note(
  Note.fromName('C', 4).midi +
      (varyKey ? kHarmonyKeyShifts[rng.nextInt(kHarmonyKeyShifts.length)] : 0),
);

/// Nota bulma ekranlarındaki tuş sırası: havuzdaki derecelerin sesleri,
/// pesten tize.
List<Note> padNotesFor({required Note tonic, required List<int> degrees}) => [
  for (final degree in (degrees.toSet().toList()..sort()))
    Note(tonic.midi + majorDegreeSemitones(degree)),
];

/// Akorun "grup" seslendirmesi: akorun kendi notaları + BASI bir oktav altta.
///
/// NEDEN: Armoni Kulağı'nın omurgası bas duymak. Kapalı pozisyondaki üçlüde bas
/// diğer seslerin arasında kaybolur; bir oktav aşağıda ikilenince gerçek bir
/// grup kaydındaki gibi ayrışır ve DUYULABİLİR hale gelir. Bu "ipucu sesi"
/// değildir (egzersizin önüne eklenen ekstra ses yasak) — akorun kendi
/// düzenlemesidir; ne çalıyorsak onu buldururuz.
List<Note> bandVoicing(Chord chord) {
  final notes = chord.notes;
  return [Note(notes.first.midi - 12), ...notes];
}

/// Akor dizisini grup seslendirmesiyle çalınabilir cümleye çevirir.
MusicalPhrase bandPhrase({
  required Note tonic,
  required List<Chord> chords,
  int beatsPerChord = 2,
}) => chordPhrase(
  tonic: tonic,
  chords: [for (final chord in chords) bandVoicing(chord)],
  beatsPerEvent: beatsPerChord,
);

/// Akorun kısa yazımı ("C", "Am", "B°").
///
/// ÇEVRİLMEZ ve çevrilmemeli: akor sembolleri müziğin uluslararası yazımıdır,
/// dünyanın her yerindeki nota/tab sitesinde kullanıcıyı bu yazım karşılar.
/// Burada bir TERİM ezberletilmiyor — taşa basınca akor çalıyor, kullanıcı onu
/// kulağıyla eşleştiriyor; sembol yalnızca taşın etiketi.
String shortChordName(Chord chord) => switch (chord.quality) {
  ChordQuality.minor => '${chord.root.name}m',
  ChordQuality.diminished => '${chord.root.name}°',
  _ => chord.root.name,
};

// --- 1 / 2 / 3 · İki seçenekli sorular ----------------------------------------

/// Aynı anda duyulacak iki sesin arasındaki mesafe adayları (yarım ses).
///
/// Oktav (12) bilinçli olarak YOK: iki oktav sesi kulağa neredeyse tek ses gibi
/// gelir ve "kaç ses" sorusunu ilk derste haksız biçimde zorlaştırırdı.
const List<int> _harmonicGaps = [2, 3, 4, 5, 7, 9];

/// İki seçenekli bir soru: çalınacak cümle + doğru seçeneğin indisi.
class ChoiceRound {
  final MusicalPhrase phrase;

  /// [choiceKeysOf] listesindeki doğru cevabın indisi.
  final int answer;

  const ChoiceRound({required this.phrase, required this.answer});
}

/// [drill] tipine uygun iki seçenekli bir soru üretir.
ChoiceRound generateChoiceRound({
  required HarmonyDrill drill,
  required Note tonic,
  required List<int> degrees,
  required Random rng,
}) {
  final pool = degrees.toSet().toList()..sort();
  if (pool.isEmpty) {
    throw ArgumentError('HarmonyLesson.degrees must not be empty');
  }

  switch (drill) {
    // Tek ses mi iki ses mi: yığının KALINLIĞI sorulur, adı değil.
    case HarmonyDrill.howMany:
      final two = rng.nextBool();
      final root = Note(
        tonic.midi + majorDegreeSemitones(pool[rng.nextInt(pool.length)]),
      );
      final notes = two
          ? [
              root,
              Note(root.midi + _harmonicGaps[rng.nextInt(_harmonicGaps.length)]),
            ]
          : [root];
      return ChoiceRound(
        phrase: MusicalPhrase(
          events: [PhraseEvent(notes, beats: 3)],
          tonic: tonic,
        ),
        answer: two ? 1 : 0,
      );

    // Akor değişti mi: gitarda elini değiştirmen gereken an.
    case HarmonyDrill.changed:
      final same = rng.nextBool();
      final first = pool[rng.nextInt(pool.length)];
      // Aynı derece iki kez çalınırsa cevap "aynı kaldı"; farklıysa "değişti".
      final second = same ? first : _otherDegree(pool, first, rng);
      return ChoiceRound(
        phrase: bandPhrase(
          tonic: tonic,
          chords: [
            chordForDegree(tonic: tonic, degree: first),
            chordForDegree(tonic: tonic, degree: second),
          ],
        ),
        answer: same ? 0 : 1,
      );

    // Bas yukarı mı aşağı mı: akor çıkarmanın en pratik becerisi.
    case HarmonyDrill.bassDirection:
      if (pool.length < 2) {
        throw ArgumentError('bassDirection needs at least 2 degrees');
      }
      final first = pool[rng.nextInt(pool.length)];
      final second = _otherDegree(pool, first, rng);
      final from = chordForDegree(tonic: tonic, degree: first);
      final to = chordForDegree(tonic: tonic, degree: second);
      return ChoiceRound(
        phrase: bandPhrase(tonic: tonic, chords: [from, to]),
        // Cevap ÖLÇÜLEREK bulunur (varsayımla değil): çevrim/oktav değişse de
        // doğru kalır.
        answer: bassDirection(from, to) > 0 ? 0 : 1,
      );

    case HarmonyDrill.findBass:
    case HarmonyDrill.bassLine:
    case HarmonyDrill.pattern:
      throw ArgumentError('$drill is not a two-choice drill');
  }
}

/// Havuzdan [degree] dışında rastgele bir derece.
int _otherDegree(List<int> pool, int degree, Random rng) {
  final others = [
    for (final d in pool)
      if (d != degree) d,
  ];
  if (others.isEmpty) {
    throw ArgumentError('Pool must contain a degree other than $degree');
  }
  return others[rng.nextInt(others.length)];
}

// --- 4 / 5 · Bas bulma ve bas hattı çıkarma -----------------------------------

/// Bas hattı çıkarma dersinin dizileri — hepsi gerçek şarkı hareketleri.
const List<List<int>> _bassLines = [
  [1, 4, 5],
  [1, 5, 6],
  [6, 4, 1],
  [4, 5, 1],
  [2, 5, 1],
  [1, 6, 4],
];

/// Kullanıcının NOTA(LAR) ürettiği soru: çalınacak cümle + hedef sesler.
class FindRound {
  final MusicalPhrase phrase;

  /// Kullanıcının sırayla bulacağı sesler (tek notalı derslerde bir eleman).
  ///
  /// Karşılaştırma perde SINIFI üzerinden yapılır: söylerken herkes kendi
  /// oktavında söyler, tuş oktavı da hedefle aynı olmak zorunda değil.
  final List<Note> targets;

  const FindRound({required this.phrase, required this.targets});
}

/// [drill] tipine uygun bir "sesi bul" sorusu üretir.
FindRound generateFindRound({
  required HarmonyDrill drill,
  required Note tonic,
  required List<int> degrees,
  required Random rng,
}) {
  final pool = degrees.toSet().toList()..sort();
  if (pool.isEmpty) {
    throw ArgumentError('HarmonyLesson.degrees must not be empty');
  }

  switch (drill) {
    // Tek akor duyulur, basi bulunur.
    case HarmonyDrill.findBass:
      final degree = pool[rng.nextInt(pool.length)];
      final chord = chordForDegree(tonic: tonic, degree: degree);
      return FindRound(
        phrase: bandPhrase(tonic: tonic, chords: [chord], beatsPerChord: 3),
        targets: [Note(tonic.midi + majorDegreeSemitones(degree))],
      );

    // Dizi duyulur, BÜTÜN bas hattı sırayla çıkarılır — bir müzisyenin bir
    // şarkıyı sökerken yaptığı ilk iş.
    case HarmonyDrill.bassLine:
      final line = _bassLines[rng.nextInt(_bassLines.length)];
      return FindRound(
        phrase: bandPhrase(
          tonic: tonic,
          chords: [
            for (final degree in line)
              chordForDegree(tonic: tonic, degree: degree),
          ],
        ),
        targets: [
          for (final degree in line)
            Note(tonic.midi + majorDegreeSemitones(degree)),
        ],
      );

    case HarmonyDrill.howMany:
    case HarmonyDrill.changed:
    case HarmonyDrill.bassDirection:
    case HarmonyDrill.pattern:
      throw ArgumentError('$drill is not a note-finding drill');
  }
}

// --- 6 / 7 / 8 · Kalıbı çöz ---------------------------------------------------

/// İki akorluk hareketler — kalıp çözmenin en küçük gerçek basamağı.
const List<List<int>> _twoChordMoves = [
  [1, 4],
  [1, 5],
  [1, 6],
  [4, 5],
  [5, 1],
  [6, 4],
  [2, 5],
  [4, 1],
];

/// "Tuzak" akorların çekildiği havuz — hepsi tonun İÇİNDEN.
///
/// Ton dışı akor seçmek soruyu kolaylaştırırdı (yanlış olan hemen sırıtır);
/// gerçek bir şarkıyı çıkarırken de kafa karıştıran şey ton dışı sesler değil,
/// aynı aileden gelen ama çalmamış akorlardır.
const List<int> _decoyDegrees = [1, 2, 3, 4, 5, 6];

/// Kalıp sorusu: duyulan sıra + kullanıcının seçebileceği akorlar.
class PatternRound {
  /// Çalınan kalıp.
  final MusicalPhrase phrase;

  /// Doğru sıra.
  final List<Chord> sequence;

  /// Kullanıcının seçebileceği BENZERSİZ akorlar (karışık sırada).
  /// I-IV-I-V gibi bir kalıpta aynı akor iki yuvaya girer → paletteki taşlar
  /// tekrar tekrar kullanılabilir. Zor derslerde palette hiç çalmamış "tuzak"
  /// akorlar da bulunur.
  final List<Chord> palette;

  const PatternRound({
    required this.phrase,
    required this.sequence,
    required this.palette,
  });
}

/// Bir kalıp sorusu kurar.
///
/// [length] 2 → iki akorluk hareket · 4 → yaygın dört akorluk kalıplar.
/// [decoyCount] palete eklenecek, kalıpta HİÇ ÇALMAYAN akor sayısı.
PatternRound generatePatternRound({
  required Note tonic,
  required Random rng,
  int length = 4,
  int decoyCount = 0,
}) {
  final degreeLines = switch (length) {
    2 => _twoChordMoves,
    4 => [
      for (final p in kCommonProgressions)
        if (p.length == 4) p.degrees,
    ],
    _ => throw ArgumentError('Unsupported pattern length: $length'),
  };
  final line = degreeLines[rng.nextInt(degreeLines.length)];
  final sequence = [
    for (final degree in line) chordForDegree(tonic: tonic, degree: degree),
  ];

  // Palet: önce kalıpta geçen benzersiz akorlar.
  final palette = <Chord>[];
  for (final chord in sequence) {
    if (!palette.contains(chord)) palette.add(chord);
  }

  // Sonra tuzaklar: aynı tondan, ama bu kalıpta çalmayan akorlar.
  if (decoyCount > 0) {
    final candidates = [
      for (final degree in _decoyDegrees)
        chordForDegree(tonic: tonic, degree: degree),
    ]..removeWhere(palette.contains);
    candidates.shuffle(rng);
    palette.addAll(candidates.take(decoyCount));
  }

  // Sıra karışmazsa ilk taşlar her zaman doğru cevap olurdu (ve tuzaklar hep
  // sonda dururdu) → kalıp dinlenmeden çözülürdü.
  palette.shuffle(rng);

  return PatternRound(
    phrase: bandPhrase(tonic: tonic, chords: sequence),
    sequence: sequence,
    palette: palette,
  );
}
