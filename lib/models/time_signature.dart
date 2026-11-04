/// A metronome time signature.
///
/// The metronome clicks once per pulse, and BPM counts those clicks. For x/4
/// signatures a pulse is a quarter note; for x/8 signatures it is an eighth.
class TimeSignature {
  const TimeSignature(this.numerator, this.denominator, {this.groupSize = 1});

  final int numerator;
  final int denominator;

  /// Visual grouping of pulses (6/8 is shown as two groups of three).
  final int groupSize;

  int get pulsesPerMeasure => numerator;
  String get label => '$numerator/$denominator';
  String get pulseDescription => denominator == 8 ? 'eighth-note clicks' : 'quarter-note clicks';

  static const TimeSignature twoFour = TimeSignature(2, 4);
  static const TimeSignature threeFour = TimeSignature(3, 4);
  static const TimeSignature fourFour = TimeSignature(4, 4);
  static const TimeSignature fiveFour = TimeSignature(5, 4);
  static const TimeSignature sixEight = TimeSignature(6, 8, groupSize: 3);
  static const TimeSignature sevenEight = TimeSignature(7, 8);

  static const List<TimeSignature> presets = [
    twoFour,
    threeFour,
    fourFour,
    fiveFour,
    sixEight,
    sevenEight,
  ];

  @override
  bool operator ==(Object other) =>
      other is TimeSignature && other.numerator == numerator && other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => 'TimeSignature($label)';
}
