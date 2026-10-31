import 'dart:typed_data';

import 'package:guitar_trainer/services/click_player.dart';
import 'package:guitar_trainer/services/mic_permission_service.dart';
import 'package:guitar_trainer/services/microphone_service.dart';

class FakeClickPlayer implements ClickPlayer {
  /// One entry per click: `true` = accented (downbeat).
  final List<bool> clicks = [];
  Object? initError;
  bool initialised = false;
  bool disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  Future<void> init() async {
    if (initError != null) throw initError!;
    initialised = true;
  }

  @override
  void play({required bool accent}) => clicks.add(accent);

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeMicrophone implements MicrophoneService {
  int startCount = 0;
  int stopCount = 0;
  bool active = false;
  Object? startError;

  void Function(Float64List samples)? _onSamples;
  void Function(Object error)? _onError;

  /// Browsers typically deliver 48 kHz, phones 44.1 kHz.
  int rate = 44100;

  @override
  int get sampleRate => rate;

  @override
  Future<void> start({
    required void Function(Float64List samples) onSamples,
    required void Function(Object error) onError,
  }) async {
    startCount++;
    if (startError != null) throw startError!;
    _onSamples = onSamples;
    _onError = onError;
    active = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    active = false;
    _onSamples = null;
    _onError = null;
  }

  /// Pushes samples as if they came from the microphone (ignored when stopped).
  void emit(Float64List samples) => _onSamples?.call(samples);

  void emitError(Object error) => _onError?.call(error);
}

class FakePermission implements MicPermissionService {
  FakePermission([this.result = MicPermission.granted]);

  MicPermission result;
  int requestCount = 0;
  int settingsOpened = 0;

  @override
  Future<MicPermission> request() async {
    requestCount++;
    return result;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
