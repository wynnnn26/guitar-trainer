import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'click_player.dart';

/// [ClickPlayer] for Android / iOS / desktop, backed by `audioplayers` in low-latency mode.
///
/// One player is used per sound. Re-triggering a player restarts its sound
/// instead of stacking new playback on top, so clicks can never pile up.
class AudioplayersClickPlayer implements ClickPlayer {
  AudioplayersClickPlayer()
      : _accentPlayer = AudioPlayer(),
        _normalPlayer = AudioPlayer();

  static const String _accentAsset = 'sounds/click_accent.wav';
  static const String _normalAsset = 'sounds/click_normal.wav';

  final AudioPlayer _accentPlayer;
  final AudioPlayer _normalPlayer;
  final AssetSource _accentSource = AssetSource(_accentAsset);
  final AssetSource _normalSource = AssetSource(_normalAsset);

  bool _ready = false;
  bool _disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  Future<void> init() async {
    for (final player in [_accentPlayer, _normalPlayer]) {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
    }
    // Pre-loading also surfaces missing/corrupt assets immediately.
    await _accentPlayer.setSource(_accentSource);
    await _normalPlayer.setSource(_normalSource);
    _ready = true;
  }

  @override
  void play({required bool accent}) {
    if (!_ready || _disposed) return;
    final player = accent ? _accentPlayer : _normalPlayer;
    final source = accent ? _accentSource : _normalSource;
    unawaited(
      player.play(source, mode: PlayerMode.lowLatency).catchError((Object error) {
        onError?.call(error);
      }),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    try {
      await _accentPlayer.dispose();
      await _normalPlayer.dispose();
    } catch (_) {
      // Nothing useful to do if the plugin is already gone.
    }
  }
}
