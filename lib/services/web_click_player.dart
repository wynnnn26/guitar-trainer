import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'click_player.dart';

/// Metronome click for browsers, synthesised with the Web Audio API.
///
/// Compared with playing an audio file this has much lower latency and needs
/// no assets. Each click is a very short sine burst with a fast decay that
/// stops itself, so clicks can never overlap or loop.
///
/// Browsers only let audio start after a user gesture. [play] is first called
/// from the Start button's tap handler, and resumes the context if needed.
class WebAudioClickPlayer implements ClickPlayer {
  web.AudioContext? _context;
  bool _disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  Future<void> init() async {
    _context = web.AudioContext();
  }

  @override
  void play({required bool accent}) {
    final context = _context;
    if (context == null || _disposed) return;
    try {
      if (context.state != 'running') {
        unawaited(
          context.resume().toDart.then<void>(
            (_) {},
            onError: (Object error) => onError?.call(error),
          ),
        );
      }

      final now = context.currentTime;
      final oscillator = context.createOscillator();
      final gain = context.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.value = accent ? 1600.0 : 1000.0;
      gain.gain.setValueAtTime(accent ? 0.9 : 0.7, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start(now);
      oscillator.stop(now + 0.07);
    } catch (error) {
      onError?.call(error);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final context = _context;
    _context = null;
    if (context == null) return;
    try {
      await context.close().toDart;
    } catch (_) {
      // Already closed; nothing to do.
    }
  }
}
