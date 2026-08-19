import '../home/curriculum.dart';

// -----------------------------------------------------------------------------
// MERDİVEN TESTİ — SAF KISIM (hangi basamak sorulur, geçilince ne açılır)
//
// Eski yerleştirme testi FİİLEN BOZUKTU: yalnızca Notalar ve Akorlar'ı
// yokluyordu, yani beş track'in üçüne (Melodi · Armoni · Ritim) kimseyi
// yerleştiremiyordu. Ezgileri kulakla çıkarabilen biri bile "notaları tanı"
// dersinden başlamak zorunda kalıyordu.
//
// YENİ MANTIK: her track'in EN ZOR dersinden üç soru. Geçersen o track'in
// tamamı "biliniyor" sayılır ve bir üst basamağa geçilir; İLK TAKILDIĞIN YERDE
// test biter. Gerekçe: müfredat sıralı bir zincir, dolayısıyla bir track'i
// bilmiyorsan sonrakini de bilmiyorsundur — sormanın anlamı yok, sorarsak da
// kullanıcıyı bilmediği şeylerle sınamış oluruz.
// -----------------------------------------------------------------------------

/// Merdivenin basamakları: her track'in SON (= en zor) dersinin kimliği.
///
/// TÜRETİLMİŞ, elle yazılmış DEĞİL. Müfredat sırası zorluk sırasıdır, dolayısıyla
/// bir track'in son dersi o track'in en zorudur. Elle liste tutsaydık bir
/// track'in sonuna yeni ders eklendiğinde merdiven sessizce ESKİ (artık en zor
/// olmayan) dersi sormaya devam ederdi → kullanıcı bilmediği bir dersi atlardı.
List<String> get placementRungIds => [
  for (final track in curriculum) track.items.last.id,
];

/// [passedRungs] basamağı geçmiş kullanıcı için "biliniyor" sayılacak ders
/// kimlikleri (`applyPlacement`'a verilir).
///
/// SON DERS KURALI: bütün basamakları geçen kullanıcıda bile müfredatın son
/// dersi AÇIK bırakılır. Tamamını "tamam" işaretlemek, kullanıcıyı oynayacak
/// tek bir dersi olmadan ana ekrana bırakırdı — testin ödülü boş bir yol
/// haritası olamaz.
List<String> placementUnlocks(int passedRungs) {
  final ids = lessonIdsInFirstTracks(passedRungs);
  final all = lessonIdsInFirstTracks(curriculum.length);
  if (ids.isNotEmpty && ids.length >= all.length) ids.removeLast();
  return ids;
}
