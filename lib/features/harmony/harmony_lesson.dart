import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import '../lesson/theory_badge.dart';
import 'harmony_round.dart';

// -----------------------------------------------------------------------------
// ARMONİ KULAĞI — "şarkının akorlarını çıkarabilmek"
//
// KUZEY YILDIZI: bir müzik duyunca akorlarını çıkarıp o şarkıyı çalabilmek.
// Bu track o hedefe giden ana yol; OMURGASI bas duymaktır — bas neredeyse her
// zaman akorun kökünü söyler, yani ilerlemenin iskeletini verir.
//
// ⚠️ CİHAZ TESTİNİN DERSİ (2026-08-16): ilk sürümde "Ev Neresi?", "Dinlendi
// mi?" ve "Sıradaki Akor" dersleri vardı; kullanıcı üçünü de reddetti ("ne
// yaptığımı ben bile anlamıyorum"). Teşhis, kaldırılan teori track'lerindeki
// hatanın aynısı: cevap duyulan sesin İÇİNDE değildi, kullanıcıdan bir YORUM
// (ev neresi / dinlendi mi) ya da hiç çalmamış bir sesin TAHMİNİ isteniyordu.
// Aynı kullanıcı "Kalıbı Çöz"ü çok sevdi — çünkü orada cevap duyduğu şeyin
// kendisi, işi de onu geri kurmak.
//
// Bu yüzden track artık TEK BİR YAY, sevilen mekaniğin büyüme basamakları:
//   duy → kaç ses · değişti mi · nereye gitti  (algı, cevap sesin içinde)
//   → tek bası bul → bütün bas hattını çıkar   (üretim, tek ses → hat)
//   → iki akoru diz → dördü diz → tuzaklarla diz (transkripsiyon)
// Melodi Kulağı'nda işe yarayan desen buydu: tek oyun, sekiz zorluk kademesi.
//
// Kullanıcı hiçbir şeyi ETİKETLEMEZ. Roma rakamı, derece adı, işlev adı
// yüzeyde YOK; teori en sonda, yaşandıktan sonra ROZET olur.
// -----------------------------------------------------------------------------

class HarmonyLesson {
  final String id;
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir.
  final String promise;

  /// Sorunun mekaniği (hangi ekranın açılacağını da bu belirler).
  final HarmonyDrill drill;

  /// Kullanılacak derece havuzu (1..7). Tuş sırası da bundan kurulur.
  final List<int> degrees;

  /// Kalıp derslerinde kaç akor dizilecek (yalnızca [HarmonyDrill.pattern]).
  final int patternLength;

  /// Kalıp derslerinde palete eklenen, HİÇ ÇALMAYAN akor sayısı.
  final int decoyCount;

  final int questionCount;

  /// Her soruda "ev" değişsin mi? Beceriyi tek bir tondan koparır.
  final bool varyKey;

  /// Ders sonunda açılan teori rozeti.
  final TheoryBadge? badge;

  const HarmonyLesson({
    required this.id,
    required this.title,
    required this.promise,
    required this.drill,
    required this.degrees,
    this.patternLength = 4,
    this.decoyCount = 0,
    this.questionCount = 6,
    this.varyKey = false,
    this.badge,
  });
}

/// İki seçenekli soruların GÖRÜNEN cevapları — sıra [choiceKeysOf] ile birebir
/// aynıdır (o liste dil-bağımsız anahtarları, bu liste çevirileri tutar).
List<String> choiceLabelsOf(HarmonyDrill drill) => switch (drill) {
  HarmonyDrill.howMany => [
    t(en: 'One sound', tr: 'Tek ses'),
    t(en: 'Two sounds', tr: 'İki ses'),
  ],
  HarmonyDrill.changed => [
    t(en: 'Stayed the same', tr: 'Aynı kaldı'),
    t(en: 'It changed', tr: 'Değişti'),
  ],
  HarmonyDrill.bassDirection => [
    t(en: 'Went up', tr: 'Yukarı çıktı'),
    t(en: 'Went down', tr: 'Aşağı indi'),
  ],
  _ => const [],
};

