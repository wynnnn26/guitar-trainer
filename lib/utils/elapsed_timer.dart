/// A monotonic clock returning microseconds. Injectable so tests can use fake time.
typedef MicrosecondClock = int Function();

final Stopwatch _systemStopwatch = Stopwatch()..start();

/// Default clock: monotonic time since the app first touched it.
int systemMicros() => _systemStopwatch.elapsedMicroseconds;

/// A pausable stopwatch built on an injectable clock.
class ElapsedTimer {
  ElapsedTimer({MicrosecondClock? clock}) : _clock = clock ?? systemMicros;

  final MicrosecondClock _clock;
  int _accumulatedMicros = 0;
  int? _startedAtMicros;

  bool get isRunning => _startedAtMicros != null;

  void start() {
    _startedAtMicros ??= _clock();
  }

  void pause() {
    final startedAt = _startedAtMicros;
    if (startedAt == null) return;
    _accumulatedMicros += _clock() - startedAt;
    _startedAtMicros = null;
  }

  void reset() {
    _accumulatedMicros = 0;
    _startedAtMicros = null;
  }

  Duration get elapsed {
    final startedAt = _startedAtMicros;
    final running = startedAt == null ? 0 : _clock() - startedAt;
    return Duration(microseconds: _accumulatedMicros + running);
  }
}
