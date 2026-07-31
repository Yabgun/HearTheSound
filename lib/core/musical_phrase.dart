import 'note.dart';

// -----------------------------------------------------------------------------
// MÜZİKAL CÜMLE — derslerin yeni uyaran birimi
//
// NEDEN VAR: Eski teori egzersizleri izole bir "tonik → hedef" çifti çalıyordu.
// Bu bir laboratuvar uyaranıdır, müzik değildir — ve öğrenilmesi istenen his
// (gerilim, çözülme, "eve varış") tek başına duyulamaz: gerilim ancak ÇÖZÜLDÜĞÜ
// duyulduğunda gerilimdir. Kullanıcı bunun yerine beklenti kuran ve o beklentiyi
// ya karşılayan ya da askıda bırakan KISA BİR CÜMLE duymalı.
//
// Saf model: ses motoru, UI ve dil bilmez (çalma işi audio/phrase_player.dart).
// Derece/akor bilgisi de burada değil — bu katman yalnızca "hangi sesler, hangi
// sırayla, ne kadar" der; müzikal anlamı çağıran taraf kurar.
// -----------------------------------------------------------------------------

/// Cümledeki tek olay: aynı anda duyulan bir ya da daha çok nota.
/// Tek nota = melodi sesi · birden çok nota = akor.
class PhraseEvent {
  /// Aynı anda duyulan notalar. (Dışarıdan değiştirilmemeli.)
  final List<Note> notes;

  /// Göreli süre. Gerçek milisaniye karşılığı çalma katmanındaki tempoya bağlı.
  final int beats;

  const PhraseEvent(this.notes, {this.beats = 1});

  /// Tek sesli olay (melodi notası).
  PhraseEvent.single(Note note, {this.beats = 1}) : notes = [note];

  bool get isChord => notes.length > 1;

  /// En pes nota — akorlarda "bas" sesi; cümlenin nerede bittiğini bu belirler.
  Note get lowest =>
      notes.reduce((a, b) => a.midi <= b.midi ? a : b);

  PhraseEvent transposedBy(int semitones) => PhraseEvent([
    for (final note in notes) Note(note.midi + semitones),
  ], beats: beats);
}

/// Kısa bir müzikal cümle: sıralı olaylar + cümlenin "evi" (tonik).
///
/// Tonik burada saklanır çünkü cümlenin ANLAMI ona görelidir: aynı notalar
/// farklı bir evde tamamen başka bir his verir.
class MusicalPhrase {
  final List<PhraseEvent> events;

  /// Cümlenin merkezi ("ev"). Yalnızca perde sınıfı anlamlıdır; oktav farkı
  /// "eve varış" hissini bozmaz (C4'e de C5'e de inilse ev evdir).
  final Note tonic;

  const MusicalPhrase({required this.events, required this.tonic});

  /// Cümle EVDE mi bitiyor? "Bitti mi?" sorusunun doğru cevabı budur.
  ///
  /// Son olayın en pes notasının perde sınıfına bakar — oktav farkı önemsizdir.
  bool get endsAtHome =>
      events.isNotEmpty &&
      events.last.lowest.pitchClass == tonic.pitchClass;

  /// Cümledeki tüm notalar (ses aralığına sığdırma hesabı için).
  List<Note> get allNotes => [
    for (final event in events)
      for (final note in event.notes) note,
  ];

  int get totalBeats =>
      events.fold(0, (sum, event) => sum + event.beats);

  /// Cümleyi blok halinde taşır — iç ilişkiler (dolayısıyla anlamı) korunur.
  /// Kullanıcının ses aralığına indirmek/çıkarmak için kullanılır.
  MusicalPhrase transposedBy(int semitones) => MusicalPhrase(
    events: [for (final event in events) event.transposedBy(semitones)],
    tonic: Note(tonic.midi + semitones),
  );
}

/// Majör dizide derece → tonikten yarım ses uzaklığı (8 = üst oktav tonik).
///
/// Çekirdekte durur çünkü genel müzik bilgisidir; tek bir track'e ait değildir.
int majorDegreeSemitones(int degree) => switch (degree) {
  1 => 0,
  2 => 2,
  3 => 4,
  4 => 5,
  5 => 7,
  6 => 9,
  7 => 11,
  8 => 12,
  _ => throw ArgumentError('Degree must be 1..8, got $degree'),
};

/// Tonik üstündeki yarım-ses uzaklıklarından TEK SESLİ (melodik) cümle kurar.
///
/// [semitoneOffsets] tonikten uzaklıklardır: 0 = tonik, 7 = beşli, 12 = üst oktav.
///
/// ÖNEMLİ (pedagoji): tüm olaylar VARSAYILAN OLARAK EŞİT SÜREDEDİR. Zıtlık
/// ikilisinde ("bitti" vs "askıda") son notayı uzatmak cazip gelir ama bu
/// kullanıcının perdeyi değil SÜREYİ dinleyerek doğru cevap vermesine yol açar —
/// öğrenmesi gereken ipucunu ortadan kaldırır. Tek fark perde olmalı.
MusicalPhrase melodicPhrase({
  required Note tonic,
  required List<int> semitoneOffsets,
  int beatsPerEvent = 1,
}) => MusicalPhrase(
  events: [
    for (final offset in semitoneOffsets)
      PhraseEvent.single(Note(tonic.midi + offset), beats: beatsPerEvent),
  ],
  tonic: tonic,
);

/// Akor dizisinden cümle kurar (işlev/ilerleme dersleri için).
/// Her iç liste bir akorun aynı anda duyulan notalarıdır.
MusicalPhrase chordPhrase({
  required Note tonic,
  required List<List<Note>> chords,
  int beatsPerEvent = 2,
}) => MusicalPhrase(
  events: [
    for (final chord in chords) PhraseEvent(chord, beats: beatsPerEvent),
  ],
  tonic: tonic,
);
