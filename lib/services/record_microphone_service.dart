import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'microphone_service.dart';

/// [MicrophoneService] for Android / iOS / desktop, backed by the `record` package
/// (16-bit PCM stream).
class RecordMicrophoneService implements MicrophoneService {
  static const int _sampleRateHz = 44100;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _subscription;
  int? _pendingByte; // Odd trailing byte carried over to the next chunk.

  @override
  int get sampleRate => _sampleRateHz;

  @override
  Future<void> start({
    required void Function(Float64List samples) onSamples,
    required void Function(Object error) onError,
  }) async {
    await stop(); // Never keep two recorders alive.

    final recorder = AudioRecorder();
    _recorder = recorder;
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRateHz,
          numChannels: 1,
          // Raw signal: processing like AGC / noise suppression distorts pitch.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      if (!identical(_recorder, recorder)) {
        // stop() (or a newer start()) happened while this recorder was still
        // starting: release it so it cannot keep the microphone open.
        await _release(recorder);
        return;
      }
      _subscription = stream.listen(
        (bytes) => _handleBytes(bytes, onSamples),
        onError: (Object error, StackTrace _) => onError(error),
        cancelOnError: false,
      );
    } catch (_) {
      if (identical(_recorder, recorder)) _recorder = null;
      await _release(recorder);
      rethrow;
    }
  }

  void _handleBytes(Uint8List bytes, void Function(Float64List) onSamples) {
    var data = bytes;
    final pending = _pendingByte;
    if (pending != null) {
      data = Uint8List(bytes.length + 1);
      data[0] = pending;
      data.setRange(1, data.length, bytes);
      _pendingByte = null;
    }
    final usableBytes = data.length - (data.length % 2);
    if (usableBytes < data.length) {
      _pendingByte = data[data.length - 1];
    }
    if (usableBytes == 0) return;

    final view = ByteData.sublistView(data, 0, usableBytes);
    final samples = Float64List(usableBytes ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    onSamples(samples);
  }

  @override
  Future<void> stop() async {
    final subscription = _subscription;
    final recorder = _recorder;
    _subscription = null;
    _recorder = null;
    _pendingByte = null;

    await subscription?.cancel();
    if (recorder != null) await _release(recorder);
  }

  Future<void> _release(AudioRecorder recorder) async {
    try {
      await recorder.stop();
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}
