import 'dart:math' as math;
import 'dart:typed_data';

/// A guitar-like tone: a fundamental plus decreasing harmonics, peak 0.4 * [amplitude] / 0.4.
Float64List synthTone(
  double frequency, {
  int length = 4096,
  int sampleRate = 44100,
  List<double> harmonics = const [1.0, 0.5, 0.3, 0.2],
  double amplitude = 0.4,
}) {
  final samples = Float64List(length);
  var peak = 0.0;
  for (var i = 0; i < length; i++) {
    final t = i / sampleRate;
    var value = 0.0;
    for (var k = 0; k < harmonics.length; k++) {
      value += harmonics[k] * math.sin(2 * math.pi * frequency * (k + 1) * t);
    }
    samples[i] = value;
    peak = math.max(peak, value.abs());
  }
  for (var i = 0; i < length; i++) {
    samples[i] = samples[i] / peak * amplitude;
  }
  return samples;
}

/// Uniform white noise in [-amplitude, amplitude].
Float64List synthNoise(double amplitude, {int length = 4096, int seed = 1}) {
  final random = math.Random(seed);
  final samples = Float64List(length);
  for (var i = 0; i < length; i++) {
    samples[i] = (random.nextDouble() * 2 - 1) * amplitude;
  }
  return samples;
}

/// [frequency] shifted by [cents].
double detune(double frequency, double cents) => frequency * math.pow(2, cents / 1200);
