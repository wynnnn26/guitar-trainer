import '../services/click_player.dart';
import '../services/mic_permission_service.dart';
import '../services/microphone_service.dart';
import 'platform_services_io.dart'
    if (dart.library.js_interop) 'platform_services_web.dart' as impl;

/// The only place that decides between mobile/desktop and browser code.
/// Everything else in the app talks to the interfaces.
ClickPlayer createClickPlayer() => impl.createClickPlayer();
MicrophoneService createMicrophoneService() => impl.createMicrophoneService();
MicPermissionService createMicPermissionService() => impl.createMicPermissionService();
