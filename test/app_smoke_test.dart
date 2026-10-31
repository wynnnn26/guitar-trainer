import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/app.dart';
import 'package:guitar_trainer/models/tuner_models.dart';
import 'package:guitar_trainer/services/metronome_service.dart';
import 'package:guitar_trainer/services/note_trainer_service.dart';
import 'package:guitar_trainer/services/tuner_service.dart';

import 'helpers/fakes.dart';

/// A destination in the bottom navigation bar (unambiguous even though screens
/// share words with the labels).
Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('three sections; leaving a section pauses it / releases the microphone',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final player = FakeClickPlayer();
    final metronome = MetronomeService(clickPlayer: player);
    final trainer = NoteTrainerService(random: Random(3));
    final mic = FakeMicrophone();
    final tuner = TunerService(microphone: mic, permission: FakePermission());

    await tester.pumpWidget(GuitarTrainerApp(
      metronomeService: metronome,
      trainerService: trainer,
      tunerService: tuner,
    ));
    await tester.pump();

    // Metronome section.
    expect(find.text('80'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(metronome.status, MetronomeStatus.running);
    expect(player.clicks, [true]);

    // Note trainer section: the metronome is paused when we leave it.
    await tester.tap(navItem('Note Trainer'));
    await tester.pump();
    expect(metronome.status, MetronomeStatus.paused);

    await tester.tap(find.text('Start Training'));
    await tester.pump();
    expect(trainer.status, TrainerStatus.running);
    expect(find.text('0/12 notes completed'), findsOneWidget);

    await tester.tap(find.text('Found It / Next Note'));
    await tester.pump();
    expect(find.text('1/12 notes completed'), findsOneWidget);

    // Tuner section: the trainer is paused when we leave it.
    await tester.tap(navItem('Tuner'));
    await tester.pump();
    expect(trainer.status, TrainerStatus.paused);

    await tester.tap(find.text('Start Tuner'));
    await tester.pump();
    await tester.pump();
    expect(tuner.status, TunerStatus.listening);
    expect(mic.active, isTrue);
    expect(find.text('Stop Tuner'), findsOneWidget);

    // Back to the metronome: the microphone is released.
    await tester.tap(navItem('Metronome'));
    await tester.pump();
    await tester.pump();
    expect(tuner.status, TunerStatus.idle);
    expect(mic.active, isFalse);

    // Tear down (cancels all timers).
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide windows (desktop browsers) use a side rail instead of the bottom bar',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final trainer = NoteTrainerService(random: Random(1));
    await tester.pumpWidget(GuitarTrainerApp(
      metronomeService: MetronomeService(clickPlayer: FakeClickPlayer()),
      trainerService: trainer,
      tunerService: TunerService(microphone: FakeMicrophone(), permission: FakePermission()),
    ));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Note Trainer')));
    await tester.pump();
    expect(find.text('Start Training'), findsOneWidget);

    // Narrowing the window switches to the bottom bar without losing state.
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Start Training'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
