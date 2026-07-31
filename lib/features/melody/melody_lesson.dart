import '../../core/content_locale.dart';
import 'melody_generator.dart';

// -----------------------------------------------------------------------------
// MELODİ KULAĞI — "duyduğun ezgiyi çıkarabilmek"
//
// Bu track, kaldırılan dört teori track'inin (Tonalite · İşlev · İlerleme ·
// Yolculuk) yerine gelir. Oradaki kök sorun kategori hatasıydı: müziği
// ETİKETLETİYORDUK ("bu kaçıncı derece?"). Burada kullanıcı hiçbir şey
// etiketlemez — DUYDUĞUNU TEKRARLAR. Müzik öğretmeninin ilk günden yaptığı şey.
//
// Teori ders değil ROZETtir: kavram önce yaşanır, adı sonra konur (bkz.
// [TheoryBadge]). "Tonik" kelimesi, kullanıcı ezgilerin hep aynı sese döndüğünü
// kendi kulağıyla fark ettikten SONRA verilir.
// -----------------------------------------------------------------------------

/// Ders sonunda verilen teori rozeti — yaşanmış bir sezgiye ad koyar.
class TheoryBadge {
  /// Terimin kendisi (ör. "Tonik").
  final String term;

  /// "Şunu fark ettin, adı buymuş" cümlesi.
  final String insight;

  const TheoryBadge({required this.term, required this.insight});
}

class MelodyLesson {
  final String id;
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir.
  final String promise;

  /// Ezgi üretim şekli (zorluk buradan büyür).
  final MelodyShape shape;

  /// Kaç ezgi tekrarlanacak.
  final int questionCount;

  /// Her soruda ev değişsin mi? (beceriyi mutlak perde ezberinden koparır)
  final bool varyKey;

  /// Ders sonunda açılan teori rozeti.
  final TheoryBadge? badge;

  const MelodyLesson({
    required this.id,
    required this.title,
    required this.promise,
    required this.shape,
    this.questionCount = 6,
    this.varyKey = false,
    this.badge,
  });
}

/// Ders listesi — locale-anahtarlı önbellek (dil değişince yeni dilde kurulur).
final Map<String, List<MelodyLesson>> _cache = {};

List<MelodyLesson> get melodyLessons =>
    _cache.putIfAbsent(ContentLocale.code, _build);

