import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/time_signature.dart';
import '../utils/elapsed_timer.dart';
import 'click_player.dart';

enum MetronomeStatus { stopped, running, paused }

/// Metronome engine (no UI code).
///
/// Timing: every beat is scheduled against an absolute target time on a
/// monotonic clock, not "one interval after the previous callback". Timer
/// jitter therefore never accumulates into tempo drift. Exactly one [Timer]
/// exists while running, and it is cancelled before any new one is created,
/// so timers can never stack up.
class MetronomeService extends ChangeNotifier {
  MetronomeService({
    required ClickPlayer clickPlayer,
    MicrosecondClock? clock,
  })  : _player = clickPlayer,
        _clock = clock ?? systemMicros;

  static const int minBpm = 30;
  static const int maxBpm = 300;
  static const int defaultBpm = 80;

  final ClickPlayer _player;
  final MicrosecondClock _clock;

  Timer? _timer;
  int _bpm = defaultBpm;
  TimeSignature _signature = TimeSignature.fourFour;
  MetronomeStatus _status = MetronomeStatus.stopped;

  /// Index of the beat that was clicked last (-1 = none yet).
  int _beatIndex = -1;

  /// Increments with every click so the UI can trigger a pulse animation.
  int _pulseCount = 0;

  int _lastBeatMicros = 0;
  int _nextBeatMicros = 0;

  bool _audioReady = false;
  String? _audioError;
  bool _disposed = false;

  int get bpm => _bpm;
  TimeSignature get timeSignature => _signature;
  MetronomeStatus get status => _status;
  bool get isRunning => _status == MetronomeStatus.running;
  int get currentBeat => _beatIndex;
  int get pulseCount => _pulseCount;
  bool get audioReady => _audioReady;
  String? get audioError => _audioError;

  /// Time between clicks at the current tempo.
  Duration get beatInterval => Duration(microseconds: _beatIntervalMicros);

  int get _beatIntervalMicros => (60000000 / _bpm).round();

  /// Loads the click sounds. The metronome still works visually if this fails.
  Future<void> init() async {
    _player.onError = (error) {
      _audioError = 'Click sound problem: $error';
      _notify();
    };
    try {
      await _player.init();
      _audioReady = true;
      _audioError = null;
    } catch (error) {
      _audioReady = false;
      _audioError = 'Could not load the click sound ($error). '
          'The visual beat indicator will still work.';
    }
    _notify();
  }

  /// Starts from the first beat, or continues when paused.
  void start() {
    if (_disposed || _status == MetronomeStatus.running) return;
    _cancelTimer();
    if (_status == MetronomeStatus.stopped) _beatIndex = -1;
    _status = MetronomeStatus.running;
    _nextBeatMicros = _clock();
    _fireBeat(); // Click right away, then schedule the next one.
  }

  void pause() {
    if (_status != MetronomeStatus.running) return;
    _cancelTimer();
    _status = MetronomeStatus.paused;
    _notify();
  }

  void resume() => start();

  /// Pauses if running (used when the user leaves the screen or the app).
  void pauseIfRunning() => pause();

  /// Stops and restores the defaults (80 BPM, 4/4, back to beat one).
  void reset() {
    _cancelTimer();
    _status = MetronomeStatus.stopped;
    _bpm = defaultBpm;
    _signature = TimeSignature.fourFour;
    _beatIndex = -1;
    _notify();
  }

  void setBpm(int value) {
    final next = math.min(maxBpm, math.max(minBpm, value));
    if (next == _bpm) return;
    _bpm = next;
    if (_status == MetronomeStatus.running) {
      // Re-time the pending beat relative to the last one so the new tempo
      // takes effect immediately and no extra timer is created.
      _nextBeatMicros = math.max(_lastBeatMicros + _beatIntervalMicros, _clock());
      _scheduleNext();
    }
    _notify();
  }

  void increaseBpm([int step = 1]) => setBpm(_bpm + step);
  void decreaseBpm([int step = 1]) => setBpm(_bpm - step);

  void setTimeSignature(TimeSignature signature) {
    if (signature == _signature) return;
    _signature = signature;
    // The next click becomes the downbeat of a fresh measure.
    _beatIndex = -1;
    _notify();
  }

  void _fireBeat() {
    _timer = null;
    if (_disposed || _status != MetronomeStatus.running) return;

    _beatIndex = (_beatIndex + 1) % _signature.pulsesPerMeasure;
    _player.play(accent: _beatIndex == 0); // Audio first: it is the timing-critical part.
    _pulseCount++;

    final interval = _beatIntervalMicros;
    _lastBeatMicros = _nextBeatMicros;
    _nextBeatMicros = _lastBeatMicros + interval;

    // If the app was starved for more than a whole beat, resynchronise
    // instead of firing a burst of catch-up clicks.
    if (_clock() - _nextBeatMicros > interval) {
      _nextBeatMicros = _clock();
    }

    _notify();
    _scheduleNext();
  }

  void _scheduleNext() {
    _cancelTimer();
    if (_disposed || _status != MetronomeStatus.running) return;
    final delay = math.max(0, _nextBeatMicros - _clock());
    _timer = Timer(Duration(microseconds: delay), _fireBeat);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimer();
    unawaited(_player.dispose());
    super.dispose();
  }
}
