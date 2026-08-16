import 'dart:math';

import '../../core/chord.dart';
import '../../core/musical_phrase.dart';
import '../../core/note.dart';
import '../harmony/harmony_chords.dart';
import '../harmony/harmony_round.dart';

// -----------------------------------------------------------------------------
// ŞARKI ÇÖZ — bulmaca üretimi (saf, testli)
//
// KUZEY YILDIZININ GERÇEKLEŞTİĞİ YER: "bir müzik duyunca akorlarını çıkarıp o
// şarkıyı çalabilmek." Armoni Kulağı'ndaki "Kalıbı Çöz" dersi bunun dört
// ölçülük provasıydı; burada aynı mekanik gerçek bir şarkı uzunluğuna çıkar.
//
// BİR ŞARKIYI "ŞARKI" YAPAN ŞEY TEKRARDIR — ve bulmacanın çekirdek fikri budur.
// Sekiz bağımsız akoru ezberlemek bir hafıza sınavı olurdu; oysa gerçek
// şarkılar kendini tekrar eder: ikinci yarı ya birincinin aynısıdır, ya
// yalnızca SON akoru değişir, ya da yeni bir yere gider. Kullanıcı bunu kendi
// kulağıyla fark ettiğinde iş yarıya iner — ve fark ettiği şey, gerçek
// transkripsiyonun en işe yarar numarasıdır. (Bu yüzden form bulmacada
// saklanır, sonuçta ADI konur: önce yaşat, sonra adını koy.)
//
// Bu dosya UI, ses motoru ve dil bilmez.
// -----------------------------------------------------------------------------

/// Bir şarkının iki yarısı arasındaki ilişki (dört ölçülük tek cümlede: [single]).
enum SongForm {
  /// Tek cümle — dört ölçü, tekrar yok.
  single,

  /// İkinci yarı birincinin AYNISI.
  repeat,

  /// İkinci yarı birincinin aynısı, yalnızca SON akoru farklı.
  /// Popüler müziğin en yaygın numarası.
  repeatVariedEnding,

  /// İki yarı farklı — ikinci bölüm yeni bir yere gider.
  contrast,
}

/// Şarkı bulmacasının zorluğu.
///
/// [id] kalıcıdır (ilerleme/istatistik anahtarı olarak kullanılabilir);
/// görünen ad UI katmanında çevrilir.
class SongDifficulty {
  final String id;

  /// Kaç dört-ölçülük cümle (1 → 4 ölçü, 2 → 8 ölçü).
  final int phrases;

  /// Palete eklenen, şarkıda HİÇ ÇALMAYAN akor sayısı.
  final int decoyCount;

  /// Şarkı her seferinde başka bir "ev"de mi çalınsın?
  final bool varyKey;

  const SongDifficulty({
    required this.id,
    required this.phrases,
    required this.decoyCount,
    required this.varyKey,
  });

  int get barCount => phrases * 4;
}

/// Üç zorluk — Kalıbı Çöz dersinden (4 ölçü, tuzaksız) gerçek şarkı boyuna.
const List<SongDifficulty> kSongDifficulties = [
  SongDifficulty(id: 'easy', phrases: 1, decoyCount: 1, varyKey: false),
  SongDifficulty(id: 'medium', phrases: 2, decoyCount: 1, varyKey: false),
  SongDifficulty(id: 'hard', phrases: 2, decoyCount: 2, varyKey: true),
];

/// Çözülecek şarkı: ölçü ölçü akorlar + kullanıcının seçebileceği palet.
class SongPuzzle {
  /// Her ölçüde bir akor (sabit süre — v1'in bilinçli sadeliği).
  final List<Chord> bars;

  /// Seçilebilir BENZERSİZ akorlar, karışık sırada. Tuzaklar da buradadır.
  final List<Chord> palette;

  /// İki yarı arasındaki ilişki — çözümden SONRA kullanıcıya anlatılır.
  final SongForm form;

  /// Şarkının tamamı (tek seferde çalmak için).
  final MusicalPhrase phrase;

  final Note tonic;