/// Cevap şıklarının ikonları — okumadan da anlaşılsın diye ("6 yaşında testi").
List<IconData> choiceIconsOf(HarmonyDrill drill) => switch (drill) {
  HarmonyDrill.howMany => const [
    Icons.looks_one_rounded,
    Icons.looks_two_rounded,
  ],
  HarmonyDrill.changed => const [
    Icons.drag_handle_rounded,
    Icons.swap_horiz_rounded,
  ],
  HarmonyDrill.bassDirection => const [
    Icons.arrow_upward_rounded,
    Icons.arrow_downward_rounded,
  ],
  _ => const [],
};

/// Ders listesi — locale-anahtarlı önbellek (dil değişince yeni dilde kurulur).
final Map<String, List<HarmonyLesson>> _cache = {};

List<HarmonyLesson> get harmonyLessons =>
    _cache.putIfAbsent(ContentLocale.code, _build);

// NOT (id'ler): 'har8' bu listede 7. sıradadır. Ders id'leri kalıcıdır ve
// SIRAYI ANLATMAZ (PROJECT.md §17.2) — sıralama değişse de kullanıcının
// ilerlemesi yerinde kalsın diye başlıktaki numara ile id kasıtlı olarak
// birbirinden bağımsızdır.
List<HarmonyLesson> _build() => [
  HarmonyLesson(
    id: 'har1',
    title: t(en: '1 · How Many Sounds?', tr: '1 · Kaç Ses?'),
    promise: t(
      en: 'You will hear whether one note or two notes are sounding at the '
          'same time — the very first step of hearing chords.',
      tr: 'Tek ses mi yoksa aynı anda iki ses mi çaldığını duyabileceksin — '
          'akor duymanın ilk adımı.',
    ),
    drill: HarmonyDrill.howMany,
    degrees: const [1, 2, 3, 4, 5, 6],
    badge: TheoryBadge(
      term: t(en: 'Harmony', tr: 'Armoni'),
      insight: t(
        en: 'When two or more notes sound at the same time, that stack is '
            'HARMONY. Every chord in every song is built from it — and you can '
            'now hear when it is there.',
        tr: 'İki ya da daha çok ses aynı anda duyulduğunda buna ARMONİ denir. '
            'Her şarkıdaki her akor bundan yapılmıştır — artık orada olup '
            'olmadığını duyabiliyorsun.',
      ),
    ),
  ),
  HarmonyLesson(
    id: 'har2',
    title: t(en: '2 · Did It Change?', tr: '2 · Değişti mi?'),
    promise: t(
      en: 'You will catch the exact moment a song changes chord — the thing '
          'you need before you can write any chords down.',
      tr: 'Bir şarkıda akorun değiştiği anı yakalayabileceksin — akorları '
          'çıkarmadan önce gereken ilk şey.',
    ),
    drill: HarmonyDrill.changed,
    degrees: const [1, 2, 3, 4, 5, 6],
  ),
  HarmonyLesson(
    id: 'har3',
    title: t(en: '3 · Where Did the Bass Go?', tr: '3 · Bas Nereye Gitti?'),
    promise: t(
      en: 'You will hear whether the lowest note went up or down when the '
          'chord changed.',
      tr: 'Akor değişince en pes sesin yukarı mı yoksa aşağı mı gittiğini '
          'duyabileceksin.',
    ),
    drill: HarmonyDrill.bassDirection,
    degrees: const [1, 2, 4, 5, 6],
    badge: TheoryBadge(
      term: t(en: 'Bass', tr: 'Bas'),
      insight: t(
        en: 'That lowest note you have been following is the BASS. It is the '
            'skeleton of a song: follow the bass and the chords follow you.',
        tr: 'Takip ettiğin o en pes ses BAStır. Şarkının iskeleti odur: bası '
            'takip edersen akorlar peşinden gelir.',
      ),
    ),
  ),
  HarmonyLesson(
    id: 'har4',
    title: t(en: '4 · Find the Bass', tr: '4 · Bası Bul'),
    promise: t(
      en: "You will find a chord's lowest note yourself — on the keys or with "
          'your own voice. This is the single most useful trick for working '
          'out chords.',
      tr: 'Bir akorun en pes sesini kendin bulabileceksin — tuşlarda ya da '
          'kendi sesinle. Akor çıkarmanın en işe yarar tek numarası budur.',
    ),
    drill: HarmonyDrill.findBass,
    degrees: const [1, 4, 5, 6],
  ),
  HarmonyLesson(
    id: 'har_bassline',
    title: t(en: '5 · Trace the Bass Line', tr: '5 · Bas Hattını Çıkar'),
    promise: t(
      en: 'You will work out a whole bass line by ear, note by note — the '
          'skeleton of a song, written down by you.',
      tr: 'Bir bas hattının tamamını kulakla, ses ses çıkarabileceksin — '
          'şarkının iskeletini kendin yazmış olacaksın.',
    ),
    drill: HarmonyDrill.bassLine,
    degrees: const [1, 2, 4, 5, 6],
    questionCount: 5,
    badge: TheoryBadge(
      term: t(en: 'Root', tr: 'Kök'),
      insight: t(
        en: 'The line you just traced is made of ROOTS — every chord is named '
            'after its own root note. Write the roots down and you have '
            "written the song's chords.",
        tr: 'Az önce çıkardığın hat KÖKlerden oluşuyor — her akor kendi kök '
            'sesinin adını taşır. Kökleri yazdıysan şarkının akorlarını '
            'yazmışsın demektir.',
      ),
    ),
  ),
  HarmonyLesson(
    id: 'har_two_chords',
    title: t(en: '6 · Two Chords', tr: '6 · İki Akor'),
    promise: t(
      en: 'You will work out a two-chord change by ear and lay it out — the '
          'smallest real piece of a song.',
      tr: 'İki akorluk bir değişimi kulakla çıkarıp dizebileceksin — bir '
          'şarkının en küçük gerçek parçası.',
    ),
    drill: HarmonyDrill.pattern,
    degrees: const [1, 2, 4, 5, 6],
    patternLength: 2,
  ),
  HarmonyLesson(
    id: 'har8',
    title: t(en: '7 · Crack the Pattern', tr: '7 · Kalıbı Çöz'),
    promise: t(
      en: 'You will lay out a four-chord pattern in the order you heard it — '
          'this is working a song out by ear, chord by chord.',
      tr: 'Dört akorluk bir kalıbı duyduğun sırayla dizebileceksin — bu, bir '
          'şarkıyı kulakla akor akor çıkarmanın ta kendisi.',
    ),
    drill: HarmonyDrill.pattern,
    degrees: const [1, 2, 4, 5, 6],
    questionCount: 5,
    varyKey: true,
    badge: TheoryBadge(
      term: t(en: 'Chord progression', tr: 'Akor kalıbı'),
      insight: t(
        en: 'A repeating run of chords is a PROGRESSION. A handful of them '
            'carry hundreds of songs — and you just took one apart by ear.',
        tr: 'Tekrarlanan akor dizisine AKOR KALIBI denir. Bir avuç kalıp '
            'yüzlerce şarkıyı taşır — az önce birini kulağınla söktün.',
      ),
    ),
  ),
  HarmonyLesson(
    id: 'har_decoys',
    title: t(en: '8 · Pattern with Decoys', tr: '8 · Tuzaklı Kalıp'),
    promise: t(
      en: 'You will pick the right chords out of a pile that also holds chords '
          'that never played — exactly what happens when you work out a real '
          'song.',
      tr: 'Doğru akorları, hiç çalmamış akorların da bulunduğu bir yığından '
          'ayıklayabileceksin — gerçek bir şarkıyı çıkarırken olan tam olarak '
          'budur.',
    ),
    drill: HarmonyDrill.pattern,
    degrees: const [1, 2, 4, 5, 6],
    decoyCount: 2,
    questionCount: 5,
    varyKey: true,
    badge: TheoryBadge(
      term: t(en: 'Transcription', tr: 'Transkripsiyon'),
      insight: t(
        en: 'Writing down music you hear is called TRANSCRIPTION. That is '
            'exactly what you just did — and it is the whole reason this app '
            'exists.',
        tr: 'Duyduğun müziği yazıya dökmeye TRANSKRİPSİYON denir. Az önce '
            'yaptığın şey tam olarak buydu — ve bu uygulamanın var oluş sebebi '
            'de bu.',
      ),
    ),
  ),
];
