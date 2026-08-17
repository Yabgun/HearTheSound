import 'package:flutter/material.dart';

import '../../core/chord.dart';
import '../../core/content_locale.dart';
import '../lesson/theory_badge.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKORLAR — "duyduğun akoru çalabilmek"
//
// ⚠️ CİHAZ TESTİNİN DERSİ (2026-08-17): track'in ilk yeniden kurulumunda cevap
// sesin içindeydi ama AMAÇ görevde değildi. Kullanıcı: *"seçenekleri doğru
// bulur ama neden bulduğunu bilmiyor, bulunca ne kazanacağını nerede
// kullanacağını anlayamıyor."* Ayrıca üç somut şikâyet: "Rengi Bul çok zor ve
// karmaşık", "Tepe Sesi'nde doğru cevap şıklarda yok", "majör akorun nasıl
// kurulduğunu kullanıcı bilmiyor", "gergin/askıda ne demek bilmiyor".
//
// ÇÖZÜM — track TEK bir kazanım etrafında toplandı: DUY → ÇAL.
//   • Analiz alt-becerileri (üçlüyü bul, tepeyi bul) kaldırıldı; üçlü artık
//     akoru KURARKEN öğreniliyor.
//   • Akorun TARİFİ ders içeriği oldu: "kökten 4 tuş, sonra 3 tuş" — kromatik
//     tuş sırasında sayılabilir bir talimat. Önce rehberli kurulur (renk
//     ekranda yazar, sıradaki tuş işaretlenir), sonra rehber kalkar.
//   • "Gergin/askıda" artık kullanıcının KURDUĞU şeyin adı: önce 3+3 ve 4+4
//     tarifleriyle kurar, adını rozette alır.
//   • Her kurma sorusu, doğru kurulunca akoru ÇALAR — "işte, ben çaldım" anı.
//
// Sorular TERİM sormaz; terim en sonda rozet olur.
// -----------------------------------------------------------------------------

class ChordLesson {
  final String id;
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir.
  final String promise;

  final ChordDrill drill;

  /// Bu dersin akor havuzu (renkler).
  final List<ChordQuality> qualities;

  /// Kurma derslerinde: rengi kullanıcı KULAĞIYLA mı bulacak?
  /// false → yalnızca kök çalar, renk ekranda yazar (rehberli öğrenme).
  final bool colorIsHeard;

  /// Kurma derslerinde sıradaki doğru tuş işaretlensin mi? (ilk öğretim adımı)
  final bool guided;

  final int questionCount;

  final TheoryBadge? badge;

  const ChordLesson({
    required this.id,
    required this.title,
    required this.promise,
    required this.drill,
    required this.qualities,
    this.colorIsHeard = true,
    this.guided = false,
    this.questionCount = 6,
    this.badge,
  });

  bool get isProduction => drill == ChordDrill.build;
}

/// Seçenek anahtarı → GÖRÜNEN metin.
String chordOptionLabel(String key) => switch (key) {
  'soundA' => t(en: 'Sound 1', tr: '1. ses'),
  'soundB' => t(en: 'Sound 2', tr: '2. ses'),
  'bright' => t(en: 'Bright', tr: 'Parlak'),
  'dark' => t(en: 'Sad', tr: 'Hüzünlü'),
  'three' => t(en: 'Three notes', tr: 'Üç ses'),
  'four' => t(en: 'Four notes', tr: 'Dört ses'),
  _ => key,
};

/// Seçenek ikonları — metin okunmadan da anlaşılsın ("6 yaşında testi").
IconData chordOptionIcon(String key) => switch (key) {
  'soundA' => Icons.looks_one_rounded,
  'soundB' => Icons.looks_two_rounded,
  'bright' => Icons.wb_sunny_rounded,
  'dark' => Icons.nights_stay_rounded,
  'three' => Icons.filter_3_rounded,
  'four' => Icons.filter_4_rounded,
  _ => Icons.help_outline_rounded,
};

