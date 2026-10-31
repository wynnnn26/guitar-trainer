import 'guitar_string.dart';

enum TunerStatus {
  /// Microphone is off.
  idle,

  /// Waiting for the permission dialog / starting the microphone.
  starting,

  /// Microphone is live and being analysed.
  listening,

  /// The user denied microphone access.
  permissionDenied,

  /// Something went wrong (see [TunerService.message]).
  error,
}

enum TuneDirection { tuneUp, tuneDown, inTune }

/// Why there is currently no pitch to show while listening.
enum SignalQuality {
  /// Nothing analysed yet.
  none,

  /// Input is too quiet.
  weak,

  /// Input is loud enough but no clear pitch was found (noise, chords, ...).
  unclear,

  /// A clear pitch is being tracked.
  good,
}

/// One pitch measurement shown by the tuner.
class TunerReading {
  const TunerReading({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.targetString,
    required this.cents,
    required this.direction,
    required this.farFromTarget,
  });

  /// Detected fundamental frequency in Hz.
  final double frequency;

  /// Nearest chromatic note name (sharps), e.g. `A♯`.
  final String noteName;
  final int octave;

  /// The string this reading is compared against (selected or auto-detected).
  final GuitarString targetString;

  /// Signed offset from the target in cents (negative = flat, positive = sharp),
  /// folded into +/-600 so octave errors do not matter.
  final double cents;

  final TuneDirection direction;

  /// True when the pitch is more than ~2 semitones away from the target,
  /// which usually means the wrong string is selected.
  final bool farFromTarget;

  String get noteLabel => '$noteName$octave';
}
