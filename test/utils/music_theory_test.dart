import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/guitar_string.dart';
import 'package:guitar_trainer/utils/formatters.dart';
import 'package:guitar_trainer/utils/music_theory.dart';

void main() {
  group('standard tuning', () {
    test('open string frequencies match the spec', () {
      const expected = {6: 82.41, 5: 110.00, 4: 146.83, 3: 196.00, 2: 246.94, 1: 329.63};
      for (final string in GuitarTuning.standard) {
        expect(string.frequency, closeTo(expected[string.number]!, 0.01), reason: string.label);
      }
    });

    test('labels and order run from the 6th to the 1st string', () {
      expect(GuitarTuning.standard.map((s) => s.label), ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']);
      expect(GuitarTuning.standard.map((s) => s.number), [6, 5, 4, 3, 2, 1]);
      expect(GuitarTuning.standard.map((s) => s.ordinal), ['6th', '5th', '4th', '3rd', '2nd', '1st']);
    });

    test('fret positions follow chromatic theory', () {
      final lowE = GuitarTuning.standard[0];
      final g = GuitarTuning.standard[3];
      final b = GuitarTuning.standard[4];
      expect(lowE.fretFor(4), 0); // E on the low E string: open
      expect(lowE.fretFor(5), 1); // F
      expect(lowE.fretFor(0), 8); // C
      expect(g.fretFor(1), 6); // C♯ on the G string
      expect(b.fretFor(0), 1); // C on the B string
      expect(b.fretFor(10), 11); // A♯ on the B string
    });

    test('every note is reachable on every string within 12 frets', () {
      for (final string in GuitarTuning.standard) {
        for (var pc = 0; pc < 12; pc++) {
          final fret = string.fretFor(pc);
          expect(fret, inInclusiveRange(0, 11));
          expect((string.pitchClass + fret) % 12, pc);
        }
      }
    });
  });

  group('MusicTheory', () {
    test('A4 is MIDI 69 and 440 Hz', () {
      expect(MusicTheory.midiFromFrequency(440), closeTo(69, 1e-9));
      expect(MusicTheory.frequencyFromMidi(69), closeTo(440, 1e-9));
    });

    test('100 cents is one semitone', () {
      expect(MusicTheory.centsBetween(466.1638, 440), closeTo(100, 0.01));
      expect(MusicTheory.centsBetween(440, 466.1638), closeTo(-100, 0.01));
    });

    test('note names and octaves', () {
      expect(MusicTheory.noteNameOfMidi(61), 'C♯');
      expect(MusicTheory.octaveOfMidi(60), 4);
      expect(MusicTheory.octaveOfMidi(40), 2);
      expect(MusicTheory.noteNameOfMidi(40), 'E');
    });

    test('foldCentsToOctave removes whole octaves', () {
      expect(MusicTheory.foldCentsToOctave(1210), closeTo(10, 1e-9));
      expect(MusicTheory.foldCentsToOctave(-1190), closeTo(10, 1e-9));
      expect(MusicTheory.foldCentsToOctave(-30), closeTo(-30, 1e-9));
      expect(MusicTheory.foldCentsToOctave(0), 0);
    });

    test('the 12 chromatic labels are unique', () {
      expect(MusicTheory.chromaticLabels.toSet().length, 12);
    });
  });

  group('formatters', () {
    test('stopwatch', () {
      expect(formatStopwatch(Duration.zero), '00:00.0');
      expect(formatStopwatch(const Duration(minutes: 1, seconds: 5, milliseconds: 340)), '01:05.3');
    });

    test('cents carry a sign', () {
      expect(formatCents(3.24), '+3.2');
      expect(formatCents(-12), '-12.0');
      expect(formatCents(0.01), '±0.0');
    });
  });
}
