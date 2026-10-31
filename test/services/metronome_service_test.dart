import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/time_signature.dart';
import 'package:guitar_trainer/services/metronome_service.dart';

import '../helpers/fakes.dart';

/// Runs [body] with a metronome driven by fake time.
void withMetronome(
  void Function(FakeAsync async, MetronomeService metronome, FakeClickPlayer player) body,
) {
  fakeAsync((async) {
    final player = FakeClickPlayer();
    final metronome = MetronomeService(
      clickPlayer: player,
      clock: () => async.elapsed.inMicroseconds,
    );
    body(async, metronome, player);
    metronome.dispose();
  });
}

void main() {
  test('starts stopped at 80 BPM in 4/4', () {
    withMetronome((async, metronome, player) {
      expect(metronome.status, MetronomeStatus.stopped);
      expect(metronome.bpm, 80);
      expect(metronome.timeSignature, TimeSignature.fourFour);
      expect(player.clicks, isEmpty);
    });
  });

  test('BPM is clamped to 30-300', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(5);
      expect(metronome.bpm, 30);
      metronome.setBpm(999);
      expect(metronome.bpm, 300);
      metronome.setBpm(100);
      metronome.increaseBpm(5);
      expect(metronome.bpm, 105);
      metronome.decreaseBpm();
      expect(metronome.bpm, 104);
    });
  });

  test('clicks immediately, then once per beat, with an accent on beat one', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(120); // 500 ms
      metronome.start();
      expect(metronome.status, MetronomeStatus.running);
      expect(player.clicks, [true]);

      async.elapse(const Duration(milliseconds: 2900));
      // Clicks at 0, 500, 1000, 1500, 2000, 2500 ms.
      expect(player.clicks, [true, false, false, false, true, false]);
    });
  });

  test('click rate matches the selected BPM', () {
    for (final bpm in [40, 60, 100, 180, 300]) {
      withMetronome((async, metronome, player) {
        metronome.setBpm(bpm);
        metronome.start();
        const window = Duration(microseconds: 9999000); // just under 10 s
        async.elapse(window);

        final interval = (60000000 / bpm).round();
        final expected = window.inMicroseconds ~/ interval + 1; // includes the click at t=0
        expect(player.clicks.length, expected, reason: '$bpm BPM');
        // Roughly bpm/6 clicks per second-10, i.e. the real-world rate.
        expect(player.clicks.length, closeTo(bpm * 10 / 60, 1.5), reason: '$bpm BPM');
      });
    }
  });

  test('changing BPM while running re-times the next beat', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(120);
      metronome.start();
      async.elapse(const Duration(milliseconds: 1200)); // clicks at 0, 500, 1000
      expect(player.clicks.length, 3);

      metronome.setBpm(60); // 1000 ms interval; next beat = 1000 + 1000 = 2000 ms
      async.elapse(const Duration(milliseconds: 700)); // t = 1900
      expect(player.clicks.length, 3);
      async.elapse(const Duration(milliseconds: 200)); // t = 2100
      expect(player.clicks.length, 4);
      async.elapse(const Duration(milliseconds: 1000)); // t = 3100
      expect(player.clicks.length, 5);
    });
  });

  test('never creates more than one timer', () {
    withMetronome((async, metronome, player) {
      metronome.start();
      metronome.start();
      metronome.start();
      expect(async.nonPeriodicTimerCount, 1);
      expect(player.clicks.length, 1);

      for (var bpm = 90; bpm < 140; bpm += 7) {
        metronome.setBpm(bpm);
        expect(async.nonPeriodicTimerCount, 1);
      }
      metronome.setTimeSignature(TimeSignature.threeFour);
      expect(async.nonPeriodicTimerCount, 1);

      metronome.pause();
      expect(async.nonPeriodicTimerCount, 0);
    });
  });

  test('pause stops the clicks and resume continues the measure', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(120);
      metronome.start();
      async.elapse(const Duration(milliseconds: 1200)); // beats 1, 2, 3
      expect(player.clicks.length, 3);

      metronome.pause();
      expect(metronome.status, MetronomeStatus.paused);
      async.elapse(const Duration(seconds: 5));
      expect(player.clicks.length, 3);

      metronome.resume(); // beat 4 right away
      expect(metronome.status, MetronomeStatus.running);
      expect(player.clicks.length, 4);
      expect(player.clicks.last, isFalse);
      async.elapse(const Duration(milliseconds: 500)); // beat 1 of the next measure
      expect(player.clicks.length, 5);
      expect(player.clicks.last, isTrue);
    });
  });

  test('reset stops everything and restores the defaults', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(150);
      metronome.setTimeSignature(TimeSignature.threeFour);
      metronome.start();
      async.elapse(const Duration(seconds: 1));

      metronome.reset();
      expect(metronome.status, MetronomeStatus.stopped);
      expect(metronome.bpm, 80);
      expect(metronome.timeSignature, TimeSignature.fourFour);
      expect(metronome.currentBeat, -1);
      expect(async.nonPeriodicTimerCount, 0);

      final clicksAtReset = player.clicks.length;
      async.elapse(const Duration(seconds: 5));
      expect(player.clicks.length, clicksAtReset);

      metronome.start(); // starts again from beat one
      expect(player.clicks.last, isTrue);
    });
  });

  test('accent follows the time signature (6/8 has six clicks per measure)', () {
    withMetronome((async, metronome, player) {
      metronome.setTimeSignature(TimeSignature.sixEight);
      metronome.setBpm(300); // 200 ms
      metronome.start();
      async.elapse(const Duration(milliseconds: 1500)); // clicks at 0..1400 => 8 clicks
      expect(player.clicks, [true, false, false, false, false, false, true, false]);
    });
  });

  test('3/4 has an accent every third click', () {
    withMetronome((async, metronome, player) {
      metronome.setTimeSignature(TimeSignature.threeFour);
      metronome.setBpm(240); // 250 ms
      metronome.start();
      async.elapse(const Duration(milliseconds: 1600)); // 0..1500 => 7 clicks
      expect(player.clicks, [true, false, false, true, false, false, true]);
    });
  });

  test('changing the time signature restarts the measure on the downbeat', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(120);
      metronome.start();
      async.elapse(const Duration(milliseconds: 600)); // beats 1, 2
      metronome.setTimeSignature(TimeSignature.threeFour);
      async.elapse(const Duration(milliseconds: 500)); // next click
      expect(player.clicks.last, isTrue);
    });
  });

  test('keeps accurate time even if a timer fires late (no drift)', () {
    withMetronome((async, metronome, player) {
      metronome.setBpm(120);
      metronome.start();
      // Elapse in awkward chunks; scheduling is absolute so count stays exact.
      for (var i = 0; i < 100; i++) {
        async.elapse(const Duration(milliseconds: 97));
      }
      // 9700 ms => clicks at 0, 500, ... 9500 => 20 clicks.
      expect(player.clicks.length, 20);
    });
  });

  test('a failing audio backend is reported but does not stop the metronome', () async {
    final player = FakeClickPlayer()..initError = Exception('no audio');
    final metronome = MetronomeService(clickPlayer: player);
    await metronome.init();
    expect(metronome.audioReady, isFalse);
    expect(metronome.audioError, isNotNull);

    metronome.start();
    expect(metronome.status, MetronomeStatus.running);
    metronome.dispose();
  });

  test('dispose cancels the timer and releases audio', () {
    fakeAsync((async) {
      final player = FakeClickPlayer();
      final metronome = MetronomeService(
        clickPlayer: player,
        clock: () => async.elapsed.inMicroseconds,
      );
      metronome.start();
      expect(async.nonPeriodicTimerCount, 1);
      metronome.dispose();
      expect(async.nonPeriodicTimerCount, 0);
      async.flushMicrotasks();
      expect(player.disposed, isTrue);
    });
  });
}
