import '../../core/content_locale.dart';
import '../lesson/theory_badge.dart';
import 'rhythm_pattern.dart';

// -----------------------------------------------------------------------------
// RİTİM KULAĞI — "müziğin NEREDE olduğunu duymak"
//
// Eko Oyunu'nun ritim versiyonu: kalıp çalınır, kullanıcı DOKUNARAK tekrarlar.
// Perde yok, yalnızca zamanlama. Onaylanan mekaniğin aynısı — duy, geri kur —
// bu yüzden yeni bir soru tipi icat edilmedi; zorluk tek bir yayda büyür:
// vuruş sayısı → araya giren sesler (senkop) → uzunluk.
//
// KUZEY YILDIZINA BAĞI: transkripsiyonun yarısı "hangi akor", diğer yarısı
// "NEREDE değişiyor". Armoni Kulağı birincisini, bu track ikincisini verir.
// Son rozet bu bağı açıkça kurar.
// -----------------------------------------------------------------------------

class RhythmLesson {
  final String id;
  final String title;

  /// "Bu dersten sonra şunu yapabileceksin" — derse girmeden gösterilir.
  final String promise;

  final RhythmShape shape;

  /// Bir vuruşun "doğru" sayılması için izin verilen sapma (ms).
  ///
  /// Ders ilerledikçe daralır: kulak keskinleştikçe ölçüt de keskinleşir.
  /// ÜST SINIR: en küçük ızgara biriminin YARISI. Daha geniş bir pencere
  /// komşu yuvayla örtüşür ve yanlış kalıbı da "doğru" sayardı — sekizlik
  /// derslerde (300 ms ızgara) bu yüzden tavan 150 ms'dir.
  /// (test/rhythm_pattern_test.dart bunu kilitler.)
  final int toleranceMs;

  final int questionCount;

  final TheoryBadge? badge;

  const RhythmLesson({
    required this.id,
    required this.title,
    required this.promise,
    required this.shape,
    this.toleranceMs = 200,
    this.questionCount = 6,
    this.badge,
  });
}

/// Ders listesi — locale-anahtarlı önbellek (dil değişince yeni dilde kurulur).
final Map<String, List<RhythmLesson>> _cache = {};

List<RhythmLesson> get rhythmLessons =>
    _cache.putIfAbsent(ContentLocale.code, _build);

