import '../utils/music_theory.dart';
import 'guitar_string.dart';

/// A note + string the player has to find.
class TrainingTarget {
  const TrainingTarget({required this.pitchClass, required this.string});

  /// 0 = C ... 11 = B.
  final int pitchClass;
  final GuitarString string;

  /// e.g. `C♯/D♭`.
  String get noteLabel => MusicTheory.chromaticLabels[pitchClass];

  /// The fret on [string] where the note is (0-11).
  int get fret => string.fretFor(pitchClass);

  /// Human readable instruction, e.g. `Find C♯/D♭ on the 3rd string (G)`.
  String get instruction =>
      'Find $noteLabel on the ${string.ordinal} string (${string.noteName})';

  @override
  String toString() => 'TrainingTarget($noteLabel, ${string.ordinal})';
}

/// A target the player confirmed, with timing.
class CompletedTarget {
  const CompletedTarget({
    required this.target,
    required this.lapTime,
    required this.finishedAt,
  });

  final TrainingTarget target;

  /// Time spent on this note only.
  final Duration lapTime;

  /// Stopwatch reading when the note was confirmed.
  final Duration finishedAt;
}
