import 'dart:math';

import '../../core/chord.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';

// -----------------------------------------------------------------------------
// AKOR SORU ÜRETİMİ — saf, testli
//
// Track'in yeni işi TEK bir şey: AKORUN RENGİ ve o rengi ÜRETEBİLMEK.
// Kök bulma ve akorların birbirine göre hareketi Armoni Kulağı'nın işi; burada
// tekrar edilmez. İş bölümü: **Akorlar = dikey renk · Armoni = yatay hareket.**
//
// Eski track 13 dersti ve yarısı ya çakışıyordu ya da yanlış soruyu soruyordu:
//   • "Bu hangi akor?" → kök bulma + renk duyma TEK soruda; kullanıcı hangisinde
//     takıldığını bilemiyordu, üstelik kök bulma zaten Armoni'de var.
//   • "Bu kaçıncı çevrim?" → bir ANALİZ sorusu. İçindeki gerçek beceri "en
//     üstte/altta hangi ses var" — o yüzden burada [findTop] olarak, cevabı
//     ÜRETTİREREK yaşatılıyor.
//   • Arpej söyleme → akoru melodiye çeviriyordu (bkz. chord_produce_page).
//
// SORULAR TERİM SORMAZ: "majör mü?" değil "parlak mı?". Terim en sonda rozet.
// -----------------------------------------------------------------------------

/// Akor derslerinin soru tipleri.
enum ChordDrill {
  /// 1 · Hangisi Parlak? — aynı kökte iki akor; fark TEK nota.
  brighter,

  /// 2 · Parlak mı Hüzünlü mü? — tek akor, karşılaştırma koltuk değneği yok.
  color,

  /// 3 · Rengi Bul — akoru renklendiren sesi (üçlüyü) ÜRET.
  findThird,

  /// 4 · Tepe Sesi — akorun en tiz sesini bul (çevrimler burada yaşanır).
  findTop,

  /// 5 · Akoru Kur — verilen kökte istenen rengi kendin üret.
  buildChord,

  /// 6 · Gergin Renkler — eksik ve artık akorlar devrede.
  tense,

  /// 7 · Üç mü Dört mü? — üstüne bir ses daha binmiş mi (yedililer).
  countTones,

  /// 8 · Renk Ustası — öğrenilen algı sorularının karışımı.
  master,
}

/// Ders havuzlarındaki kökler. Aynı ilişkiyi farklı evlerde yaşatmak beceriyi
/// tek bir akordan koparır.
const List<String> kChordRoots = ['C', 'D', 'E', 'F', 'G', 'A'];

/// Üçlü akorların rengi → dil-bağımsız seçenek anahtarı.
///
/// Sözcükler TERİM değil HİS: kullanıcı "majör" kelimesini bilmeden de
/// "parlak"ı duyar. Adı rozet olarak sonra konur.
String colorKeyOf(ChordQuality quality) => switch (quality) {
  ChordQuality.major || ChordQuality.major7 || ChordQuality.dominant7 =>
    'bright',
  ChordQuality.minor || ChordQuality.minor7 => 'dark',
  ChordQuality.diminished ||
  ChordQuality.diminished7 ||
  ChordQuality.halfDiminished7 => 'tense',
  ChordQuality.augmented => 'floating',
};

/// Tek bir akoru çalınabilir cümleye çevirir.
///
/// Armoni'deki `bandVoicing`in aksine bas İKİLENMEZ: orada mesele bası
/// duyurmaktı, burada mesele yığının RENGİ. Fazladan bir oktav bası, üçlünün
/// taşıdığı rengi bulanıklaştırır.
MusicalPhrase chordSoundPhrase(Chord chord, {int beats = 3}) => MusicalPhrase(
  events: [PhraseEvent(chord.notes, beats: beats)],
  tonic: chord.root,
);

/// İki seçenekli/çok seçenekli algı sorusu.
class ChordChoiceRound {
  final MusicalPhrase phrase;

  /// Seçeneklerin dil-bağımsız anahtarları (UI bunları çevirir).
  final List<String> optionKeys;

  /// [optionKeys] içindeki doğru cevabın indisi.
  final int answer;

  const ChordChoiceRound({
    required this.phrase,
    required this.optionKeys,
    required this.answer,
  });
}

/// Kullanıcının SES ÜRETTİĞİ soru.
class ChordProduceRound {
  /// Duyulan (ya da kurulacak) akor.
  final Chord chord;

  /// Çalınacak ses. [ChordDrill.buildChord] için yalnızca KÖK çalar — akorun
  /// tamamı çalsaydı kullanıcı kurmaz, taklit ederdi.
  final MusicalPhrase phrase;

  /// Kullanıcının sırayla üreteceği sesler.
  final List<Note> targets;

  /// Kurulacak renk (yalnızca [ChordDrill.buildChord]); kullanıcıya söylenir.
  final ChordQuality? buildQuality;

  const ChordProduceRound({
    required this.chord,
    required this.phrase,
    required this.targets,
    this.buildQuality,
  });
}

Note _root(String name, Random rng) => Note.fromName(name, 4);

Chord _randomChord(
  Random rng, {
  required List<ChordQuality> qualities,
  int inversion = 0,
}) => Chord(
  _root(kChordRoots[rng.nextInt(kChordRoots.length)], rng),
  qualities[rng.nextInt(qualities.length)],
  inversion: inversion,
);

