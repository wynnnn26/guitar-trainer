import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/guitar_string.dart';
import '../models/training.dart';
import '../utils/elapsed_timer.dart';

enum TrainerStatus { idle, running, paused, completed }

/// Note-training session logic (no UI code).
///
/// A session shuffles the 12 chromatic notes once and walks through them in
/// that order. Each note gets an independently random string. A note is only
/// counted after the player calls [confirmFound].
class NoteTrainerService extends ChangeNotifier {
  NoteTrainerService({
    math.Random? random,
    MicrosecondClock? clock,
    this.strings = GuitarTuning.standard,
  })  : _random = random ?? math.Random(),
        _stopwatch = ElapsedTimer(clock: clock);

  static const int noteCount = 12;

  final List<GuitarString> strings;
  final math.Random _random;
  final ElapsedTimer _stopwatch;

  /// Updates ~10x/second while running; lets the UI rebuild only the clock.
  final ValueNotifier<Duration> elapsedListenable = ValueNotifier(Duration.zero);

  Timer? _ticker;
  TrainerStatus _status = TrainerStatus.idle;
  List<int> _remaining = [];
  final List<CompletedTarget> _completed = [];
  TrainingTarget? _current;
  Duration _lastLapEnd = Duration.zero;
  bool _disposed = false;

  TrainerStatus get status => _status;
  TrainingTarget? get current => _current;
  List<CompletedTarget> get completed => List.unmodifiable(_completed);
  int get completedCount => _completed.length;
  double get progress => _completed.length / noteCount;
  Duration get elapsed => _stopwatch.elapsed;

  bool isNoteCompleted(int pitchClass) =>
      _completed.any((c) => c.target.pitchClass == pitchClass);

  /// Starts a new session (or resumes a paused one).
  void start() {
    if (_disposed) return;
    if (_status == TrainerStatus.running) return;
    if (_status == TrainerStatus.paused) {
      resume();
      return;
    }
    _clearSession();
    _remaining = List<int>.generate(noteCount, (i) => i)..shuffle(_random);
    _status = TrainerStatus.running;
    _current = _nextTarget();
    _stopwatch.start();
    _startTicker();
    _publishElapsed();
    _notify();
  }

  void pause() {
    if (_status != TrainerStatus.running) return;
    _stopwatch.pause();
    _cancelTicker();
    _status = TrainerStatus.paused;
    _publishElapsed();
    _notify();
  }

  void resume() {
    if (_status != TrainerStatus.paused) return;
    _stopwatch.start();
    _startTicker();
    _status = TrainerStatus.running;
    _publishElapsed();
    _notify();
  }

  /// Pauses if a session is running (used when leaving the screen / app).
  void pauseIfRunning() => pause();

  /// The player confirms they located the current target.
  void confirmFound() {
    final target = _current;
    if (_status != TrainerStatus.running || target == null) return;

    final isLast = _completed.length + 1 >= noteCount;
    if (isLast) {
      _stopwatch.pause();
      _cancelTicker();
    }
    final now = _stopwatch.elapsed;
    _completed.add(CompletedTarget(
      target: target,
      lapTime: now - _lastLapEnd,
      finishedAt: now,
    ));
    _lastLapEnd = now;

    if (isLast) {
      _current = null;
      _status = TrainerStatus.completed;
    } else {
      _current = _nextTarget();
    }
    _publishElapsed();
    _notify();
  }

  /// Clears the timer, progress, completed notes and current target.
  void reset() {
    _cancelTicker();
    _clearSession();
    _status = TrainerStatus.idle;
    _publishElapsed();
    _notify();
  }

  /// Convenience for the "new session" button after completion.
  void startNewSession() {
    reset();
    start();
  }

  TrainingTarget _nextTarget() {
    final pitchClass = _remaining.removeLast();
    final string = strings[_random.nextInt(strings.length)];
    return TrainingTarget(pitchClass: pitchClass, string: string);
  }

  void _clearSession() {
    _stopwatch.reset();
    _remaining = [];
    _completed.clear();
    _current = null;
    _lastLapEnd = Duration.zero;
  }

  void _startTicker() {
    _cancelTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _publishElapsed());
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _publishElapsed() {
    if (!_disposed) elapsedListenable.value = _stopwatch.elapsed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTicker();
    elapsedListenable.dispose();
    super.dispose();
  }
}
