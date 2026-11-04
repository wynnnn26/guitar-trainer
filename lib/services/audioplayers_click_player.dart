import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/click_sound.dart';
import 'click_player.dart';

/// [ClickPlayer] for Android / iOS / desktop, backed by `audioplayers` in low-latency mode.
///
/// One player is used per sound. Re-triggering a player restarts its sound
/// instead of stacking new playback on top, so clicks can never pile up.
class AudioplayersClickPlayer implements ClickPlayer {
  AudioplayersClickPlayer()
      : _accentPlayer = AudioPlayer(),
        _normalPlayer = AudioPlayer();

  final AudioPlayer _accentPlayer;
  final AudioPlayer _normalPlayer;

  AssetSource _accentSource = AssetSource(ClickSound.classic.accentAsset);
  AssetSource _normalSource = AssetSource(ClickSound.classic.normalAsset);
  ClickSound _sound = ClickSound.classic;

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
    await _preload(ClickSound.classic);
    _ready = true;
  }

  @override
  Future<void> setSound(ClickSound sound) async {
    if (_disposed || sound == _sound) return;
    await _preload(sound);
  }

  /// Loads both variants of [sound]. The sources are only swapped once both
  /// players accepted them, so a failed switch keeps the old sound.
  Future<void> _preload(ClickSound sound) async {
    final accent = AssetSource(sound.accentAsset);
    final normal = AssetSource(sound.normalAsset);
    await _accentPlayer.setSource(accent);
    await _normalPlayer.setSource(normal);
    _accentSource = accent;
    _normalSource = normal;
    _sound = sound;
  }

  @override
  void setVolume(double volume) {
    final level = volume.clamp(0.0, 1.0);
    unawaited(
      _accentPlayer.setVolume(level).catchError((Object error) {
        onError?.call(error);
      }),
    );
    unawaited(
      _normalPlayer.setVolume(level).catchError((Object error) {
        onError?.call(error);
      }),
    );
  }

  @override
  void play({required bool accent}) {
    if (!_ready || _disposed) return;
    final player = accent ? _accentPlayer : _normalPlayer;
    final source = accent ? _accentSource : _normalSource;
    unawaited(() async {
      // Android low-latency (SoundPool) mode never reports playback
      // completion, so the plugin keeps its "playing" flag set forever after
      // the first click: further play()/resume() calls then hit
      // soundPool.resume() on an already-finished stream and produce silence
      // while the UI keeps ticking (upstream: audioplayers #1489). stop()
      // resets both the flag and the stream id — and re-requests audio focus
      // — so every click starts a fresh stream and recovers on its own if
      // focus was ever lost.
      await player.stop();
      await player.play(source, mode: PlayerMode.lowLatency);
    }().catchError((Object error) {
      onError?.call(error);
    }));
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