List<MelodyLesson> _build() => [
  MelodyLesson(
    id: 'mel1',
    title: t(en: '1 · Two Notes', tr: '1 · İki Ses'),
    promise: t(
      en: 'You will hear two notes and sing or play them back yourself.',
      tr: 'İki sesi duyup aynısını kendin tekrarlayabileceksin.',
    ),
    shape: const MelodyShape(
      noteCount: 2,
      degrees: [1, 2, 3, 4, 5],
      maxLeap: 2,
    ),
    questionCount: 5,
  ),
  MelodyLesson(
    id: 'mel2',
    title: t(en: '2 · Three Notes', tr: '2 · Üç Ses'),
    promise: t(
      en: 'You will hold three notes in your ear and repeat them in order.',
      tr: 'Üç sesi kulağında tutup sırasıyla tekrarlayabileceksin.',
    ),
    shape: const MelodyShape(
      noteCount: 3,
      degrees: [1, 2, 3, 4, 5],
      maxLeap: 2,
    ),
  ),
  MelodyLesson(
    id: 'mel3',
    title: t(en: '3 · The Note It Returns To', tr: '3 · Dönen Ses'),
    promise: t(
      en: 'You will notice that tunes keep coming back to one note — and you '
          'will be able to find it.',
      tr: 'Ezgilerin hep tek bir sese döndüğünü fark edecek ve o sesi '
          'bulabileceksin.',
    ),
    shape: const MelodyShape(
      noteCount: 4,
      degrees: [1, 2, 3, 4, 5],
      maxLeap: 2,
      endOnTonic: true,
    ),
    badge: TheoryBadge(
      term: t(en: 'Tonic', tr: 'Tonik'),
      insight: t(
        en: 'Every tune here came back to the same note at the end. That note '
            'is the "home" of the key — musicians call it the TONIC.',
        tr: 'Buradaki her ezgi sonunda aynı sese döndü. O ses tonalitenin '
            '"evi"dir — müzisyenler ona TONİK der.',
      ),
    ),
  ),
  MelodyLesson(
    id: 'mel4',
    title: t(en: '4 · Five Notes', tr: '4 · Beş Ses'),
    promise: t(
      en: 'You will follow a real little tune and reproduce it note by note.',
      tr: 'Gerçek bir küçük ezgiyi takip edip notasını notasına '
          'tekrarlayabileceksin.',
    ),
    shape: const MelodyShape(
      noteCount: 5,
      degrees: [1, 2, 3, 4, 5, 6],
      maxLeap: 2,
      endOnTonic: true,
    ),
    badge: TheoryBadge(
      term: t(en: 'Scale', tr: 'Dizi'),
      insight: t(
        en: 'The notes these tunes walk on are not random: they are the steps '
            'of a SCALE — the ladder almost every melody climbs.',
        tr: 'Bu ezgilerin bastığı sesler rastgele değil: bir DİZİnin '
            'basamakları — neredeyse her melodinin tırmandığı merdiven.',
      ),
    ),
  ),
  MelodyLesson(
    id: 'mel5',
    title: t(en: '5 · Leaping Tune', tr: '5 · Zıplayan Ezgi'),
    promise: t(
      en: 'You will catch tunes that jump, not just step — the hard part of '
          'singing a song back.',
      tr: 'Adım adım değil ZIPLAYAN ezgileri de yakalayabileceksin — bir '
          'şarkıyı tekrar söylemenin zor kısmı.',
    ),
    shape: const MelodyShape(
      noteCount: 4,
      degrees: [1, 2, 3, 4, 5, 6, 8],
      maxLeap: 6, // havuzun tamamı erişilebilir → gerçek sıçramalar
      endOnTonic: true,
    ),
    // Aralık isimleri ARTIK YALNIZCA BURADA yaşıyor: ayrı bir "Aralıklar"
    // track'i vardı ama orada "Majör 3'lü / Tam 5'li" ezberletmek kulak
    // eğitimi değil terminoloji sınavıydı. İsim, sıçrama DUYULDUKTAN sonra
    // rozet olarak veriliyor.
    badge: TheoryBadge(
      term: t(en: 'Interval', tr: 'Aralık'),
      insight: t(
        en: 'The distance between two notes is called an INTERVAL. Those wide '
            'jumps you just caught are the big ones — musicians name them by '
            'size ("a fifth", "an octave"). You could already hear them; now '
            'they have a name too.',
        tr: 'İki ses arasındaki mesafeye ARALIK denir. Az önce yakaladığın '
            'geniş zıplayışlar bunların büyük olanları — müzisyenler onları '
            'büyüklüğüne göre adlandırır ("beşli", "oktav"). Zaten '
            'duyabiliyordun; artık bir adı da var.',
      ),
    ),
  ),
  MelodyLesson(
    id: 'mel6',
    title: t(en: '6 · Longer Tune', tr: '6 · Uzun Ezgi'),
    promise: t(
      en: 'You will remember a longer phrase after one listen.',
      tr: 'Daha uzun bir ezgiyi tek dinleyişte aklında tutabileceksin.',
    ),
    shape: const MelodyShape(
      noteCount: 6,
      degrees: [1, 2, 3, 4, 5, 6, 7],
      maxLeap: 3,
      endOnTonic: true,
    ),
    questionCount: 5,
  ),
  MelodyLesson(
    id: 'mel7',
    title: t(en: '7 · Another Home', tr: '7 · Başka Ev'),
    promise: t(
      en: 'You will repeat tunes in any key — the skill becomes yours, not the '
          "key's.",
      tr: 'Ezgileri hangi tonda olursa olsun tekrarlayabileceksin — beceri '
          'senin olur, tonalitenin değil.',
    ),
    shape: const MelodyShape(
      noteCount: 5,
      degrees: [1, 2, 3, 4, 5, 6],
      maxLeap: 3,
      endOnTonic: true,
    ),
    varyKey: true,
    badge: TheoryBadge(
      term: t(en: 'Transposition', tr: 'Transpozisyon'),
      insight: t(
        en: 'Same tune, different home. Moving music to another key is called '
            'TRANSPOSITION — it is how you fit a song to your own voice.',
        tr: 'Aynı ezgi, başka ev. Müziği başka bir tona taşımaya TRANSPOZİSYON '
            'denir — bir şarkıyı kendi sesine uydurmanın yolu budur.',
      ),
    ),
  ),
  MelodyLesson(
    id: 'mel8',
    title: t(en: '8 · Melody Hunt', tr: '8 · Ezgi Avı'),
    promise: t(
      en: 'You will take on any short tune: leaps, length and a changing home '
          'all at once.',
      tr: 'Her türlü kısa ezginin altından kalkabileceksin: sıçrama, uzunluk ve '
          'değişen ev, hepsi bir arada.',
    ),
    shape: const MelodyShape(
      noteCount: 7,
      degrees: [1, 2, 3, 4, 5, 6, 7, 8],
      maxLeap: 7, // her şey serbest — gerçek "ezgi avı"
      endOnTonic: true,
    ),
    questionCount: 7,
    varyKey: true,
  ),
];