/// Algı sorusu üretir.
ChordChoiceRound generateChordChoice({
  required ChordDrill drill,
  required Random rng,
}) {
  switch (drill) {
    // Aynı KÖKTE majör ve minör peş peşe: fark tek nota (üçlü), o yüzden
    // duyulması en kolay renk zıtlığı. Track buradan başlar.
    case ChordDrill.brighter:
      final root = _root(kChordRoots[rng.nextInt(kChordRoots.length)], rng);
      final majorFirst = rng.nextBool();
      final first = Chord(root, majorFirst
          ? ChordQuality.major
          : ChordQuality.minor);
      final second = Chord(root, majorFirst
          ? ChordQuality.minor
          : ChordQuality.major);
      return ChordChoiceRound(
        phrase: MusicalPhrase(
          events: [
            PhraseEvent(first.notes, beats: 3),
            PhraseEvent(second.notes, beats: 3),
          ],
          tonic: root,
        ),
        optionKeys: const ['first', 'second'],
        answer: majorFirst ? 0 : 1,
      );

    case ChordDrill.color:
      final chord = _randomChord(
        rng,
        qualities: const [ChordQuality.major, ChordQuality.minor],
      );
      const options = ['bright', 'dark'];
      return ChordChoiceRound(
        phrase: chordSoundPhrase(chord),
        optionKeys: options,
        answer: options.indexOf(colorKeyOf(chord.quality)),
      );

    case ChordDrill.tense:
      final chord = _randomChord(
        rng,
        qualities: const [
          ChordQuality.major,
          ChordQuality.minor,
          ChordQuality.diminished,
          ChordQuality.augmented,
        ],
      );
      const options = ['bright', 'dark', 'tense', 'floating'];
      return ChordChoiceRound(
        phrase: chordSoundPhrase(chord),
        optionKeys: options,
        answer: options.indexOf(colorKeyOf(chord.quality)),
      );

    // Yedililer bir RENK değil bir KALINLIK sorusu olarak öğretilir: üstüne bir
    // ses daha binmiş mi? (Armoni'nin sevilen "Kaç Ses?" mekaniğinin akor hâli.)
    case ChordDrill.countTones:
      final chord = _randomChord(
        rng,
        qualities: const [
          ChordQuality.major,
          ChordQuality.minor,
          ChordQuality.dominant7,
          ChordQuality.major7,
          ChordQuality.minor7,
        ],
      );
      const options = ['three', 'four'];
      return ChordChoiceRound(
        phrase: chordSoundPhrase(chord),
        optionKeys: options,
        answer: chord.quality.isSeventh ? 1 : 0,
      );

    // Capstone: öğrenilen algı sorularını karıştırır. Dokuz şıklı dev bir
    // etiketleme ekranı YAPILMADI — o, kaldırdığımız hatanın ta kendisi olurdu.
    case ChordDrill.master:
      const mixed = [ChordDrill.color, ChordDrill.tense, ChordDrill.countTones];
      return generateChordChoice(
        drill: mixed[rng.nextInt(mixed.length)],
        rng: rng,
      );

    case ChordDrill.findThird:
    case ChordDrill.findTop:
    case ChordDrill.buildChord:
      throw ArgumentError('$drill is not a perception drill');
  }
}

/// Üretim sorusu üretir.
ChordProduceRound generateChordProduce({
  required ChordDrill drill,
  required Random rng,
}) {
  switch (drill) {
    // Majörle minörü ayıran TEK ses üçlüdür. Onu bulabilen kullanıcı, rengin
    // sebebini ezberlemez — elinde tutar.
    case ChordDrill.findThird:
      final chord = _randomChord(
        rng,
        qualities: const [ChordQuality.major, ChordQuality.minor],
      );
      return ChordProduceRound(
        chord: chord,
        phrase: chordSoundPhrase(chord),
        targets: [chord.notes[1]],
      );

    // Çevrimlerin dürüst hâli: "kaçıncı çevrim" diye sormak yerine en tiz sesi
    // buldururuz. Kapalı pozisyonda tepe her zaman beşli olurdu (tahmin
    // edilebilirdi); çevrim onu değiştirdiği için soru gerçek bir kulak sorusu.
    case ChordDrill.findTop:
      final chord = _randomChord(
        rng,
        qualities: const [ChordQuality.major, ChordQuality.minor],
        inversion: rng.nextInt(3),
      );
      return ChordProduceRound(
        chord: chord,
        phrase: chordSoundPhrase(chord),
        targets: [chord.notes.last],
      );

    // Akoru KUR: yalnızca kök çalar, rengi söylenir, üç sesi kullanıcı üretir.
    // Arpejin dürüst olduğu tek yer burası — amaç taklit değil İNŞA.
    case ChordDrill.buildChord:
      final chord = _randomChord(
        rng,
        qualities: const [ChordQuality.major, ChordQuality.minor],
      );
      return ChordProduceRound(
        chord: chord,
        phrase: MusicalPhrase(
          events: [PhraseEvent([chord.root], beats: 3)],
          tonic: chord.root,
        ),
        targets: chord.notes,
        buildQuality: chord.quality,
      );

    case ChordDrill.brighter:
    case ChordDrill.color:
    case ChordDrill.tense:
    case ChordDrill.countTones:
    case ChordDrill.master:
      throw ArgumentError('$drill is not a production drill');
  }
}

/// Üretim ekranındaki tuş sırası: kökten başlayan KROMATİK bir oktav.
///
/// Diyatonik bir havuz yetmez — minör üçlü (kök+3) çoğu tonda dizinin dışında
/// kalır. "Nokta atışı" istiyorsak aradaki sesler de tuşta olmalı.
List<Note> chromaticPadsFrom(Note root) => [
  for (var semitone = 0; semitone < 12; semitone++) Note(root.midi + semitone),
];
