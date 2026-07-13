import '../../core/concept.dart';
import '../../core/interval.dart';

/// Bir aralık dersi = kimlik + başlık + o derste çalışılan aralıklar (+ kavram
/// kartı). Nota/akor dersleri gibi ilerler; bir ders geçilince sonraki açılır.
class IntervalLesson {
  final String id;
  final String title;
  final List<MusicInterval> pool;
  final Concept? concept;
  const IntervalLesson({
    required this.id,
    required this.title,
    required this.pool,
    this.concept,
  });
}

/// Aralık müfredatı — kolaydan zora (geniş/açık aralıklardan dar/yakınlara).
/// Melodik (kök → üst, çıkıcı) çalınır.
final List<IntervalLesson> intervalLessons = [
  IntervalLesson(
    id: 'iv1',
    title: '1 · İlk Aralıklar',
    pool: [iv(4), iv(7), iv(12)], // Büyük 3'lü, Tam 5'li, Oktav
    concept: const Concept(
      title: 'Aralık Nedir?',
      sections: [
        ConceptSection(
          'Aralık, iki nota arasındaki mesafedir. Melodiler bu mesafelerden '
          '(atlamalardan) örülür.',
        ),
        ConceptSection(
          heading: 'Bu derste',
          'Büyük 3\'lü, Tam 5\'li ve Oktav — üçü de geniş, açık ve birbirinden '
          'kolay ayrılan aralıklar.',
        ),
        ConceptSection(
          heading: 'Nasıl dinle?',
          'Önce kökü, hemen ardından üst notayı duyacaksın. İki ses arasındaki '
          '"atlama" ne kadar büyük — ona odaklan.',
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv2',
    title: '2 · Üçlüler',
    pool: [iv(2), iv(3), iv(4)], // Büyük 2'li, Küçük 3'lü, Büyük 3'lü
    concept: const Concept(
      title: 'Renk Burada Doğar: 3\'lüler',
      sections: [
        ConceptSection(
          'Küçük 3\'lü (3 yarım ses) ile Büyük 3\'lü (4 yarım ses) arasında '
          'yalnızca bir yarım ses fark var — ama biri hüzünlü, biri parlak duyulur.',
        ),
        ConceptSection(
          heading: 'Neden önemli?',
          'Akorların majör/minör rengi tam da bu üçlüden gelir. Bu farkı '
          'duyabilmek her şeyin anahtarıdır.',
        ),
        ConceptSection(
          heading: 'Büyük 2\'li',
          'Karşılaştırma için bir de komşu adım (2\'li) var — üçlülerden daha dar.',
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv3',
    title: '3 · Dörtlü · Triton · Beşli',
    pool: [iv(5), iv(6), iv(7)], // Tam 4'lü, Triton, Tam 5'li
    concept: const Concept(
      title: 'Açık ve Gergin',
      sections: [
        ConceptSection(
          'Tam 4\'lü ve Tam 5\'li "açık, kararlı, oturmuş" duyulur — marşların ve '
          'ilahilerin sesi.',
        ),
        ConceptSection(
          heading: 'Triton',
          'Tam tam 4\'lü ile 5\'li arasında kalan Triton gergin, kararsız, '
          'huzursuz bir aralıktır (eskiden "şeytanın aralığı" denirdi).',
        ),
      ],
    ),
  ),
  IntervalLesson(
    id: 'iv4',
    title: '4 · Karışık Aralıklar',
    pool: [iv(2), iv(3), iv(4), iv(5), iv(7), iv(9), iv(12)],
    concept: const Concept(
      title: 'Karışık Aralıklar',
      sections: [
        ConceptSection(
          'Öğrendiğin aralıklar farklı köklerde karışık gelir. Amaç: mesafeyi '
          'kökten bağımsız, sadece "boyutundan" tanımak.',
        ),
        ConceptSection(
          heading: 'İpucu',
          'Bildiğin şarkıların başındaki atlamalarla eşleştir. Örneğin Tam 5\'li, '
          '"Twinkle Twinkle / Daha Dün Annemizin" başlangıcındaki sıçramadır.',
        ),
      ],
    ),
  ),
];
