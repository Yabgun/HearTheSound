import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/progress_repository.dart';
import 'features/home/home_page.dart';
import 'state/progress_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // İlerlemeyi açılışta yükleyebilmek için prefs'i hazırla ve repository'yi ver.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          PrefsProgressRepository(prefs),
        ),
      ],
      child: const HearTheSoundApp(),
    ),
  );
}

class HearTheSoundApp extends StatelessWidget {
  const HearTheSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Marka rengi (amber/altın) çekirdekli koyu tema.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE0912B),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'HearTheSound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
