import '../services/audioplayers_click_player.dart';
import '../services/click_player.dart';
import '../services/mic_permission_service.dart';
import '../services/microphone_service.dart';
import '../services/permission_handler_mic_service.dart';
import '../services/record_microphone_service.dart';

/// Android, iOS and desktop implementations.
ClickPlayer createClickPlayer() => AudioplayersClickPlayer();
MicrophoneService createMicrophoneService() => RecordMicrophoneService();
MicPermissionService createMicPermissionService() => PermissionHandlerMicService();
