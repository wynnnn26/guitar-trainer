import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'microphone_service.dart';

/// Microphone for browsers: `getUserMedia` + Web Audio.
///
/// * The browser shows its own permission prompt when [start] opens the
///   microphone; refusal is reported as [MicrophonePermissionException].
/// * Requires a secure context (https:// or http://localhost).
/// * The AudioContext runs at the hardware rate (often 48 kHz). That rate is
///   exposed through [sampleRate] so pitch maths stay correct.
/// * Echo cancellation, noise suppression and auto gain are switched off:
///   they distort pitch.
/// * A `ScriptProcessorNode` delivers the samples. It is deprecated on paper
///   but supported by every browser, needs no extra JavaScript file and is
///   plenty for ~10 analyses per second.
class WebMicrophoneService implements MicrophoneService {
  web.AudioContext? _context;
  web.MediaStream? _stream;
  web.MediaStreamAudioSourceNode? _source;
  web.ScriptProcessorNode? _processor;

  int _sampleRate = 48000;

  /// Bumped by every start()/stop() so a slow start can tell it was cancelled.
  int _generation = 0;

  @override
  int get sampleRate => _sampleRate;

  @override
  Future<void> start({
    required void Function(Float64List samples) onSamples,
    required void Function(Object error) onError,
  }) async {
    await stop();
    final generation = ++_generation;

    if (!web.window.isSecureContext) {
      throw const MicrophoneUnavailableException(
        'Browsers only allow microphone access on secure pages. Open this '
        'app over https:// (or http://localhost while developing).',
      );
    }

    final web.MediaStream stream;
    try {
      final constraints = {
        'audio': {
          'echoCancellation': false,
          'noiseSuppression': false,
          'autoGainControl': false,
        },
        'video': false,
      }.jsify() as web.MediaStreamConstraints;
      stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    } catch (error) {
      throw _translate(error);
    }

    if (generation != _generation) {
      // Cancelled while the permission prompt was open.
      _stopTracks(stream);
      return;
    }

    try {
      final context = web.AudioContext();
      _context = context;
      _stream = stream;
      if (context.state != 'running') {
        await context.resume().toDart;
      }
      _sampleRate = context.sampleRate.round();

      final source = context.createMediaStreamSource(stream);
      final processor = context.createScriptProcessor(4096, 1, 1);
      processor.onaudioprocess = ((web.AudioProcessingEvent event) {
        if (generation != _generation) return;
        final input = event.inputBuffer.getChannelData(0).toDart;
        final copy = Float64List(input.length);
        for (var i = 0; i < input.length; i++) {
          copy[i] = input[i];
        }
        onSamples(copy);
      }).toJS;

      // The processor must be connected to the destination for the browser to
      // run it. It outputs silence (we never write to its output buffer).
      source.connect(processor);
      processor.connect(context.destination);
      _source = source;
      _processor = processor;

      // The browser's "stop sharing" button / unplugging a headset mic.
      for (final track in stream.getAudioTracks().toDart) {
        track.onended = ((web.Event _) {
          if (generation == _generation) {
            onError(const MicrophoneUnavailableException('The microphone was disconnected.'));
          }
        }).toJS;
      }
    } catch (error) {
      await _release();
      if (generation != _generation) return; // cancelled meanwhile; not an error
      throw const MicrophoneUnavailableException(
        'This browser could not start audio processing for the tuner.',
      );
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _release();
  }

  Future<void> _release() async {
    final processor = _processor;
    final source = _source;
    final stream = _stream;
    final context = _context;
    _processor = null;
    _source = null;
    _stream = null;
    _context = null;

    try {
      processor?.onaudioprocess = null;
      source?.disconnect();
      processor?.disconnect();
    } catch (_) {}
    if (stream != null) _stopTracks(stream);
    if (context != null) {
      try {
        await context.close().toDart;
      } catch (_) {}
    }
  }

  void _stopTracks(web.MediaStream stream) {
    try {
      for (final track in stream.getTracks().toDart) {
        track.onended = null;
        track.stop();
      }
    } catch (_) {}
  }

  Exception _translate(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('notallowed') ||
        text.contains('permission') ||
        text.contains('securityerror')) {
      return const MicrophonePermissionException(
        message: 'The browser blocked microphone access. Click the lock (or '
            'camera) icon in the address bar, allow the microphone for this '
            'site, then press Try Again.',
      );
    }
    if (text.contains('notfound') || text.contains('overconstrained')) {
      return const MicrophoneUnavailableException(
        'No microphone was found. Plug one in or check your system sound settings.',
      );
    }
    if (text.contains('notreadable') || text.contains('abort')) {
      return const MicrophoneUnavailableException(
        'The microphone could not be opened. Another app or tab may be using it.',
      );
    }
    return const MicrophoneUnavailableException(
      'Could not open the microphone in this browser.',
    );
  }
}
