import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../lesson/theory_badge.dart';
import 'chord_round.dart';

// -----------------------------------------------------------------------------
// AKORLAR — "akorun rengini duy, o sesi kendin çıkar"
//
// Track 2026-08-17'de KÖKTEN yeniden kuruldu (13 ders → 8). Eski hâli
// uygulamadaki son "çoktan seçmeli etiketleme" adasıydı ve üç sorunu vardı:
//   1. "Bu hangi akor?" iki beceriyi (kök + renk) tek soruda soruyordu;
//      üstelik kök bulma Armoni Kulağı'nın omurgası — çakışma.
//   2. "Bu kaçıncı çevrim?" bir analiz sorusuydu (kaldırılan teori
//      track'lerindeki hatanın aynısı).
//   3. Söyleme adımı akoru ARPEJLEYEREK söyletiyordu — bu, akoru melodiye
//      çevirmek demek; akor kulağını hiç çalıştırmıyordu.
//
// YENİ YAY — algıdan üretime, sonra yeni renklere:
//   parlak/hüzünlü ayır → tek akorda ayır → RENGİ VEREN SESİ ÜRET →
//   tepe sesini bul → akoru kendin kur → gergin renkler → yedililer → usta
//
// Sorular TERİM sormaz ("majör mü?" değil "parlak mı?"); terim en sonda rozet.
// Üç ders doğrudan ÜRETİMdir: kullanıcı duyduğu sesi kendi sesiyle ya da
// tuşlarda nokta atışı bulur — uygulamanın çekirdek Duy→Söyle döngüsü.
// -----------------------------------------------------------------------------

class ChordLesson {
  final String id;
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir.
  final String promise;

  final ChordDrill drill;

  final int questionCount;

  final TheoryBadge? badge;

  const ChordLesson({
    required this.id,
    required this.title,
    required this.promise,
    required this.drill,
    this.questionCount = 6,
    this.badge,
  });

  /// Bu ders ses ÜRETTİRİYOR mu? (akış hangi ekranı açacağını buna bakar)
  bool get isProduction =>
      drill == ChordDrill.findThird ||
      drill == ChordDrill.findTop ||
      drill == ChordDrill.buildChord;
}

/// Seçenek anahtarı → GÖRÜNEN metin. Anahtarlar dil-bağımsız (karıştırma
/// sayaçları onları kullanır), çeviri burada yaşar.
String chordOptionLabel(String key) => switch (key) {
  'first' => t(en: 'The first one', tr: 'Birincisi'),
  'second' => t(en: 'The second one', tr: 'İkincisi'),
  'bright' => t(en: 'Bright', tr: 'Parlak'),
  'dark' => t(en: 'Sad', tr: 'Hüzünlü'),
  'tense' => t(en: 'Tense', tr: 'Gergin'),
  'floating' => t(en: 'Floating', tr: 'Askıda'),
  'three' => t(en: 'Three notes', tr: 'Üç ses'),
  'four' => t(en: 'Four notes', tr: 'Dört ses'),
  _ => key,
};

/// Seçenek ikonları — metin okunmadan da anlaşılsın ("6 yaşında testi").
IconData chordOptionIcon(String key) => switch (key) {
  'first' => Icons.looks_one_rounded,
  'second' => Icons.looks_two_rounded,
  'bright' => Icons.wb_sunny_rounded,
  'dark' => Icons.nights_stay_rounded,
  'tense' => Icons.bolt_rounded,
  'floating' => Icons.cloud_rounded,
  'three' => Icons.filter_3_rounded,
  'four' => Icons.filter_4_rounded,
  _ => Icons.help_outline_rounded,
};

/// Ders listesi — locale-anahtarlı önbellek (dil değişince yeni dilde kurulur).
final Map<String, List<ChordLesson>> _lessonCache = {};

List<ChordLesson> get chordLessons =>
    _lessonCache.putIfAbsent(ContentLocale.code, _buildChordLessons);

