import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/guitar_string.dart';
import '../models/tuner_models.dart';
import '../utils/elapsed_timer.dart';
import '../utils/music_theory.dart';
import 'mic_permission_service.dart';
import 'microphone_service.dart';
import 'pitch_detector.dart';

/// Guitar tuner logic (no UI code).
///
/// Pipeline: microphone PCM chunks -> sliding frame -> DC removal + level gate
/// -> YIN pitch detection -> median filter -> note / cents / direction.
/// Nothing here is simulated: every reading comes from real microphone input.
class TunerService extends ChangeNotifier {
  TunerService({
    required MicrophoneService microphone,
    required MicPermissionService permission,
    MicrosecondClock? clock,
    List<GuitarString> strings = GuitarTuning.standard,
  })  : _mic = microphone,
        _permission = permission,
        _clock = clock ?? systemMicros,
        strings = List.unmodifiable(strings);

  /// Within this many cents of the target counts as "in tune".
  static const double inTuneCents = 5.0;

  /// RMS level below which the input is considered silence / too weak.
  static const double minRms = 0.01;

  /// Minimum YIN clarity (1 - d') to trust a pitch.
  static const double minClarity = 0.80;

  /// Pitches further than this from the target suggest the wrong string.
  static const double farFromTargetCents = 200.0;

  /// Keep the last reading on screen this long after the signal disappears.
  static const int _holdMicros = 700000;

  /// Do not analyse more often than this.
  static const int _minAnalysisIntervalMicros = 40000;

  static const int _medianWindow = 5;

  final List<GuitarString> strings;
  final MicrophoneService _mic;
  final MicPermissionService _permission;
  final MicrosecondClock _clock;

  /// Created after the microphone opened, because browsers pick their own
  /// sample rate (commonly 48 kHz) and pitch maths depend on it.
  YinPitchDetector? _detector;
  Float64List _frame = Float64List(0);
  Float64List _work = Float64List(0);
  int _filled = 0;
  int _lastAnalysisAt = -_minAnalysisIntervalMicros;
  int _lastPitchAt = 0;
  final List<double> _recentFrequencies = [];

  TunerStatus _status = TunerStatus.idle;
  GuitarString? _selectedString; // null = automatic string detection
  TunerReading? _reading;
  SignalQuality _signal = SignalQuality.none;
  String? _message;
  bool _permissionPermanentlyDenied = false;

  /// Incremented whenever start/stop is requested so that a slow `start()`
  /// finishing after the user already left does not turn the mic back on.
  int _session = 0;
  bool _disposed = false;

  TunerStatus get status => _status;
  bool get isListening => _status == TunerStatus.listening;
  GuitarString? get selectedString => _selectedString;
  bool get isAutoMode => _selectedString == null;
  TunerReading? get reading => _reading;
  SignalQuality get signal => _signal;

  /// Error / permission explanation to show to the user.
  String? get message => _message;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;

  /// Turns the tuner on: asks for permission, then opens the microphone.
  Future<void> start() async {
    if (_disposed) return;
    if (_status == TunerStatus.starting || _status == TunerStatus.listening) return;

    final session = ++_session;
    _resetAnalysis();
    _status = TunerStatus.starting;
    _message = null;
    _permissionPermanentlyDenied = false;
    _notify();

    final MicPermission permission;
    try {
      permission = await _permission.request();
    } catch (_) {
      if (_isStale(session)) return;
      _fail('Could not ask for microphone permission. Please try again.');
      return;
    }
    if (_isStale(session)) return;

    if (permission != MicPermission.granted) {
      _showPermissionDenied(permanent: permission == MicPermission.permanentlyDenied);
      return;
    }

    try {
      await _mic.start(onSamples: _onSamples, onError: _onMicrophoneError);
    } on MicrophonePermissionException catch (error) {
      // Browsers report a refusal here, when getUserMedia is called.
      if (_isStale(session)) return;
      _showPermissionDenied(permanent: error.permanent, message: error.message);
      return;
    } on MicrophoneUnavailableException catch (error) {
      if (_isStale(session)) return;
      _fail(error.message);
      return;
    } catch (_) {
      if (_isStale(session)) return; // stop() already released the microphone.
      _fail('Could not open the microphone. Another app may be using it.');
      return;
    }
    // If stop()/dispose() ran while the microphone was opening, they already
    // released it (and the microphone services release late starters themselves).
    if (_isStale(session)) return;

    _prepareAnalysis(_mic.sampleRate);
    _status = TunerStatus.listening;
    _signal = SignalQuality.none;
    _notify();
  }

  void _showPermissionDenied({required bool permanent, String? message}) {
    _permissionPermanentlyDenied = permanent;
    _status = TunerStatus.permissionDenied;
    _message = message ??
        (permanent
            ? 'Microphone access is blocked. Enable it for this app in your '
                'device settings to use the tuner.'
            : 'Microphone permission was denied. The tuner needs the microphone '
                'to hear your guitar.');
    _notify();
  }

  void _prepareAnalysis(int sampleRate) {
    final existing = _detector;
    if (existing == null || existing.sampleRate != sampleRate) {
      final detector = YinPitchDetector(sampleRate: sampleRate);
      _detector = detector;
      _frame = Float64List(detector.requiredSamples);
      _work = Float64List(detector.requiredSamples);
    }
    _filled = 0;
  }

