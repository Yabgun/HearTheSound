import 'package:flutter/material.dart';

import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/player_progress.dart';
import '../../ui/app_theme.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../harmony/harmony_lesson.dart';
import '../harmony/harmony_lesson_flow_page.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_flow_page.dart';
import '../melody/melody_lesson.dart';
import '../melody/melody_lesson_flow_page.dart';

// -----------------------------------------------------------------------------
// MÜFREDAT — tüm track'ler ve dersleri TEK, birleşik bir modelde.
//
// Farklı ders tipleri (nota/akor/aralık/tonalite/işlev/ilerleme) burada ortak
// bir [TrackItem] arayüzüne indirgenir: id + başlık + kavram + "aç" fonksiyonu.
// Böylece hem "Devam Et" (sıradaki ders) hem "Yol Haritası" tek kaynaktan beslenir.
// -----------------------------------------------------------------------------

class TrackItem {
  final String id;
  final String title;
  final Concept? concept;
  final Widget Function() open; // dersin akış sayfası
  const TrackItem({
    required this.id,
    required this.title,
    this.concept,
    required this.open,
  });
}

class Track {
  final String name;
  final Color color;
  final IconData icon;

  /// Bu ders id'si tamamlanınca track'in İLK dersi açılır (track'ler arası
  /// bağımlılık). null = baştan açık.
  final String? unlockAfter;
  final List<TrackItem> items;

  const Track({
    required this.name,
    required this.color,
    required this.icon,
    this.unlockAfter,
    required this.items,
  });
}

/// Tüm müfredat, ana ekran sırasıyla (pedagojik/bağımlılık düzeni).
/// Locale-anahtarlı önbellekten döner: dil değişince yeni dilde kurulur
/// (ders listeleri de aynı mekanizmayla dil değiştirir).
final Map<String, List<Track>> _curriculumCache = {};

List<Track> get curriculum =>
    _curriculumCache.putIfAbsent(ContentLocale.code, _buildCurriculum);

// Müfredat tek bir SIRALI zincir (zorluk/bağımlılık düzeni): Notalar → Aralıklar
// → Akorlar → Tonalite → İşlev → İlerlemeler → Yolculuk. Her track bir öncekinin
// SON dersi geçilince açılır → yeni başlayan YALNIZCA Notalar'ı görür, sırayla
// ilerler. (Aralıklar akorların yapı taşı olduğu için Akorlar'dan ÖNCE gelir.)
// Başlangıç noktası seviyeye göre değişir: onboarding'deki seviye seçimi önceki
// track'leri "tamam" işaretler (applyPlacement) → o track'ler açık başlar.
List<Track> _buildCurriculum() => [
  Track(
    name: t(en: 'Notes', tr: 'Notalar'),
    color: AppColors.catNotes,
    icon: Icons.music_note_rounded,
    items: [
      for (final l in lessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => LessonFlowPage(lesson: l),
        ),
    ],
  ),
  // MELODİ KULAĞI — "duyduğun ezgiyi çıkarabilmek".
  // Eski teori track'lerinin yerini alan YETENEK track'i: kullanıcı burada
  // hiçbir şey etiketlemez, Eko'nun çaldığı ezgiyi tekrarlar.
  //
  // AKORLARDAN ÖNCE gelir: doğal öğrenme sırası tek ses → zamanda çok ses
  // (ezgi) → aynı anda çok ses (akor). İnsan önce şarkı söyler, sonra akor duyar.
  Track(
    name: t(en: 'Melody Ear', tr: 'Melodi Kulağı'),
    color: AppColors.catMelody,
    icon: Icons.hearing_rounded,
    unlockAfter: lessons.last.id,
    items: [
      for (final l in melodyLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          open: () => MelodyLessonFlowPage(lesson: l),
        ),
    ],
  ),
  Track(
    name: t(en: 'Chords', tr: 'Akorlar'),
    color: AppColors.catChords,
    icon: Icons.piano_rounded,
    unlockAfter: melodyLessons.last.id,
    items: [
      for (final l in chordLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => ChordLessonFlowPage(lesson: l),
        ),
    ],
  ),
  // ARMONİ KULAĞI — "şarkının akorlarını çıkarabilmek".
  // Kuzey yıldızına en yakın track; omurgası BAS DUYMAKtır. Akorlar'dan SONRA
  // gelir: kullanıcı önce tek bir akorun rengini tanımalı, ancak ondan sonra
  // akorların birbirine göre hareketini (ilerlemeyi) duyabilir.
  Track(
    name: t(en: 'Harmony Ear', tr: 'Armoni Kulağı'),
    color: AppColors.catHarmony,
    icon: Icons.graphic_eq_rounded,
    unlockAfter: chordLessons.last.id,
    items: [
      for (final l in harmonyLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          open: () => HarmonyLessonFlowPage(lesson: l),
        ),
    ],
  ),
  // NOT: "Aralıklar" track'i KALDIRILDI ve dağıtıldı: melodik aralıklar Melodi
  // Kulağı'nda çalışılıyor (isimler orada rozet), harmonik aralıklar ise Armoni
  // Kulağı'nın ilk dersinde ("Kaç Ses?") yaşanıyor. Ayrı bir track olarak
  // "Majör 3'lü / Tam 5'li" ezberletmek kulak eğitimi değil terminoloji
  // sınavıydı.
  //
  // NOT: "Diziler & Tonalite", "Akor İşlevi", "İlerlemeler" ve "Tonalite
  // Yolculuğu" track'leri KALDIRILDI. Dördü de aynı beceriyi (ev neresi) dört
  // ayrı sözlükle tekrar ediyor ve müziği ETİKETLETİYORDU — kullanıcı "neyi
  // neden yaptığını" anlamıyordu. Yerlerini yetenek track'leri aldı: Melodi
  // Kulağı ve Armoni Kulağı ("ev neresi" artık ETİKET değil, kullanıcının
  // BULDUĞU bir ses — bkz. har5).
];

