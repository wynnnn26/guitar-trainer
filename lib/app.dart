import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/metronome_service.dart';
import 'services/note_trainer_service.dart';
import 'services/tuner_service.dart';
import 'theme/app_theme.dart';

class FretFlowApp extends StatelessWidget {
  const FretFlowApp({
    super.key,
    this.metronomeService,
    this.trainerService,
    this.tunerService,
  });

  /// Optional overrides, mainly for tests.
  final MetronomeService? metronomeService;
  final NoteTrainerService? trainerService;
  final TunerService? tunerService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FretFlow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeShell(
        metronomeService: metronomeService,
        trainerService: trainerService,
        tunerService: tunerService,
      ),
    );
  }
}
