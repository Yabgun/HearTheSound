import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/ui/coach_mark.dart';

// §2 İlk-açılış coach-mark turu — adımlar ilerler, Atla/Anladım turu bitirir.

const _steps = [
  CoachStep(title: 'Adım bir', body: 'gövde 1'),
  CoachStep(title: 'Adım iki', body: 'gövde 2'),
];

void main() {
  testWidgets('adımlar ilerler ve son adımda onDone çağrılır', (t) async {
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        home: CoachMarks(steps: _steps, onDone: () => done = true),
      ),
    );
    await t.pump(); // post-frame ölçüm

    expect(find.text('Adım bir'), findsOneWidget);
    expect(find.text('Adım iki'), findsNothing);

    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text('Adım iki'), findsOneWidget);
    expect(done, isFalse);

    await t.tap(find.text('Got it'));
    await t.pump();
    expect(done, isTrue);
  });

  testWidgets('Atla ilk adımda bile turu bitirir', (t) async {
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        home: CoachMarks(steps: _steps, onDone: () => done = true),
      ),
    );
    await t.pump();

    await t.tap(find.text('Skip'));
    await t.pump();
    expect(done, isTrue);
  });
}
