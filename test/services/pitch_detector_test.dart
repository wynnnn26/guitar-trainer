import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/guitar_string.dart';
import 'package:guitar_trainer/services/pitch_detector.dart';
import 'package:guitar_trainer/utils/music_theory.dart';

import '../helpers/signals.dart';

void main() {
  late YinPitchDetector detector;

  setUp(() => detector = YinPitchDetector(sampleRate: 44100));

  group('YinPitchDetector', () {
    test('finds every open string of standard tuning within 1 cent', () {
      for (final string in GuitarTuning.standard) {
        final estimate = detector.detect(synthTone(string.frequency));
        expect(estimate, isNotNull, reason: string.label);
        final error = MusicTheory.centsBetween(estimate!.frequency, string.frequency);
        expect(error.abs(), lessThan(1.0), reason: '${string.label} was off by $error cents');
        expect(estimate.clarity, greaterThan(0.9));
      }
    });

    test('reports flat and sharp strings with the correct sign', () {
      final target = GuitarTuning.standard[1].frequency; // A2
      for (final offset in [-30.0, -12.0, 12.0, 25.0]) {
        final estimate = detector.detect(synthTone(detune(target, offset)))!;
        final measured = MusicTheory.centsBetween(estimate.frequency, target);
        expect(measured, closeTo(offset, 1.0));
      }
    });

    test('still locks on when the fundamental is weak (small phone speakers/mics)', () {
      final target = GuitarTuning.standard[0].frequency; // E2
      final estimate = detector.detect(
        synthTone(target, harmonics: const [0.25, 1.0, 0.7, 0.4, 0.2]),
      );
      expect(estimate, isNotNull);
      expect(MusicTheory.centsBetween(estimate!.frequency, target).abs(), lessThan(2.0));
    });

    test('returns null for silence', () {
      expect(detector.detect(Float64List(detector.requiredSamples + 100)), isNull);
    });

    test('returns null for white noise', () {
      for (var seed = 0; seed < 10; seed++) {
        final result = detector.detect(synthNoise(0.1, seed: seed));
        expect(result == null || result.clarity < 0.8, isTrue, reason: 'seed $seed');
      }
    });

    test('returns null when there are not enough samples', () {
      expect(detector.detect(Float64List(detector.requiredSamples - 1)), isNull);
    });
  });
}
