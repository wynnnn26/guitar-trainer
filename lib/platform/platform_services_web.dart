import '../services/click_player.dart';
import '../services/mic_permission_service.dart';
import '../services/microphone_service.dart';
import '../services/web_click_player.dart';
import '../services/web_microphone_service.dart';

/// Browser implementations (Web Audio API).
ClickPlayer createClickPlayer() => WebAudioClickPlayer();
MicrophoneService createMicrophoneService() => WebMicrophoneService();

/// The browser asks for permission itself when the microphone is opened.
MicPermissionService createMicPermissionService() => const DeferredMicPermissionService();
