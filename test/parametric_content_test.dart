import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/major_key.dart';
import 'package:hear_the_sound/core/note.dart';

// Parametrik içerik — beşler çemberi (MajorKey).
//
// NOT: "Tonalite Yolculuğu" (üretilen işlev/ilerleme dersleri) testleri
// kaldırıldı; o track müfredattan çıkarıldı. MajorKey çekirdekte kalıyor çünkü
// ezgi/akor içeriğini başka tonlara taşımak hâlâ kullanılıyor.

void main() {
  group('MajorKey — beşler çemberi genişlemesi', () {
    test('yeni merkezlerin C’ye uzaklığı doğru', () {
      expect(MajorKey.a.semitonesFromC, 9);
      expect(MajorKey.e.semitonesFromC, 4);
      expect(MajorKey.f.semitonesFromC, 5);
    });

    test('tonicAtOctave doğru perdeyi verir', () {
      expect(MajorKey.a.tonicAtOctave(4).midi, Note.fromName('A', 4).midi);
      expect(MajorKey.f.tonicAtOctave(3).midi, Note.fromName('F', 3).midi);
    });
  });

  // NOT: eski "Nitelik Ustası" capstone testi kaldırıldı — Akorlar track'i
  // 2026-08-17'de yeniden kuruldu; dokuz şıklı etiketleme capstone'u yerine,
  // öğrenilen ALGI sorularını karıştıran 'ch_master' geldi (sözleşmeleri
  // test/chord_round_test.dart'ta).
}