/// Akor renginin GÖRÜNEN adı (his + parantez içinde terim).
///
/// Terim parantezde ve HİSTEN SONRA: kullanıcı önce ne duyduğunu bilir, adı
/// yanında durur. Böylece "gergin ne demek?" sorusu doğmaz — gergin olan şeyi
/// zaten kendi kurmuştur.
String chordColorName(ChordQuality quality) => switch (quality) {
  ChordQuality.major => t(en: 'Bright (major)', tr: 'Parlak (majör)'),
  ChordQuality.minor => t(en: 'Sad (minor)', tr: 'Hüzünlü (minör)'),
  ChordQuality.diminished => t(
    en: 'Tense (diminished)',
    tr: 'Gergin (eksik)',
  ),
  ChordQuality.augmented => t(
    en: 'Floating (augmented)',
    tr: 'Askıda (artık)',
  ),
  _ => quality.label,
};

/// Ders listesi — locale-anahtarlı önbellek (dil değişince yeni dilde kurulur).
final Map<String, List<ChordLesson>> _lessonCache = {};

List<ChordLesson> get chordLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildChordLessons);

const List<ChordQuality> _majorMinor = [
  ChordQuality.major,
  ChordQuality.minor,
];

const List<ChordQuality> _fourColors = [
  ChordQuality.major,
  ChordQuality.minor,
  ChordQuality.diminished,
  ChordQuality.augmented,
];

