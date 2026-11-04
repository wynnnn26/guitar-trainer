import '../models/click_sound.dart';

/// Plays the metronome click. Abstracted so the metronome logic can be tested
/// without the audio plugin.
abstract class ClickPlayer {
  /// Loads the default sound ([ClickSound.classic]). Throws if the audio
  /// backend is unavailable.
  Future<void> init();

  /// Preloads [sound] and makes it the set used by later clicks. Throws if
  /// the assets cannot be loaded; the previous sound keeps playing then.
  Future<void> setSound(ClickSound sound);

  /// Output level, 0.0 (mute) to 1.0 (full).
  void setVolume(double volume);

  /// Plays a single click immediately. Must not throw.
  void play({required bool accent});

  /// Called when a click could not be played.
  void Function(Object error)? onError;

  Future<void> dispose();
}
