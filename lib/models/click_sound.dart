/// The metronome's sound sets.
///
/// Every set ships two generated WAV variants: [accentAsset] (the downbeat,
/// higher and louder) and [normalAsset] (all other beats).
enum ClickSound {
  classic('Classic click', 'classic'),
  woodblock('Woodblock', 'woodblock'),
  digital('Digital beep', 'digital'),
  soft('Soft tick', 'soft');

  const ClickSound(this.label, this.assetKey);

  /// Display name in the sound picker.
  final String label;

  final String assetKey;

  String get accentAsset => 'sounds/${assetKey}_accent.wav';
  String get normalAsset => 'sounds/${assetKey}_normal.wav';
}
