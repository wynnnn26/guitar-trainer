import 'dart:typed_data';

/// The user (or the browser/OS) refused microphone access.
class MicrophonePermissionException implements Exception {
  const MicrophonePermissionException({this.permanent = false, this.message});

  /// True when only the system settings can fix it.
  final bool permanent;

  /// Optional platform-specific explanation to show instead of the default.
  final String? message;

  @override
  String toString() => message ?? 'Microphone permission denied';
}

/// The microphone cannot be used (missing, busy, insecure page, ...).
class MicrophoneUnavailableException implements Exception {
  const MicrophoneUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Source of live microphone samples. Abstracted so the tuner logic can be
/// tested without a real microphone, and so Android/iOS and the browser can
/// each use the right implementation.
abstract class MicrophoneService {
  /// Sample rate (Hz) of the samples delivered to `onSamples`.
  ///
  /// Only valid once [start] has completed: browsers choose their own rate
  /// (commonly 48 000 Hz), so the tuner reads it after starting.
  int get sampleRate;

  /// Starts capturing. Samples are mono, normalised to [-1, 1].
  ///
  /// Throws [MicrophonePermissionException] if access is refused and
  /// [MicrophoneUnavailableException] (or any other error) if the microphone
  /// cannot be opened.
  Future<void> start({
    required void Function(Float64List samples) onSamples,
    required void Function(Object error) onError,
  });

  /// Stops capturing and releases the microphone. Safe to call repeatedly.
  Future<void> stop();
}
