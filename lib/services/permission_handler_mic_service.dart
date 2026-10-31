import 'package:permission_handler/permission_handler.dart';

import 'mic_permission_service.dart';

/// Android / iOS microphone permission via `permission_handler`.
class PermissionHandlerMicService implements MicPermissionService {
  @override
  Future<MicPermission> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
