import 'dart:math' as math;

/// Pure music-theory helpers (equal temperament, A4 = 440 Hz).
class MusicTheory {
  MusicTheory._();

  static const double a4Frequency = 440.0;
  static const int a4Midi = 69;

  /// Note names using sharps, indexed by pitch class (0 = C).
  static const List<String> sharpNames = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B',
  ];

  /// Labels showing both enharmonic spellings, indexed by pitch class.
  static const List<String> chromaticLabels = [
    'C', 'C♯/D♭', 'D', 'D♯/E♭', 'E', 'F', 'F♯/G♭', 'G', 'G♯/A♭', 'A', 'A♯/B♭', 'B',
  ];

  /// Fractional MIDI note number for [frequency] (69.0 == A4).
  static double midiFromFrequency(double frequency) =>
      a4Midi + 12 * math.log(frequency / a4Frequency) / math.ln2;

  /// Frequency in Hz of a (possibly fractional) MIDI note number.
  static double frequencyFromMidi(num midi) =>
      a4Frequency * math.pow(2, (midi - a4Midi) / 12);

  /// Signed distance in cents from [reference] to [frequency].
  /// Positive = [frequency] is sharp of [reference]. 100 cents = 1 semitone.
  static double centsBetween(double frequency, double reference) =>
      1200 * math.log(frequency / reference) / math.ln2;

  /// Folds a cents value into [-600, +600] by removing whole octaves.
  /// Makes the tuner tolerant of octave errors in pitch detection.
  static double foldCentsToOctave(double cents) =>
      cents - 1200 * (cents / 1200).roundToDouble();

  static int pitchClassOfMidi(int midi) => midi % 12; // Dart % is never negative.

  static int octaveOfMidi(int midi) => (midi / 12).floor() - 1;

  static String noteNameOfMidi(int midi) => sharpNames[pitchClassOfMidi(midi)];

  /// Traditional tempo marking for a BPM value.
  static String tempoName(int bpm) {
    if (bpm < 60) return 'Largo';
    if (bpm < 66) return 'Larghetto';
    if (bpm < 76) return 'Adagio';
    if (bpm < 108) return 'Andante';
    if (bpm < 120) return 'Moderato';
    if (bpm < 156) return 'Allegro';
    if (bpm < 176) return 'Vivace';
    if (bpm < 200) return 'Presto';
    return 'Prestissimo';
  }
}
