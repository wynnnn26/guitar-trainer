import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/guitar_string.dart';
import 'package:guitar_trainer/models/tuner_models.dart';
import 'package:guitar_trainer/services/mic_permission_service.dart';
import 'package:guitar_trainer/services/microphone_service.dart';
import 'package:guitar_trainer/services/tuner_service.dart';

import '../helpers/fakes.dart';
import '../helpers/signals.dart';

class Rig {
  Rig({MicPermission permission = MicPermission.granted})
      : mic = FakeMicrophone(),
        perm = FakePermission(permission) {
    tuner = TunerService(microphone: mic, permission: perm, clock: () => now);
  }

  final FakeMicrophone mic;
  final FakePermission perm;
  late final TunerService tuner;
  int now = 1000000;

  /// Delivers a chunk as if it came from the microphone, 100 ms after the last one.
  void emit(Float64List samples) {
    now += 100000;
    mic.emit(samples);
  }
}

const GuitarString lowE = GuitarString(number: 6, midi: 40);

void main() {
  final a2 = GuitarTuning.standard[1];
  final d3 = GuitarTuning.standard[2];
  final e4 = GuitarTuning.standard[5];

  group('permission and lifecycle', () {
    test('asks for permission, opens the microphone and starts listening', () async {
      final rig = Rig();
      expect(rig.tuner.status, TunerStatus.idle);
      await rig.tuner.start();
      expect(rig.perm.requestCount, 1);
      expect(rig.mic.startCount, 1);
      expect(rig.tuner.status, TunerStatus.listening);
      rig.tuner.dispose();
    });

    test('permission denied: friendly state, microphone never opened', () async {
      final rig = Rig(permission: MicPermission.denied);
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.permissionDenied);
      expect(rig.tuner.message, isNotNull);
      expect(rig.tuner.permissionPermanentlyDenied, isFalse);
      expect(rig.mic.startCount, 0);

      // The user can try again after granting it.
      rig.perm.result = MicPermission.granted;
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.listening);
      rig.tuner.dispose();
    });

    test('permanently denied offers the system settings', () async {
      final rig = Rig(permission: MicPermission.permanentlyDenied);
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.permissionDenied);
      expect(rig.tuner.permissionPermanentlyDenied, isTrue);
      await rig.tuner.openSystemSettings();
      expect(rig.perm.settingsOpened, 1);
      rig.tuner.dispose();
    });

    test('a microphone that fails to open becomes an error state, not a crash', () async {
      final rig = Rig();
      rig.mic.startError = Exception('busy');
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.error);
      expect(rig.tuner.message, isNotNull);

      rig.mic.startError = null;
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.listening);
      rig.tuner.dispose();
    });

    test('a refusal reported by the microphone itself (browsers) shows a permission message',
        () async {
      final rig = Rig();
      rig.mic.startError = const MicrophonePermissionException(message: 'Allow it in the address bar.');
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.permissionDenied);
      expect(rig.tuner.message, 'Allow it in the address bar.');
      expect(rig.tuner.permissionPermanentlyDenied, isFalse);

      rig.mic.startError = null; // the user allowed it in the browser
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.listening);
      rig.tuner.dispose();
    });

    test('an unavailable microphone shows its explanation', () async {
      final rig = Rig();
      rig.mic.startError = const MicrophoneUnavailableException('No microphone was found.');
      await rig.tuner.start();
      expect(rig.tuner.status, TunerStatus.error);
      expect(rig.tuner.message, 'No microphone was found.');
      rig.tuner.dispose();
    });

    test('a stream error while listening is reported and releases the microphone', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.mic.emitError(Exception('device lost'));
      await Future<void>.delayed(Duration.zero);
      expect(rig.tuner.status, TunerStatus.error);
      expect(rig.mic.active, isFalse);
      rig.tuner.dispose();
    });

    test('stop releases the microphone and ignores any further samples', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency));
      expect(rig.tuner.reading, isNotNull);

      await rig.tuner.stop();
      expect(rig.tuner.status, TunerStatus.idle);
      expect(rig.mic.active, isFalse);
      expect(rig.mic.stopCount, greaterThan(0));
      expect(rig.tuner.reading, isNull);

      rig.emit(synthTone(a2.frequency));
      expect(rig.tuner.reading, isNull);
      rig.tuner.dispose();
    });

    test('leaving while the microphone is still opening does not leave it on', () async {
      final rig = Rig();
      final starting = rig.tuner.start();
      await rig.tuner.stop();
      await starting;
      expect(rig.tuner.status, TunerStatus.idle);
      rig.tuner.dispose();
    });

    test('dispose releases the microphone', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.tuner.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(rig.mic.active, isFalse);
    });
  });

  group('pitch readings from microphone audio', () {
    test('open A string, auto mode: note, octave, frequency and in tune', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency));

      final reading = rig.tuner.reading!;
      expect(reading.noteName, 'A');
      expect(reading.octave, 2);
      expect(reading.frequency, closeTo(110.0, 0.5));
      expect(reading.targetString, a2);
      expect(reading.cents.abs(), lessThan(1));
      expect(reading.direction, TuneDirection.inTune);
      expect(rig.tuner.signal, SignalQuality.good);
      rig.tuner.dispose();
    });

    test('uses the real sample rate: 48 kHz (typical for browsers) reads correctly', () async {
      final rig = Rig();
      rig.mic.rate = 48000;
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency, sampleRate: 48000, length: 8192));

      final reading = rig.tuner.reading!;
      expect(reading.noteName, 'A');
      expect(reading.octave, 2);
      expect(reading.frequency, closeTo(110.0, 0.3));
      expect(reading.direction, TuneDirection.inTune);
      rig.tuner.dispose();
    });

    test('a flat string is still flat at 48 kHz', () async {
      final rig = Rig();
      rig.mic.rate = 48000;
      await rig.tuner.start();
      rig.emit(synthTone(detune(d3.frequency, -30), sampleRate: 48000, length: 8192));

      final reading = rig.tuner.reading!;
      expect(reading.cents, closeTo(-30, 1));
      expect(reading.direction, TuneDirection.tuneUp);
      rig.tuner.dispose();
    });

    test('a new session picks up a different sample rate', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency));
      expect(rig.tuner.reading!.direction, TuneDirection.inTune);
      await rig.tuner.stop();

      rig.mic.rate = 48000;
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency, sampleRate: 48000, length: 8192));
      expect(rig.tuner.reading!.direction, TuneDirection.inTune);
      rig.tuner.dispose();
    });

    test('flat string says Tune Up with a negative cents value', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(detune(d3.frequency, -30)));

      final reading = rig.tuner.reading!;
      expect(reading.targetString, d3);
      expect(reading.cents, closeTo(-30, 1));
      expect(reading.direction, TuneDirection.tuneUp);
      rig.tuner.dispose();
    });

    test('sharp string says Tune Down with a positive cents value', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.tuner.selectString(e4);
      rig.emit(synthTone(detune(e4.frequency, 25)));

      final reading = rig.tuner.reading!;
      expect(reading.cents, closeTo(25, 1));
      expect(reading.direction, TuneDirection.tuneDown);
      rig.tuner.dispose();
    });

    test('within 5 cents counts as in tune', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(detune(a2.frequency, 4)));
      expect(rig.tuner.reading!.direction, TuneDirection.inTune);
      rig.tuner.dispose();
    });

    test('manual mode compares against the selected string and flags a wrong string', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.tuner.selectString(d3);
      rig.emit(synthTone(a2.frequency)); // playing A while D is selected

      final reading = rig.tuner.reading!;
      expect(reading.targetString, d3);
      expect(reading.noteName, 'A');
      expect(reading.farFromTarget, isTrue);
      expect(reading.direction, TuneDirection.tuneUp);
      rig.tuner.dispose();
    });

    test('auto mode distinguishes the low E and high E strings', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(lowE.frequency));
      expect(rig.tuner.reading!.targetString, lowE);

      await rig.tuner.stop();
      await rig.tuner.start();
      rig.emit(synthTone(e4.frequency));
      expect(rig.tuner.reading!.targetString, e4);
      rig.tuner.dispose();
    });

    test('a very quiet signal gives no reading and a "weak" hint', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency, amplitude: 0.002));
      expect(rig.tuner.reading, isNull);
      expect(rig.tuner.signal, SignalQuality.weak);
      rig.tuner.dispose();
    });

    test('background noise does not produce a note', () async {
      final rig = Rig();
      await rig.tuner.start();
      for (var seed = 0; seed < 5; seed++) {
        rig.emit(synthNoise(0.1, seed: seed));
      }
      expect(rig.tuner.reading, isNull);
      expect(rig.tuner.signal, SignalQuality.unclear);
      rig.tuner.dispose();
    });

    test('the last reading is held briefly after the sound dies away, then cleared', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency));
      expect(rig.tuner.reading, isNotNull);

      rig.now += 200000; // 200 ms of silence: still shown
      rig.mic.emit(Float64List(4096));
      expect(rig.tuner.reading, isNotNull);

      rig.now += 1000000; // 1.2 s of silence: cleared
      rig.mic.emit(Float64List(4096));
      expect(rig.tuner.reading, isNull);
      expect(rig.tuner.signal, SignalQuality.weak);
      rig.tuner.dispose();
    });

    test('small chunks are accumulated into a full analysis frame', () async {
      final rig = Rig();
      await rig.tuner.start();
      final tone = synthTone(a2.frequency, length: 8192);
      for (var offset = 0; offset < 8192; offset += 1024) {
        rig.emit(Float64List.sublistView(tone, offset, offset + 1024));
      }
      expect(rig.tuner.reading, isNotNull);
      expect(rig.tuner.reading!.noteName, 'A');
      rig.tuner.dispose();
    });

    test('switching the target string clears the previous reading', () async {
      final rig = Rig();
      await rig.tuner.start();
      rig.emit(synthTone(a2.frequency));
      rig.tuner.selectString(a2);
      expect(rig.tuner.reading, isNull);
      expect(rig.tuner.isAutoMode, isFalse);
      rig.tuner.selectString(null);
      expect(rig.tuner.isAutoMode, isTrue);
      rig.tuner.dispose();
    });
  });
}
