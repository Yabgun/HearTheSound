import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/core/confusion.dart';
import 'package:hear_the_sound/core/player_progress.dart';
import 'package:hear_the_sound/core/spaced_repetition.dart';

void main() {
  group('topConfusions', () {
    test('sayaca göre çoktan aza sıralar ve limit uygular', () {
      final top = topConfusions({
        'note:C>E': 3,
        'quality:major7>dominant7': 5,
        'interval:4>3': 1,
        'degree:3>5': 2,
      }, limit: 3);

      expect(top.length, 3);
      expect(top[0].type, 'quality');
      expect(top[0].expected, 'major7');
      expect(top[0].chosen, 'dominant7');
      expect(top[0].count, 5);
      expect(top[1].count, 3);
      expect(top[2].count, 2);
    });

    test('bozuk anahtarları sessizce atlar', () {
      final top = topConfusions({'bozukanahtar': 9, 'note:C>E': 1, ':>x': 4});
      expect(top.length, 1);
      expect(top.single.type, 'note');
    });

    test('eşit sayıda deterministik (alfabetik) sıralar', () {
      final a = topConfusions({'note:C>E': 2, 'note:A>B': 2});
      final b = topConfusions({'note:A>B': 2, 'note:C>E': 2});
      expect(a.first.expected, 'A');
      expect([for (final e in a) e.expected], [for (final e in b) e.expected]);
    });
  });

  group('PlayerProgress.confusionCounts', () {
    test('serileştirme gidiş-dönüşünde korunur', () {
      const p = PlayerProgress(
        xp: 10,
        confusionCounts: {'note:C>E': 3, 'inv:1>2': 1},
      );
      final round = PlayerProgress.fromJson(p.toJson());
      expect(round.confusionCounts, p.confusionCounts);
    });

    test('eski kayıtlar (alan yok) boş sayaçla açılır', () {
      final p = PlayerProgress.fromMap({'xp': 5});
      expect(p.confusionCounts, isEmpty);
    });
  });

  group('dueReviewSkills — lapses önceliği', () {
    ReviewState due({required int lapses}) => ReviewState(
      ease: 2.5,
      intervalDays: 1,
      reps: 1,
      lapses: lapses,
      dueDay: '2026-07-01',
      lastReviewedDay: '2026-06-30',
    );

    test('en çok unutulan beceri önce gelir', () {
      final p = PlayerProgress(
        reviews: {
          'kolay': due(lapses: 0),
          'zor': due(lapses: 4),
          'orta': due(lapses: 2),
        },
      );
      expect(p.dueReviewSkills('2026-07-18'), ['zor', 'orta', 'kolay']);
    });
  });
}