List<ChordLesson> _buildChordLessons() => [
  ChordLesson(
    id: 'ch_bright',
    title: t(en: '1 · Match the Sound', tr: '1 · Aynısını Bul'),
    promise: t(
      en: 'You will pick a chord out of two by ear — the first step of copying '
          'a chord you hear in a song.',
      tr: 'İki akordan duyduğunu kulakla seçebileceksin — bir şarkıda duyduğun '
          'akoru taklit etmenin ilk adımı.',
    ),
    drill: ChordDrill.match,
    qualities: _majorMinor,
  ),
  ChordLesson(
    id: 'ch_color',
    title: t(en: '2 · Bright or Sad?', tr: '2 · Parlak mı Hüzünlü mü?'),
    promise: t(
      en: 'You will call a chord bright or sad from one listen — so you know '
          'which shape to reach for before you even touch the instrument.',
      tr: 'Bir akorun parlak mı hüzünlü mü olduğunu tek dinleyişte '
          'söyleyebileceksin — enstrümana dokunmadan hangi şekli tutacağını '
          'bilirsin.',
    ),
    drill: ChordDrill.color,
    qualities: _majorMinor,
    badge: TheoryBadge(
      term: t(en: 'Major & Minor', tr: 'Majör & Minör'),
      insight: t(
        en: 'The bright one is called MAJOR, the sad one MINOR. Almost every '
            'song you know is built from these two — and you can now tell them '
            'apart on purpose.',
        tr: 'Parlak olana MAJÖR, hüzünlü olana MİNÖR denir. Bildiğin neredeyse '
            'her şarkı bu ikisinden kuruludur — artık onları bilerek ayırt '
            'edebiliyorsun.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_third',
    title: t(en: '3 · The Recipe', tr: '3 · Akorun Tarifi'),
    promise: t(
      en: 'You will learn how a chord is actually built — count up from one '
          'note and a major or minor chord appears under your fingers.',
      tr: 'Bir akorun gerçekte nasıl kurulduğunu öğreneceksin — tek bir sesten '
          'sayarak majör ya da minör akoru parmaklarının altında kuracaksın.',
    ),
    drill: ChordDrill.build,
    qualities: _majorMinor,
    // Rengi SÖYLERİZ ve sıradaki tuşu işaretleriz: bu ders bir sınav değil,
    // tarifin öğretildiği yer. Sınav bir sonraki derste.
    colorIsHeard: false,
    guided: true,
    questionCount: 5,
    badge: TheoryBadge(
      term: t(en: 'The third', tr: 'Üçlü'),
      insight: t(
        en: 'That middle note you kept placing is the THIRD. Four keys up from '
            'the root makes a chord bright, three keys up makes it sad — that '
            'one note carries the whole mood of a song.',
        tr: 'Ortaya koyduğun o ses ÜÇLÜdür. Kökten dört tuş yukarısı akoru '
            'parlak, üç tuş yukarısı hüzünlü yapar — bir şarkının bütün '
            'havasını o tek ses taşır.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_build',
    title: t(en: '4 · Play What You Hear', tr: '4 · Duyduğunu Çal'),
    promise: t(
      en: 'You will hear a chord and play the very same chord back — this is '
          'the whole point of the track.',
      tr: 'Bir akoru duyup aynısını kendin çalabileceksin — bu track\'in bütün '
          'meselesi bu.',
    ),
    drill: ChordDrill.build,
    qualities: _majorMinor,
    questionCount: 5,
  ),
  ChordLesson(
    id: 'ch_tense',
    title: t(en: '5 · Two More Colours', tr: '5 · İki Renk Daha'),
    promise: t(
      en: 'You will build the two unsettled chords films use when something is '
          'about to happen — and hear why they feel that way.',
      tr: 'Filmlerde bir şey olmak üzereyken kullanılan iki huzursuz akoru '
          'kurabileceksin — ve neden öyle hissettirdiklerini duyacaksın.',
    ),
    drill: ChordDrill.build,
    qualities: _fourColors,
    colorIsHeard: false,
    guided: true,
    questionCount: 6,
    badge: TheoryBadge(
      term: t(en: 'Diminished & Augmented', tr: 'Eksik & Artık'),
      insight: t(
        en: 'Even steps make an unsettled chord. Three-and-three is DIMINISHED '
            '(tense, wants to move); four-and-four is AUGMENTED (floating, '
            'nowhere to land). You just built both.',
        tr: 'Eşit adımlar huzursuz bir akor yapar. Üç-üç EKSİK akordur '
            '(gergin, hareket etmek ister); dört-dört ARTIK akordur (askıda, '
            'inecek yeri yoktur). İkisini de az önce sen kurdun.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_seventh',
    title: t(en: '6 · Three or Four?', tr: '6 · Üç mü Dört mü?'),
    promise: t(
      en: 'You will hear when a fourth note is stacked on a chord — the sound '
          'of almost every jazz and soul record.',
      tr: 'Bir akorun üstüne dördüncü bir ses bindiğini duyabileceksin — '
          'neredeyse her caz ve soul kaydının sesi.',
    ),
    drill: ChordDrill.countTones,
    qualities: const [
      ChordQuality.major,
      ChordQuality.minor,
      ChordQuality.dominant7,
      ChordQuality.major7,
      ChordQuality.minor7,
    ],
    badge: TheoryBadge(
      term: t(en: 'Seventh chords', tr: 'Yedili akorlar'),
      insight: t(
        en: 'A chord with a fourth note stacked on is a SEVENTH chord. That '
            'extra note is what makes music sound smoky rather than plain.',
        tr: 'Üstüne dördüncü ses binen akora YEDİLİ akor denir. O fazladan ses, '
            'müziği düz olmaktan çıkarıp dumanlı yapan şeydir.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_master',
    title: t(en: '★ Play Any Chord', tr: '★ Hepsini Çal'),
    promise: t(
      en: 'You will hear any of the four colours and play it straight back — '
          'the chord half of working a song out by ear.',
      tr: 'Dört rengin hangisi gelirse gelsin duyup hemen çalabileceksin — bir '
          'şarkıyı kulakla çıkarmanın akor tarafı.',
    ),
    drill: ChordDrill.build,
    qualities: _fourColors,
    questionCount: 6,
  ),
];
