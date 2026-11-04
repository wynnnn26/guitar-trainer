import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/click_sound.dart';
import '../models/time_signature.dart';
import '../utils/elapsed_timer.dart';
import 'click_player.dart';

enum MetronomeStatus { stopped, running, paused }

/// Which metronome UI is active. Only one mode exists at a time, so two
/// metronomes can never click over each other.
enum MetronomeMode {
  /// One identical click per beat: no measures, no accents.
  basic,

  /// Measures, time signatures, per-beat accents and sound settings.
  advanced,
}

/// Metronome engine (no UI code).
///
/// Timing: every beat is scheduled against an absolute target time on a
/// monotonic clock, not "one interval after the previous callback". Timer
/// jitter therefore never accumulates into tempo drift. Exactly one [Timer]
/// exists while running, and it is cancelled before any new one is created,
/// so timers can never stack up.
///
/// [MetronomeMode.basic] and [MetronomeMode.advanced] share this single
/// engine and its clock; switching modes stops playback and restarts the
/// beat count, so modes can never play at the same time.
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
  MetronomeMode _mode = MetronomeMode.advanced;
  ClickSound _sound = ClickSound.classic;
  double _volume = 1.0;

  /// Per-pulse accent pattern for [MetronomeMode.advanced] (index 0 = first
  /// beat of the measure). Read-only for the UI; mutate via [setBeatAccent].
  List<bool> _accentBeats = [true, false, false, false];

  /// Per-pulse mute flags for [MetronomeMode.advanced]. Muted beats keep
  /// their timing slot (the position indicator still advances) but make no
  /// sound. Read-only for the UI; mutate via [setBeatEnabled].
  List<bool> _beatEnabled = [true, true, true, true];

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
  MetronomeMode get mode => _mode;
  ClickSound get sound => _sound;
  double get volume => _volume;
  List<bool> get accentBeats => _accentBeats;
  List<bool> get beatEnabled => _beatEnabled;
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

  /// Stops and restores the tempo / signature / beat defaults. The active
  /// mode, sound set and volume are user preferences and stay as they are.
  void reset() {
    _cancelTimer();
    _status = MetronomeStatus.stopped;
    _bpm = defaultBpm;
    _signature = TimeSignature.fourFour;
    _beatIndex = -1;
    _accentBeats = [true, false, false, false];
    _beatEnabled = [true, true, true, true];
    _notify();
  }

  /// Switches between Basic and Advanced. Playback always stops first, so
  /// the two modes can never click at the same time; the tempo carries over.
  void setMode(MetronomeMode mode) {
    if (mode == _mode) return;
    _cancelTimer();
    _status = MetronomeStatus.stopped;
    _mode = mode;
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
    if (_mode != MetronomeMode.advanced || signature == _signature) return;
    _signature = signature;
    _resizeBeatConfig();
    // The next click becomes the downbeat of a fresh measure.
    _beatIndex = -1;
    _notify();
  }

  /// Accents one pulse of the measure (advanced mode only).
  void setBeatAccent(int beat, bool accent) {
    if (beat < 0 || beat >= _accentBeats.length || _accentBeats[beat] == accent) return;
    _accentBeats[beat] = accent;
    _notify();
  }

  /// Mutes or unmutes one pulse of the measure (advanced mode only).
  /// Muted beats keep their place in the timing, they just make no sound.
  void setBeatEnabled(int beat, bool enabled) {
    if (beat < 0 || beat >= _beatEnabled.length || _beatEnabled[beat] == enabled) return;
    _beatEnabled[beat] = enabled;
    _notify();
  }

  /// Preloads [sound] and uses it for every later click. On failure the old
  /// sound keeps playing and [audioError] explains what happened.
  Future<void> setSound(ClickSound sound) async {
    if (_disposed || sound == _sound) return;
    try {
      await _player.setSound(sound);
      _sound = sound;
      _audioError = null;
    } catch (error) {
      _audioError = 'Could not load the "${sound.label}" click ($error).';
    }
    _notify();
  }

  void setVolume(double value) {
    final next = value.clamp(0.0, 1.0);
    if (next == _volume) return;
    _volume = next;
    _player.setVolume(next);
    _notify();
  }

  /// Dismisses the audio error banner (the next failure reports again).
  void clearAudioError() {
    if (_audioError == null) return;
    _audioError = null;
    _notify();
  }

  void _fireBeat() {
    _timer = null;
    if (_disposed || _status != MetronomeStatus.running) return;

    if (_mode == MetronomeMode.basic) {
      _player.play(accent: false); // Identical click on every beat.
      _beatIndex = -1;
    } else {
      _beatIndex = (_beatIndex + 1) % _signature.pulsesPerMeasure;
      if (_beatEnabled[_beatIndex]) {
        _player.play(accent: _accentBeats[_beatIndex]);
      }
      // Muted beats still pulse so the position indicator keeps its place.
    }
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

  /// Keeps the accent / mute lists the length of the current measure when
  /// the time signature changes (existing customisation is kept).
  void _resizeBeatConfig() {
    final beats = _signature.pulsesPerMeasure;
    _accentBeats = [
      for (var i = 0; i < beats; i++) i < _accentBeats.length ? _accentBeats[i] : i == 0,
    ];
    _beatEnabled = [
      for (var i = 0; i < beats; i++) i < _beatEnabled.length ? _beatEnabled[i] : true,
    ];
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