/// Onboarding seviye seçimi için: müfredatın ilk [trackCount] track'indeki TÜM
/// ders kimlikleri. Seçilen seviyede bunlar "tamam" işaretlenir (applyPlacement)
/// → zincir gereği bir sonraki track açık başlar. trackCount 0 → boş (sıfırdan).
List<String> lessonIdsInFirstTracks(int trackCount) => [
  for (var i = 0; i < trackCount && i < curriculum.length; i++)
    for (final it in curriculum[i].items) it.id,
];

bool _trackStartUnlocked(Track t, PlayerProgress p) =>
    t.unlockAfter == null || p.isLessonCompleted(t.unlockAfter!);

/// Bir dersin açık olup olmadığı: tamamlanmışsa açık; ilk dersse track kapısına;
/// değilse bir önceki dersin tamamlanmasına bağlı.
bool itemUnlocked(Track t, int i, PlayerProgress p) {
  if (p.isLessonCompleted(t.items[i].id)) return true;
  if (i == 0) return _trackStartUnlocked(t, p);
  return p.isLessonCompleted(t.items[i - 1].id);
}

/// "Devam Et" hedefi: müfredat sırasında açık ama henüz tamamlanmamış ilk ders.
/// Hepsi tamamsa null.
({Track track, TrackItem item})? nextLesson(PlayerProgress p) {
  for (final t in curriculum) {
    for (var i = 0; i < t.items.length; i++) {
      if (itemUnlocked(t, i, p) && !p.isLessonCompleted(t.items[i].id)) {
        return (track: t, item: t.items[i]);
      }
    }
  }
  return null;
}

/// Toplam ders ve tamamlanan sayısı (ilerleme göstergesi için).
({int total, int done}) curriculumProgress(PlayerProgress p) {
  var total = 0;
  var done = 0;
  for (final t in curriculum) {
    for (final it in t.items) {
      total++;
      if (p.isLessonCompleted(it.id)) done++;
    }
  }
  return (total: total, done: done);
}
