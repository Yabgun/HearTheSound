import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/data/progress_repository.dart';
import 'package:hear_the_sound/features/lesson/lesson.dart';
import 'package:hear_the_sound/features/lesson/lesson_complete_page.dart';
import 'package:hear_the_sound/state/progress_controller.dart';

// Tamamlama ekranı, geçme barajına (kPassAccuracy) göre kutlama vs. "tekrar dene"
// ayrımını doğru yapmalı — kullanıcı failleyince geçtiğini SANMAMALI.

// Sayfa artık kullanıcının Eko rengini gösterdiği için (PlayerEko) ProviderScope
// gerekiyor; bellek-içi sahte repo ile besliyoruz (SharedPreferences'e girmeden).
class _FakeRepo implements ProgressRepository {
  PlayerProgress _p = PlayerProgress.empty;
  @override
  PlayerProgress load() => _p;
  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}

void main() {
  Widget wrap(LessonResult r) => ProviderScope(
    overrides: [progressRepositoryProvider.overrideWithValue(_FakeRepo())],
    child: MaterialApp(
      home: LessonCompletePage(
        result: r,
        xpEarned: 20,
        streak: 3,
        onDone: () {},
        onReplay: () {},
      ),
    ),
  );

  testWidgets('geçemeyince kutlama değil "tekrar dene" gösterir', (t) async {
    await t.pumpWidget(wrap(const LessonResult(2, 8))); // %25 < %70
    await t.pump();
    expect(find.text('Lesson Complete!'), findsNothing);
    expect(find.text('Almost there!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    await t.pump(const Duration(seconds: 1)); // giriş animasyonları otursun
  });

  testWidgets('geçince kutlama ve Devam gösterir', (t) async {
    await t.pumpWidget(wrap(const LessonResult(7, 8))); // %87 >= %70
    await t.pump();
    expect(find.text('Lesson Complete!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    await t.pump(const Duration(seconds: 3)); // konfeti bitsin (temiz teardown)
  });
}
