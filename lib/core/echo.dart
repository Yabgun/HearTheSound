import 'note.dart';

// -----------------------------------------------------------------------------
// EKO — "duyduğunu tekrarla" karşılaştırması
//
// NEDEN VAR: Teori track'lerinin kökten sorunu, kullanıcıya müziği ETİKETLETMESİ
// idi ("bu kaçıncı derece?"). Etiketleme müziği değil, müzik hakkındaki
// kelimeleri ölçer. Gerçek müzisyen duyduğunda ne yapar? SÖYLER ya da ÇALAR.
// Eko oyunu tam olarak budur: uygulama çalar, kullanıcı tekrarlar.
//
// Bu dosya saf karşılaştırmadır: kim çaldı, nasıl girdi, UI ne gösterecek bilmez.
// -----------------------------------------------------------------------------

/// Kullanıcı tekrarını nasıl veriyor?
///
/// İkisi de desteklenir çünkü ortam belirleyicidir: otobüste sesli söylenemez,
/// evde ise sesle üretmek asıl beceridir. Tercih Ayarlar'da saklanır.
enum EchoInputMode {
  /// Ekrandaki nota tuşlarına basarak (her yerde çalışır, doğrulaması kesin).
  tap,

  /// Mikrofona söyleyerek (uygulamanın çekirdek "Duy → Söyle" döngüsü).
  sing,
}

/// Bir tekrar denemesinin hedefle karşılaştırması.
class EchoComparison {
  /// Her pozisyon için doğru mu? Uzunluğu hedefin uzunluğu kadardır; kullanıcı
  /// eksik nota verdiyse kalanlar `false` sayılır.
  final List<bool> matches;

  const EchoComparison(this.matches);

  int get correctCount => matches.where((m) => m).length;

  int get length => matches.length;

  bool get isPerfect => matches.isNotEmpty && matches.every((m) => m);

  double get accuracy => matches.isEmpty ? 0 : correctCount / matches.length;

  /// İlk hatanın indisi (yoksa null) — "buraya kadar doğruydun" geri bildirimi.
  int? get firstMistakeIndex {
    final index = matches.indexOf(false);
    return index < 0 ? null : index;
  }
}

/// Kullanıcının tekrarını hedefle POZİSYON POZİSYON karşılaştırır.
///
/// [octaveTolerant] SÖYLEME modu içindir: kullanıcı ezgiyi kendi ses aralığında
/// söyler. Önemli olan doğru perdeyi (nota adını) tutturmasıdır, uygulamanın
/// çaldığı oktavı taklit etmesi değil — kadın/erkek ses farkı yüzünden zaten
/// çoğu zaman mümkün olmaz. Tuş modunda ise oktav birebir aynıdır.
EchoComparison compareEcho({
  required List<Note> target,
  required List<Note> attempt,
  bool octaveTolerant = false,
}) {
  return EchoComparison([
    for (var i = 0; i < target.length; i++)
      if (i >= attempt.length)
        false
      else
        octaveTolerant
            ? attempt[i].pitchClass == target[i].pitchClass
            : attempt[i].midi == target[i].midi,
  ]);
}

/// Söyleme modunda tek bir notanın kabul edilip edilmeyeceği.
///
/// Perde tespiti sürekli bir değer verir; "doğru" saymak için hem doğru perde
/// sınıfı hem makul bir akort yakınlığı (varsayılan ±50 cent = PitchMeter'ın
/// yeşil bölgesi) aranır. Böylece ekranda gördüğü geri bildirimle puanlama
/// birbirini tutar.
bool isSungNoteAccepted({
  required NoteReading reading,
  required Note target,
  double toleranceCents = 50,
}) =>
    reading.note.pitchClass == target.pitchClass &&
    reading.cents.abs() <= toleranceCents;