List<ChordLesson> _buildChordLessons() => [
  ChordLesson(
    id: 'ch_bright',
    title: t(en: '1 · Which One Is Bright?', tr: '1 · Hangisi Parlak?'),
    promise: t(
      en: 'You will hear the difference between the two most common chord '
          'colours — the single biggest sound in all of music.',
      tr: 'En yaygın iki akor rengi arasındaki farkı duyabileceksin — bütün '
          'müzikteki en büyük tek ses farkı.',
    ),
    drill: ChordDrill.brighter,
  ),
  ChordLesson(
    id: 'ch_color',
    title: t(en: '2 · Bright or Sad?', tr: '2 · Parlak mı Hüzünlü mü?'),
    promise: t(
      en: 'You will name a chord\'s mood from a single listen, with nothing to '
          'compare it against.',
      tr: 'Bir akorun havasını tek dinleyişte, karşılaştıracak hiçbir şey '
          'olmadan söyleyebileceksin.',
    ),
    drill: ChordDrill.color,
    badge: TheoryBadge(
      term: t(en: 'Major & Minor', tr: 'Majör & Minör'),
      insight: t(
        en: 'The bright one is called MAJOR, the sad one MINOR. You have been '
            'hearing them your whole life — now you can tell them apart on '
            'purpose.',
        tr: 'Parlak olana MAJÖR, hüzünlü olana MİNÖR denir. Hayatın boyunca '
            'bunları duydun — artık bilerek ayırt edebiliyorsun.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_third',
    title: t(en: '3 · Find the Colour', tr: '3 · Rengi Bul'),
    promise: t(
      en: 'You will find the exact note that makes a chord bright or sad — on '
          'the keys or with your own voice.',
      tr: 'Bir akoru parlak ya da hüzünlü yapan sesi tam olarak '
          'bulabileceksin — tuşlarda ya da kendi sesinle.',
    ),
    drill: ChordDrill.findThird,
    badge: TheoryBadge(
      term: t(en: 'The third', tr: 'Üçlü'),
      insight: t(
        en: 'That note you kept finding is the THIRD. It is the only note that '
            'differs between a major and a minor chord — the whole mood of a '
            'song hangs on it.',
        tr: 'Bulup durduğun o ses ÜÇLÜdür. Majör ile minör akor arasındaki '
            'TEK farklı ses odur — bir şarkının bütün havası ona bağlıdır.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_top',
    title: t(en: '4 · The Top Note', tr: '4 · Tepe Sesi'),
    promise: t(
      en: 'You will pick out the highest note inside a chord — the one a '
          'melody usually sits on.',
      tr: 'Bir akorun içindeki en tiz sesi ayırt edebileceksin — melodinin '
          'genelde üstüne oturduğu ses.',
    ),
    drill: ChordDrill.findTop,
    questionCount: 5,
  ),
  ChordLesson(
    id: 'ch_build',
    title: t(en: '5 · Build the Chord', tr: '5 · Akoru Kur'),
    promise: t(
      en: 'You will build a chord yourself from a single starting note — sing '
          'or play all three notes, in tune.',
      tr: 'Tek bir başlangıç sesinden akoru kendin kurabileceksin — üç sesin '
          'hepsini, akortlu şekilde söyle ya da çal.',
    ),
    drill: ChordDrill.buildChord,
    questionCount: 5,
    badge: TheoryBadge(
      term: t(en: 'Arpeggio', tr: 'Arpej'),
      insight: t(
        en: 'Playing a chord one note at a time is called an ARPEGGIO — what a '
            'guitarist does string by string. Building one yourself is how '
            'chords stop being a wall of sound and become three notes you own.',
        tr: 'Bir akoru tek tek seslendirmeye ARPEJ denir — gitaristin tel tel '
            'çalması gibi. Akoru kendin kurmak, onu bir ses duvarı olmaktan '
            'çıkarıp sahip olduğun üç sese çevirir.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_tense',
    title: t(en: '6 · Tense Colours', tr: '6 · Gergin Renkler'),
    promise: t(
      en: 'You will spot the two unsettled chords — the ones films use when '
          'something is about to happen.',
      tr: 'Huzursuz iki akoru yakalayabileceksin — filmlerde bir şey olmak '
          'üzereyken kullanılanlar.',
    ),
    drill: ChordDrill.tense,
  ),
  ChordLesson(
    id: 'ch_seventh',
    title: t(en: '7 · Three or Four?', tr: '7 · Üç mü Dört mü?'),
    promise: t(
      en: 'You will hear when a fourth note is stacked on top of a chord — the '
          'sound of almost every jazz and soul record.',
      tr: 'Bir akorun üstüne dördüncü bir ses bindiğini duyabileceksin — '
          'neredeyse her caz ve soul kaydının sesi.',
    ),
    drill: ChordDrill.countTones,
    badge: TheoryBadge(
      term: t(en: 'Seventh chords', tr: 'Yedili akorlar'),
      insight: t(
        en: 'A chord with a fourth note stacked on is called a SEVENTH chord. '
            'That extra note is what makes music sound smoky rather than plain.',
        tr: 'Üstüne dördüncü ses binen akora YEDİLİ akor denir. O fazladan ses, '
            'müziği düz olmaktan çıkarıp dumanlı yapan şeydir.',
      ),
    ),
  ),
  ChordLesson(
    id: 'ch_master',
    title: t(en: '★ Colour Master', tr: '★ Renk Ustası'),
    promise: t(
      en: 'You will take on every colour at once: bright, sad, tense, floating '
          'and thick.',
      tr: 'Bütün renklerin altından bir arada kalkabileceksin: parlak, '
          'hüzünlü, gergin, askıda ve kalın.',
    ),
    drill: ChordDrill.master,
    questionCount: 8,
  ),
];
