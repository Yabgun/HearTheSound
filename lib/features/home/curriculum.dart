import 'package:flutter/material.dart';

import '../../core/concept.dart';
import '../../core/content_locale.dart';
import '../../core/player_progress.dart';
import '../../ui/app_theme.dart';
import '../chords/chord_lesson.dart';
import '../chords/chord_lesson_flow_page.dart';
import '../function/function_lesson.dart';
import '../function/function_lesson_flow_page.dart';
import '../intervals/interval_lesson.dart';
import '../intervals/interval_lesson_flow_page.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_flow_page.dart';
import '../progression/progression_lesson.dart';
import '../progression/progression_lesson_flow_page.dart';
import '../tonality/tonality_lesson.dart';
import '../tonality/tonality_lesson_flow_page.dart';

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
  Track(
    name: t(en: 'Chords', tr: 'Akorlar'),
    color: AppColors.catChords,
    icon: Icons.piano_rounded,
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
  Track(
    name: t(en: 'Intervals', tr: 'Aralıklar'),
    color: AppColors.catIntervals,
    icon: Icons.straighten_rounded,
    items: [
      for (final l in intervalLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => IntervalLessonFlowPage(lesson: l),
        ),
    ],
  ),
  Track(
    name: t(en: 'Scales & Tonality', tr: 'Diziler ve Tonalite'),
    color: AppColors.catTonality,
    icon: Icons.hub_rounded,
    items: [
      for (final l in tonalityLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => TonalityLessonFlowPage(lesson: l),
        ),
    ],
  ),
  Track(
    name: t(en: 'Chord Function', tr: 'Akor İşlevi'),
    color: AppColors.catFunction,
    icon: Icons.account_tree_rounded,
    unlockAfter: tonalityLessons.last.id,
    items: [
      for (final l in functionLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => FunctionLessonFlowPage(lesson: l),
        ),
    ],
  ),
  Track(
    name: t(en: 'Progressions', tr: 'İlerlemeler'),
    color: AppColors.catProgression,
    icon: Icons.timeline_rounded,
    unlockAfter: functionLessons.last.id,
    items: [
      for (final l in progressionLessons)
        TrackItem(
          id: l.id,
          title: l.title,
          concept: l.concept,
          open: () => ProgressionLessonFlowPage(lesson: l),
        ),
    ],
  ),
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