  /// Turns the tuner off and releases the microphone.
  Future<void> stop() async {
    _session++;
    await _stopMic();
    _resetAnalysis();
    _status = TunerStatus.idle;
    _message = null;
    _permissionPermanentlyDenied = false;
    _notify();
  }

  Future<void> openSystemSettings() => _permission.openSettings();

  /// Selects the string to tune; `null` switches to automatic detection.
  void selectString(GuitarString? string) {
    if (_selectedString == string) return;
    _selectedString = string;
    _recentFrequencies.clear();
    _reading = null;
    _notify();
  }

  // ---------------------------------------------------------------- audio

  void _onSamples(Float64List chunk) {
    final detector = _detector;
    if (_status != TunerStatus.listening || _disposed || detector == null) return;
    final size = _frame.length;

    // Slide the newest samples into the end of the analysis frame.
    if (chunk.length >= size) {
      _frame.setRange(0, size, chunk, chunk.length - size);
      _filled = size;
    } else {
      _frame.setRange(0, size - chunk.length, _frame, chunk.length);
      _frame.setRange(size - chunk.length, size, chunk);
      _filled = math.min(size, _filled + chunk.length);
    }
    if (_filled < size) return;

    final now = _clock();
    if (now - _lastAnalysisAt < _minAnalysisIntervalMicros) return;
    _lastAnalysisAt = now;
    _analyse(now, detector);
  }

  void _analyse(int now, YinPitchDetector detector) {
    final size = _frame.length;

    // Remove DC offset and measure the level.
    var mean = 0.0;
    for (var i = 0; i < size; i++) {
      mean += _frame[i];
    }
    mean /= size;
    var energy = 0.0;
    for (var i = 0; i < size; i++) {
      final v = _frame[i] - mean;
      _work[i] = v;
      energy += v * v;
    }
    final rms = math.sqrt(energy / size);

    if (rms < minRms) {
      _onNoPitch(now, SignalQuality.weak);
      return;
    }

    final estimate = detector.detect(_work);
    if (estimate == null || estimate.clarity < minClarity) {
      _onNoPitch(now, SignalQuality.unclear);
      return;
    }

    _recentFrequencies.add(estimate.frequency);
    if (_recentFrequencies.length > _medianWindow) {
      _recentFrequencies.removeAt(0);
    }
    final frequency = _median(_recentFrequencies);

    _reading = buildReading(frequency);
    _signal = SignalQuality.good;
    _lastPitchAt = now;
    _notify();
  }

  void _onNoPitch(int now, SignalQuality quality) {
    var changed = _signal != quality;
    _signal = quality;
    if (_reading != null && now - _lastPitchAt > _holdMicros) {
      _reading = null;
      _recentFrequencies.clear();
      changed = true;
    }
    if (changed) _notify();
  }

  /// Turns a frequency into a note + tuning offset against the target string.
  /// Public so it can be unit-tested without audio.
  TunerReading buildReading(double frequency) {
    final midi = MusicTheory.midiFromFrequency(frequency).round();
    final target = _selectedString ?? _nearestString(frequency);
    final rawCents = MusicTheory.centsBetween(frequency, target.frequency);
    final cents = MusicTheory.foldCentsToOctave(rawCents);

    final TuneDirection direction;
    if (cents.abs() <= inTuneCents) {
      direction = TuneDirection.inTune;
    } else if (cents < 0) {
      direction = TuneDirection.tuneUp; // Flat -> raise the pitch.
    } else {
      direction = TuneDirection.tuneDown; // Sharp -> lower the pitch.
    }

    return TunerReading(
      frequency: frequency,
      noteName: MusicTheory.noteNameOfMidi(midi),
      octave: MusicTheory.octaveOfMidi(midi),
      targetString: target,
      cents: cents,
      direction: direction,
      farFromTarget: cents.abs() > farFromTargetCents,
    );
  }

  /// Automatic mode: the string whose pitch is closest (octave-insensitive,
  /// ties broken by true distance so E2 and E4 are told apart).
  GuitarString _nearestString(double frequency) {
    var best = strings.first;
    var bestFolded = double.infinity;
    var bestRaw = double.infinity;
    for (final string in strings) {
      final raw = MusicTheory.centsBetween(frequency, string.frequency);
      final folded = MusicTheory.foldCentsToOctave(raw).abs();
      final isBetter = folded < bestFolded - 0.001 ||
          ((folded - bestFolded).abs() <= 0.001 && raw.abs() < bestRaw);
      if (isBetter) {
        best = string;
        bestFolded = folded;
        bestRaw = raw.abs();
      }
    }
    return best;
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  // ------------------------------------------------------------ housekeeping

  void _onMicrophoneError(Object error) {
    if (_disposed || _status != TunerStatus.listening) return;
    _fail('The microphone stopped working. Please try again.');
  }

  void _fail(String message) {
    _session++;
    unawaited(_stopMic());
    _resetAnalysis();
    _status = TunerStatus.error;
    _message = message;
    _notify();
  }

  Future<void> _stopMic() async {
    try {
      await _mic.stop();
    } catch (_) {
      // Releasing the microphone must never crash the app.
    }
  }

  void _resetAnalysis() {
    _filled = 0;
    _lastAnalysisAt = -_minAnalysisIntervalMicros;
    _recentFrequencies.clear();
    _reading = null;
    _signal = SignalQuality.none;
  }

  bool _isStale(int session) => _disposed || session != _session;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    unawaited(_stopMic());
    super.dispose();
  }
}
