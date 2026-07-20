import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_locale.dart';
import '../../state/settings_controller.dart';
import '../../ui/coach_mark.dart';
import 'home_destinations.dart';
import 'path_map_page.dart';
import 'today_page.dart';

// -----------------------------------------------------------------------------
// ANA EKRAN — sekmeli kabuk
//
// Dört varış: Bugün (tek net eylem + plan) · Yol (tüm müfredat haritası) ·
// Pratik (tekrar/keşif/kalibrasyon) · Profil. Sekmeler push değil IndexedStack
// ile değişir → "neredeyim" her zaman belli, durum korunur.
//
// İlk açılışta (tutorialSeen=false) kısa bir coach-mark turu üstte belirir:
// yeni kullanıcıya nereye basacağını gösterir, sonunda turu görüldü işaretler.
// -----------------------------------------------------------------------------

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;
  final GlobalKey _navKey = GlobalKey(); // coach turu alt sekmeleri spotlar

  static const _pages = [
    TodayPage(),
    PathMapPage(),
    PracticeHubPage(),
    ProfileHubPage(),
  ];

  List<CoachStep> _coachSteps() => [
    CoachStep(
      title: t(en: 'Welcome! I’m Eko', tr: 'Hoş geldin! Ben Eko'),
      body: t(
        en:
            'This is Today — your one clear next step. Tap “Continue” to pick up '
            'your current lesson any time.',
        tr:
            'Burası Bugün — tek net sıradaki adımın. “Devam Et” ile kaldığın '
            'dersi istediğin an açarsın.',
      ),
    ),
    CoachStep(
      title: t(en: 'Your four areas', tr: 'Dört alanın'),
      targetKey: _navKey,
      body: t(
        en:
            'Today (here), Path (the whole map), Practice (endless drills, the '
            'daily challenge, reviews) and Profile.',
        tr:
            'Bugün (burası), Yol (tüm harita), Pratik (sonsuz pratik, günün '
            'meydan okuması, tekrarlar) ve Profil.',
      ),
    ),
    CoachStep(
      title: t(en: 'The ℹ️ teaches the “why”', tr: 'ℹ️ “neden”i anlatır'),
      body: t(
        en:
            'Every lesson has a concept card — tap the info icon to learn what '
            'you’re training and why, before the test.',
        tr:
            'Her dersin bir kavram kartı var — test öncesi neyi neden çalıştığını '
            'öğrenmek için bilgi simgesine dokun.',
      ),
    ),
    CoachStep(
      title: t(en: 'Come back every day', tr: 'Her gün uğra'),
      body: t(
        en:
            'A few minutes daily keeps your streak alive and your ear sharp. '
            'That’s the whole secret. Let’s go!',
        tr:
            'Günde birkaç dakika serini canlı, kulağını keskin tutar. Bütün sır '
            'bu. Hadi başlayalım!',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final showCoach = !ref.watch(settingsProvider).tutorialSeen;

    final scaffold = Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        key: _navKey,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.wb_sunny_outlined),
            selectedIcon: const Icon(Icons.wb_sunny_rounded),
            label: t(en: 'Today', tr: 'Bugün'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: t(en: 'Path', tr: 'Yol'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.headphones_outlined),
            selectedIcon: const Icon(Icons.headphones_rounded),
            label: t(en: 'Practice', tr: 'Pratik'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: t(en: 'Profile', tr: 'Profil'),
          ),
        ],
      ),
    );

    if (!showCoach) return scaffold;

    // İlk açılış turu: kabuğun ÜSTÜNE tam ekran overlay (nav çubuğu dahil kaplar).
    return Stack(
      children: [
        scaffold,
        CoachMarks(
          steps: _coachSteps(),
          onDone: () =>
              ref.read(settingsProvider.notifier).setTutorialSeen(true),
        ),
      ],
    );
  }
}
