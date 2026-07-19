import 'package:flutter/material.dart';

import '../../core/content_locale.dart';
import 'home_destinations.dart';
import 'path_map_page.dart';
import 'today_page.dart';

// -----------------------------------------------------------------------------
// ANA EKRAN — sekmeli kabuk
//
// Dört varış: Bugün (tek net eylem + plan) · Yol (tüm müfredat haritası) ·
// Pratik (tekrar/keşif/kalibrasyon) · Profil. Sekmeler push değil IndexedStack
// ile değişir → "neredeyim" her zaman belli, durum korunur.
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = [
    TodayPage(),
    PathMapPage(),
    PracticeHubPage(),
    ProfileHubPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
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
  }
}
