#!/usr/bin/env bash
# Generates the android/, ios/ and web/ folders (if missing) and applies the
# configuration this app needs. Safe to run more than once.
#
#   ./tool/setup_platforms.sh
#
# Requires the Flutter SDK on your PATH. On Windows use Git Bash, or follow the
# manual steps in README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null 2>&1 || { echo "Flutter SDK not found on PATH."; exit 1; }

if [ ! -d android ] || [ ! -d ios ] || [ ! -d web ]; then
  echo "==> Generating platform folders"
  flutter create --platforms=android,ios,web --project-name guitar_trainer --org com.example .
fi

# The template creates a counter-app test that does not apply to this app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
  echo "==> Removed template test/widget_test.dart"
fi

echo "==> Android: RECORD_AUDIO permission"
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.RECORD_AUDIO" "$MANIFEST"; then
  perl -0pi -e 's#(\s*)<application#$1<uses-permission android:name="android.permission.RECORD_AUDIO" />$1<application#' "$MANIFEST"
fi

echo "==> Android: minSdk 23 (required by the 'record' package)"
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] || continue
  perl -pi -e 's/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion Math.max(flutter.minSdkVersion, 23)/; s/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' "$f"
done

echo "==> iOS: microphone usage description"
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q "NSMicrophoneUsageDescription" "$PLIST"; then
  perl -0pi -e 's#</dict>\s*</plist>#\t<key>NSMicrophoneUsageDescription</key>\n\t<string>The tuner listens to your guitar through the microphone.</string>\n</dict>\n</plist>#' "$PLIST"
fi

echo "==> iOS: enable the microphone permission in permission_handler"
PODFILE=ios/Podfile
if [ -f "$PODFILE" ]; then
  if ! grep -q "PERMISSION_MICROPHONE" "$PODFILE"; then
    perl -0pi -e "s#(flutter_additional_ios_build_settings\(target\)\n)#\$1    target.build_configurations.each do |config|\n      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['\\\$(inherited)', 'PERMISSION_MICROPHONE=1']\n    end\n#" "$PODFILE"
  fi
else
  echo "    ios/Podfile does not exist yet. Run 'flutter pub get' and 'flutter build ios' once,"
  echo "    then run this script again (see README, section iOS)."
fi

echo "==> Web: page title and description"
INDEX=web/index.html
if [ -f "$INDEX" ]; then
  perl -0pi -e 's#<title>.*?</title>#<title>Guitar Trainer</title>#s; s#(<meta name="description" content=")[^"]*(")#$1Metronome, note trainer and guitar tuner$2#' "$INDEX"
fi

echo "==> Fetching packages"
flutter pub get

echo
echo "Done."
echo "  Phone:    flutter run                (use a real device: emulators have no guitar!)"
echo "  Browser:  flutter run -d chrome      (microphone works on http://localhost)"
echo "  Release:  flutter build web --release    (host the build/web folder over HTTPS)"