List<RhythmLesson> _build() => [
  RhythmLesson(
    id: 'rhy1',
    title: t(en: '1 · Two Hits', tr: '1 · İki Vuruş'),
    promise: t(
      en: 'You will tap back the gap between two hits exactly as you heard it '
          '— the smallest piece of rhythm there is.',
      tr: 'İki vuruş arasındaki boşluğu duyduğun gibi geri vurabileceksin — '
          'ritmin en küçük parçası.',
    ),
    shape: const RhythmShape(beats: 4, onsetCount: 2),
    toleranceMs: 220,
    questionCount: 5,
  ),
  RhythmLesson(
    id: 'rhy2',
    title: t(en: '2 · Three Hits', tr: '2 · Üç Vuruş'),
    promise: t(
      en: 'You will hold a three-hit pattern in your ear and tap it back in '
          'order.',
      tr: 'Üç vuruşluk bir kalıbı kulağında tutup sırasıyla geri '
          'vurabileceksin.',
    ),
    shape: const RhythmShape(beats: 4, onsetCount: 3),
    toleranceMs: 200,
  ),
  RhythmLesson(
    id: 'rhy3',
    title: t(en: '3 · A Full Bar', tr: '3 · Dolu Ölçü'),
    promise: t(
      en: 'You will keep an even pulse going across four hits without drifting.',
      tr: 'Dört vuruş boyunca eşit bir tempoyu kaymadan sürdürebileceksin.',
    ),
    shape: const RhythmShape(beats: 4, onsetCount: 4),
    toleranceMs: 190,
    badge: TheoryBadge(
      term: t(en: 'Beat', tr: 'Vuruş'),
      insight: t(
        en: 'Those hits all landed the same distance apart. That even spacing '
            'is the BEAT — the thing your foot taps to when a song is playing.',
        tr: 'O vuruşların hepsi birbirinden eşit uzaklığa düştü. Bu eşit '
            'aralığa VURUŞ denir — bir şarkı çalarken ayağınla tuttuğun şey.',
      ),
    ),
  ),
  RhythmLesson(
    id: 'rhy4',
    title: t(en: '4 · In Between', tr: '4 · Araya Girenler'),
    promise: t(
      en: 'You will catch hits that fall between the beats, not just on them.',
      tr: 'Vuruşun üstüne değil ARASINA düşen sesleri de yakalayabileceksin.',
    ),
    shape: const RhythmShape(
      beats: 4,
      onsetCount: 4,
      subdivision: 2,
      allowOffbeat: true,
    ),
    toleranceMs: 145,
  ),
  RhythmLesson(
    id: 'rhy5',
    title: t(en: '5 · Off the Beat', tr: '5 · Senkop'),
    promise: t(
      en: 'You will tap back patterns that lean off the beat — the thing that '
          'makes music groove instead of march.',
      tr: 'Vuruşun dışına yaslanan kalıpları geri vurabileceksin — müziğe '
          'yürüyüş yerine kıvraklık veren şey.',
    ),
    shape: const RhythmShape(
      beats: 4,
      onsetCount: 5,
      subdivision: 2,
      allowOffbeat: true,
    ),
    toleranceMs: 140,
    badge: TheoryBadge(
      term: t(en: 'Syncopation', tr: 'Senkop'),
      insight: t(
        en: 'Some of those hits landed BETWEEN the beats instead of on them. '
            'That is SYNCOPATION — it is what gives a song its swing.',
        tr: 'O seslerin bazıları vuruşun üstüne değil ARASINA düştü. Buna '
            'SENKOP denir — bir şarkıya kıvraklığını veren şey budur.',
      ),
    ),
  ),
  RhythmLesson(
    id: 'rhy6',
    title: t(en: '6 · Longer Pattern', tr: '6 · Uzun Kalıp'),
    promise: t(
      en: 'You will remember a longer pattern after one listen, without losing '
          'the count.',
      tr: 'Daha uzun bir kalıbı tek dinleyişte, sayıyı kaybetmeden aklında '
          'tutabileceksin.',
    ),
    shape: const RhythmShape(beats: 8, onsetCount: 5),
    toleranceMs: 180,
    questionCount: 5,
  ),
  RhythmLesson(
    id: 'rhy7',
    title: t(en: '7 · Rhythm Hunt', tr: '7 · Ritim Avı'),
    promise: t(
      en: 'You will take on any short rhythm: length and off-beat hits at once.',
      tr: 'Her türlü kısa ritmin altından kalkabileceksin: uzunluk ve senkop '
          'bir arada.',
    ),
    shape: const RhythmShape(
      beats: 8,
      onsetCount: 6,
      subdivision: 2,
      allowOffbeat: true,
    ),
    toleranceMs: 130,
    questionCount: 5,
    badge: TheoryBadge(
      term: t(en: 'Bar', tr: 'Ölçü'),
      insight: t(
        en: 'Songs are cut into equal packets called BARS. Chords usually '
            'change at the start of one — so if you can hear the rhythm, you '
            'can hear WHERE the chord changes. That is the other half of '
            'working a song out.',
        tr: 'Şarkılar eşit paketlere bölünür; her pakete ÖLÇÜ denir. Akorlar '
            'genellikle bir ölçünün başında değişir — yani ritmi '
            'duyabiliyorsan, akorun NEREDE değiştiğini de duyabilirsin. '
            'Şarkı çıkarmanın diğer yarısı budur.',
      ),
    ),
  ),
];
