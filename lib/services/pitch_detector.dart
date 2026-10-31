import 'dart:math' as math;
import 'dart:typed_data';

/// A detected fundamental frequency.
class PitchEstimate {
  const PitchEstimate({required this.frequency, required this.clarity});

  /// Fundamental frequency in Hz.
  final double frequency;

  /// 0..1; how periodic the signal is (1 = perfectly periodic).
  final double clarity;
}

/// Monophonic pitch detector using the YIN algorithm
/// (de Cheveigné & Kawahara, 2002).
///
/// Pure Dart, no plugins. Works on a frame of mono samples in [-1, 1]:
///  1. difference function  d(tau) = sum (x[j] - x[j+tau])^2
///  2. cumulative mean normalised difference  d'(tau)
///  3. first dip below an absolute threshold, walked down to its minimum
///  4. parabolic interpolation for sub-sample (sub-cent) accuracy
class YinPitchDetector {
  YinPitchDetector({
    required this.sampleRate,
    this.minFrequency = 60,
    this.maxFrequency = 1000,
    this.threshold = 0.15,
    this.windowSize = 2048,
  })  : _tauMin = math.max(2, (sampleRate / maxFrequency).floor()),
        _tauMax = (sampleRate / minFrequency).ceil() {
    _diff = Float64List(_tauMax + 1);
    _cmnd = Float64List(_tauMax + 1);
  }

  final int sampleRate;
  final double minFrequency;
  final double maxFrequency;

  /// Lower = stricter. 0.10-0.20 is the usual range.
  final double threshold;

  /// Number of samples compared for every lag.
  final int windowSize;

  final int _tauMin;
  final int _tauMax;
  late final Float64List _diff;
  late final Float64List _cmnd;

  /// Minimum number of samples [detect] needs.
  int get requiredSamples => windowSize + _tauMax + 1;

  /// Returns the pitch of the last [requiredSamples] samples, or `null` when
  /// the signal is silent / not periodic enough.
  PitchEstimate? detect(Float64List samples) {
    final needed = requiredSamples;
    if (samples.length < needed) return null;
    final offset = samples.length - needed;
    final w = windowSize;

    // 1. Difference function.
    _diff[0] = 0;
    for (var tau = 1; tau <= _tauMax; tau++) {
      var sum = 0.0;
      for (var j = 0; j < w; j++) {
        final delta = samples[offset + j] - samples[offset + j + tau];
        sum += delta * delta;
      }
      _diff[tau] = sum;
    }

    // 2. Cumulative mean normalised difference.
    _cmnd[0] = 1.0;
    var running = 0.0;
    for (var tau = 1; tau <= _tauMax; tau++) {
      running += _diff[tau];
      _cmnd[tau] = running == 0 ? 1.0 : _diff[tau] * tau / running;
    }

    // 3. Absolute threshold: first dip below it, then follow it to its bottom.
    var estimate = -1;
    var tau = _tauMin;
    while (tau < _tauMax) {
      if (_cmnd[tau] < threshold) {
        while (tau + 1 < _tauMax && _cmnd[tau + 1] < _cmnd[tau]) {
          tau++;
        }
        estimate = tau;
        break;
      }
      tau++;
    }
    if (estimate < 0) return null;

    // 4. Parabolic interpolation around the minimum.
    final s0 = _cmnd[estimate - 1];
    final s1 = _cmnd[estimate];
    final s2 = _cmnd[estimate + 1];
    final denominator = 2 * (2 * s1 - s2 - s0);
    var refined = estimate.toDouble();
    if (denominator != 0) {
      final shift = (s2 - s0) / denominator;
      if (shift.abs() <= 1) refined += shift;
    }

    return PitchEstimate(
      frequency: sampleRate / refined,
      clarity: (1 - s1).clamp(0.0, 1.0).toDouble(),
    );
  }
}
