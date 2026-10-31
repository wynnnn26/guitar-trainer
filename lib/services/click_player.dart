
/// Plays the metronome click. Abstracted so the metronome logic can be tested
/// without the audio plugin.
abstract class ClickPlayer {
  /// Loads the sounds. Throws if the audio backend is unavailable.
  Future<void> init();

  /// Plays a single click immediately. Must not throw.
  void play({required bool accent});

  /// Called when a click could not be played.
  void Function(Object error)? onError;

  Future<void> dispose();
}
