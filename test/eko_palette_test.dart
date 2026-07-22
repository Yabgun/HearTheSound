import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/features/mascot/eko_mascot.dart';

// -----------------------------------------------------------------------------
// EKO AVATAR PALETLERİ — §19: seçilen avatar `avatarId` ile saklanır, dolayısıyla
// id'ler ders id'leriyle aynı disiplinde KALICIDIR. Yayınlanmış bir id değişirse
// o rengi seçmiş kullanıcının avatarı sessizce varsayılana döner.
// -----------------------------------------------------------------------------

void main() {
  test('yayınlanmış palet id\'leri donduruldu (silme/yeniden adlandırma yok)', () {
    // Bu set küçülemez/yeniden adlandırılamaz — yalnızca büyüyebilir.
    const shipped = {'grape', 'ocean', 'forest', 'sunset', 'berry', 'mono'};
    final current = kEkoPalettes.map((p) => p.id).toSet();

    expect(
      shipped.difference(current),
      isEmpty,
      reason: 'Kaybolan palet id\'leri kullanıcıların avatarını sıfırlar.',
    );
  });

  test('palet id\'leri benzersiz', () {
    final ids = kEkoPalettes.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('ekoPaletteFor bilinen id\'yi doğru döndürür', () {
    expect(ekoPaletteFor('ocean').id, 'ocean');
    expect(ekoPaletteFor('mono').id, 'mono');
  });

  test('bilinmeyen/null id varsayılana (ilk palet) düşer — çökmez', () {
    final fallback = kEkoPalettes.first.id;
    expect(ekoPaletteFor(null).id, fallback);
    expect(ekoPaletteFor('kaldirilmis-renk').id, fallback);
    expect(ekoPaletteFor('').id, fallback);
  });
}
