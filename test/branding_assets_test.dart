import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/models/click_sound.dart';

/// The branding/sound pipeline (`tool/generate_clicks.py`,
/// `tool/prepare_branding.py`) must have produced every file the app loads —
/// a missing one would only show up as silent audio or a broken icon on a
/// device.
void main() {
  test('every click sound asset exists', () {
    for (final sound in ClickSound.values) {
      // Asset keys are bundle paths; the files live under assets/.
      expect(File('assets/${sound.accentAsset}').existsSync(), isTrue,
          reason: sound.accentAsset);
      expect(File('assets/${sound.normalAsset}').existsSync(), isTrue,
          reason: sound.normalAsset);
    }
  });

  test('the FretFlow logo asset exists', () {
    expect(File('assets/images/fretflow_logo.png').existsSync(), isTrue);
  });
}