  const SongPuzzle({
    required this.bars,
    required this.palette,
    required this.form,
    required this.phrase,
    required this.tonic,
  });

  int get barCount => bars.length;

  /// Tek bir ölçünün sesi — kullanıcı takıldığı ölçüyü tek başına dinler.
  /// Gerçek transkripsiyonun en temel hareketi budur: zor yeri döngüye al.
  List<Note> barVoicing(int index) => bandVoicing(bars[index]);
}

/// Dört ölçülük cümle adayları — popüler müziğin iskeleti.
List<List<int>> _fourBarPhrases() => [
  for (final p in kCommonProgressions)
    if (p.length == 4) p.degrees,
];

/// İkinci yarının değiştirilmiş bitişi için aday dereceler.
/// Hepsi tonun içinden ve gerçekten kullanılan bitişler.
const List<int> _endingDegrees = [1, 4, 5, 6];

/// Tuzak akorların çekildiği havuz — hepsi tonun İÇİNDEN.
/// Ton dışı akor kulağa hemen yanlış gelir ve soruyu kolaylaştırırdı.
const List<int> _decoyDegrees = [1, 2, 3, 4, 5, 6];

/// Bir şarkı bulmacası üretir.
SongPuzzle generateSongPuzzle({
  required SongDifficulty difficulty,
  required Random rng,
}) {
  final tonic = harmonyTonic(varyKey: difficulty.varyKey, rng: rng);
  final phrases = _fourBarPhrases();
  final first = phrases[rng.nextInt(phrases.length)];

  final SongForm form;
  final List<int> degrees;
  if (difficulty.phrases == 1) {
    form = SongForm.single;
    degrees = [...first];
  } else {
    // Formlar eşit olasılıkla gelmez: TEKRAR eden biçimler daha sık, çünkü
    // öğretilmek istenen sezgi ("şarkılar kendini tekrar eder") ancak sık
    // yaşanırsa yerleşir. Kontrast biçimi sürprizi canlı tutar.
    final roll = rng.nextInt(10);
    if (roll < 4) {
      form = SongForm.repeat;
      degrees = [...first, ...first];
    } else if (roll < 8) {
      form = SongForm.repeatVariedEnding;
      final alternatives = [
        for (final d in _endingDegrees)
          if (d != first.last) d,
      ];
      final newEnding = alternatives[rng.nextInt(alternatives.length)];
      degrees = [...first, ...first.take(3), newEnding];
    } else {
      form = SongForm.contrast;
      final others = [
        for (final p in phrases)
          if (!_sameLine(p, first)) p,
      ];
      final second = others.isEmpty
          ? first
          : others[rng.nextInt(others.length)];
      degrees = [...first, ...second];
    }
  }

  final bars = [
    for (final degree in degrees) chordForDegree(tonic: tonic, degree: degree),
  ];

  // Palet: şarkıda geçen benzersiz akorlar + tuzaklar, karışık.
  final palette = <Chord>[];
  for (final chord in bars) {
    if (!palette.contains(chord)) palette.add(chord);
  }
  if (difficulty.decoyCount > 0) {
    final candidates = [
      for (final degree in _decoyDegrees)
        chordForDegree(tonic: tonic, degree: degree),
    ]..removeWhere(palette.contains);
    candidates.shuffle(rng);
    palette.addAll(candidates.take(difficulty.decoyCount));
  }
  // Sıra karışmazsa ilk taşlar hep doğru cevap, tuzaklar hep sonda olurdu →
  // şarkı dinlenmeden çözülürdü.
  palette.shuffle(rng);

  return SongPuzzle(
    bars: bars,
    palette: palette,
    form: form,
    phrase: bandPhrase(tonic: tonic, chords: bars),
    tonic: tonic,
  );
}

bool _sameLine(List<int> a, List<int> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

/// Çözümün ölçü ölçü doğruluğu. Boş bırakılan ölçü yanlış sayılır.
List<bool> checkSongSolution({
  required SongPuzzle puzzle,
  required List<Chord?> answer,
}) => [
  for (var i = 0; i < puzzle.bars.length; i++)
    i < answer.length && answer[i] == puzzle.bars[i],
];
