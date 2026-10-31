import '../utils/music_theory.dart';

/// One string of the guitar, identified by its standard-tuning open note.
class GuitarString {
  const GuitarString({
    required this.number,
    required this.midi,
  });

  /// 1 = thinnest (high E) ... 6 = thickest (low E).
  final int number;

  /// MIDI note number of the open string.
  final int midi;

  int get pitchClass => MusicTheory.pitchClassOfMidi(midi);
  String get noteName => MusicTheory.noteNameOfMidi(midi);
  int get octave => MusicTheory.octaveOfMidi(midi);

  /// Open-string frequency in Hz (equal temperament, A4 = 440 Hz).
  double get frequency => MusicTheory.frequencyFromMidi(midi);

  /// e.g. `E2`.
  String get label => '$noteName$octave';

  /// e.g. `6th`.
  String get ordinal {
    switch (number) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${number}th';
    }
  }

  /// The fret (0-11) at which this string sounds [pitchClass].
  /// Add 12 for the same note one octave higher.
  int fretFor(int targetPitchClass) => (targetPitchClass - pitchClass) % 12;

  @override
  bool operator ==(Object other) => other is GuitarString && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'GuitarString($number, $label)';
}

/// Standard tuning, ordered from the 6th (low E) to the 1st (high E) string.
class GuitarTuning {
  GuitarTuning._();

  static const List<GuitarString> standard = [
    GuitarString(number: 6, midi: 40), // E2  82.41 Hz
    GuitarString(number: 5, midi: 45), // A2 110.00 Hz
    GuitarString(number: 4, midi: 50), // D3 146.83 Hz
    GuitarString(number: 3, midi: 55), // G3 196.00 Hz
    GuitarString(number: 2, midi: 59), // B3 246.94 Hz
    GuitarString(number: 1, midi: 64), // E4 329.63 Hz
  ];
}
