import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_the_sound/audio/note_player.dart';
import 'package:hear_the_sound/core/chord.dart';
import 'package:hear_the_sound/core/note.dart';
import 'package:hear_the_sound/features/chords/chord_arpeggio_page.dart';

class _RecordingPlayer implements NotePlayer {
  List<Note>? lastChord;

  @override
  Future<void> play(Note note) async {}

  @override
  Future<void> playChord(List<Note> notes) async {
    lastChord = List<Note>.from(notes);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('akor söyleme adımı çevrim sırasını korur', (tester) async {
    final player = _RecordingPlayer();
    final chord = Chord(
      Note.fromName('C', 4),
      ChordQuality.major,
      inversion: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChordArpeggioPage(
          chords: [chord],
          player: player,
          onComplete: () {},
        ),
      ),
    );
    await tester.pump();

    expect(player.lastChord?.map((note) => note.midi), [64, 67, 72]);
  });
}
