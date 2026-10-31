import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/guitar_string.dart';
import 'package:guitar_trainer/services/note_trainer_service.dart';

/// Runs [body] with a trainer driven by fake time and a seeded Random.
void withTrainer(
  void Function(FakeAsync async, NoteTrainerService trainer) body, {
  int seed = 42,
}) {
  fakeAsync((async) {
    final trainer = NoteTrainerService(
      random: Random(seed),
      clock: () => async.elapsed.inMicroseconds,
    );
    body(async, trainer);
    trainer.dispose();
  });
}

void main() {
  test('starts idle with nothing selected', () {
    withTrainer((async, trainer) {
      expect(trainer.status, TrainerStatus.idle);
      expect(trainer.current, isNull);
      expect(trainer.completedCount, 0);
      expect(trainer.elapsed, Duration.zero);
    });
  });

  test('start picks a note on one of the six standard strings and starts the clock', () {
    withTrainer((async, trainer) {
      trainer.start();
      expect(trainer.status, TrainerStatus.running);
      final target = trainer.current!;
      expect(target.pitchClass, inInclusiveRange(0, 11));
      expect(GuitarTuning.standard, contains(target.string));

      async.elapse(const Duration(seconds: 2));
      expect(trainer.elapsed, const Duration(seconds: 2));
    });
  });

  test('a note is only completed when the player confirms it', () {
    withTrainer((async, trainer) {
      trainer.start();
      final first = trainer.current;
      async.elapse(const Duration(seconds: 30));
      expect(trainer.completedCount, 0);
      expect(trainer.current, same(first));

      trainer.confirmFound();
      expect(trainer.completedCount, 1);
      expect(trainer.current, isNot(same(first)));
    });
  });

  test('a full session covers all 12 notes exactly once', () {
    for (var seed = 0; seed < 25; seed++) {
      withTrainer((async, trainer) {
        trainer.start();
        final notes = <int>[];
        final strings = <int>[];
        for (var i = 0; i < 12; i++) {
          final target = trainer.current!;
          notes.add(target.pitchClass);
          strings.add(target.string.number);
          expect(GuitarTuning.standard, contains(target.string));
          async.elapse(const Duration(seconds: 1));
          trainer.confirmFound();
        }
        expect(notes.toSet().length, 12, reason: 'seed $seed: $notes');
        expect(notes.toSet(), {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11});
        // Strings are drawn independently, so a session is not stuck on one string.
        expect(strings.toSet().length, greaterThan(1), reason: 'seed $seed');
        expect(trainer.status, TrainerStatus.completed);
        expect(trainer.current, isNull);
        expect(trainer.progress, 1.0);
      }, seed: seed);
    }
  });

  test('completed list records each note with its string and lap time', () {
    withTrainer((async, trainer) {
      trainer.start();
      for (var i = 0; i < 12; i++) {
        async.elapse(Duration(seconds: i + 1));
        trainer.confirmFound();
      }
      final completed = trainer.completed;
      expect(completed.length, 12);
      for (var i = 0; i < 12; i++) {
        expect(completed[i].lapTime, Duration(seconds: i + 1));
        expect(trainer.isNoteCompleted(completed[i].target.pitchClass), isTrue);
      }
      expect(completed.last.finishedAt, Duration(seconds: 78)); // 1 + 2 + ... + 12
    });
  });

  test('the sequence is shuffled differently for different sessions', () {
    withTrainer((async, trainer) {
      List<int> playSession() {
        trainer.startNewSession();
        final order = <int>[];
        for (var i = 0; i < 12; i++) {
          order.add(trainer.current!.pitchClass);
          trainer.confirmFound();
        }
        return order;
      }

      final first = playSession();
      final second = playSession();
      expect(first.toSet().length, 12);
      expect(second.toSet().length, 12);
      expect(first, isNot(second));
      expect(first, isNot(orderedEquals(List.generate(12, (i) => i))));
    });
  });

  test('the stopwatch stops on the last note and shows the final time', () {
    withTrainer((async, trainer) {
      trainer.start();
      for (var i = 0; i < 12; i++) {
        async.elapse(const Duration(seconds: 1));
        trainer.confirmFound();
      }
      expect(trainer.status, TrainerStatus.completed);
      expect(trainer.elapsed, const Duration(seconds: 12));
      expect(trainer.elapsedListenable.value, const Duration(seconds: 12));

      async.elapse(const Duration(minutes: 5));
      expect(trainer.elapsed, const Duration(seconds: 12));
      expect(async.periodicTimerCount, 0);
    });
  });

  test('confirming after completion or while idle does nothing', () {
    withTrainer((async, trainer) {
      trainer.confirmFound();
      expect(trainer.completedCount, 0);

      trainer.start();
      for (var i = 0; i < 12; i++) {
        trainer.confirmFound();
      }
      trainer.confirmFound();
      expect(trainer.completedCount, 12);
    });
  });

  test('pause freezes time and blocks new targets; resume keeps progress', () {
    withTrainer((async, trainer) {
      trainer.start();
      async.elapse(const Duration(seconds: 3));
      trainer.confirmFound();
      async.elapse(const Duration(seconds: 2));
      final target = trainer.current;

      trainer.pause();
      expect(trainer.status, TrainerStatus.paused);
      expect(trainer.elapsed, const Duration(seconds: 5));
      expect(async.periodicTimerCount, 0);

      async.elapse(const Duration(seconds: 10));
      expect(trainer.elapsed, const Duration(seconds: 5));

      trainer.confirmFound(); // must be ignored while paused
      expect(trainer.completedCount, 1);
      expect(trainer.current, same(target));

      trainer.resume();
      expect(trainer.status, TrainerStatus.running);
      async.elapse(const Duration(seconds: 2));
      expect(trainer.elapsed, const Duration(seconds: 7));
      expect(trainer.completedCount, 1);
      expect(trainer.current, same(target));

      trainer.confirmFound();
      expect(trainer.completedCount, 2);
    });
  });

  test('start while paused resumes instead of starting over', () {
    withTrainer((async, trainer) {
      trainer.start();
      trainer.confirmFound();
      trainer.pause();
      trainer.start();
      expect(trainer.status, TrainerStatus.running);
      expect(trainer.completedCount, 1);
    });
  });

  test('reset clears timer, progress, completed notes and target', () {
    withTrainer((async, trainer) {
      trainer.start();
      async.elapse(const Duration(seconds: 4));
      trainer.confirmFound();
      trainer.confirmFound();

      trainer.reset();
      expect(trainer.status, TrainerStatus.idle);
      expect(trainer.current, isNull);
      expect(trainer.completedCount, 0);
      expect(trainer.completed, isEmpty);
      expect(trainer.progress, 0);
      expect(trainer.elapsed, Duration.zero);
      expect(trainer.elapsedListenable.value, Duration.zero);
      expect(async.periodicTimerCount, 0);
      for (var pc = 0; pc < 12; pc++) {
        expect(trainer.isNoteCompleted(pc), isFalse);
      }
    });
  });

  test('a new session can be started after finishing', () {
    withTrainer((async, trainer) {
      trainer.start();
      for (var i = 0; i < 12; i++) {
        async.elapse(const Duration(seconds: 1));
        trainer.confirmFound();
      }
      trainer.startNewSession();
      expect(trainer.status, TrainerStatus.running);
      expect(trainer.completedCount, 0);
      expect(trainer.current, isNotNull);
      expect(trainer.elapsed, Duration.zero);
      async.elapse(const Duration(seconds: 1));
      expect(trainer.elapsed, const Duration(seconds: 1));
    });
  });

  test('the displayed clock ticks while running', () {
    withTrainer((async, trainer) {
      trainer.start();
      async.elapse(const Duration(seconds: 1));
      expect(trainer.elapsedListenable.value, const Duration(seconds: 1));
      expect(async.periodicTimerCount, 1);
    });
  });
}
