import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand header shown above every section: FretFlow logo, app name and the
/// entry point to the About dialog.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  static const String appName = 'FretFlow';
  static const String tagline = 'Master Your Rhythm. Know Your Notes. Perfect Your Tone.';

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String version = '1.0.0';

  static const String _logoAsset = 'assets/images/fretflow_logo.png';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 6, 0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _logoAsset,
                width: 34,
                height: 34,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.music_note,
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAbout(context),
              tooltip: 'About $appName',
              icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: version,
      applicationLegalese: tagline,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          _logoAsset,
          width: 56,
          height: 56,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.music_note,
            color: AppColors.accent,
            size: 48,
          ),
        ),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Three practice tools in one app:\n'
          '• Advanced & Basic Metronome\n'
          '• Note Trainer\n'
          '• Guitar Tuner',
          style: AppText.caption,
        ),
      ],
    );
  }
}
