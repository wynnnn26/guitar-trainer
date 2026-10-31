enum MicPermission {
  granted,

  /// Denied, but the system dialog can be shown again.
  denied,

  /// Denied for good (or restricted): only the system settings can fix it.
  permanentlyDenied,
}

/// Microphone permission handling, abstracted for testing and for the web.
abstract class MicPermissionService {
  /// Shows the system permission dialog if needed and returns the outcome.
  Future<MicPermission> request();

  /// Opens the app's page in the system settings (no-op where unsupported).
  Future<void> openSettings();
}

/// For platforms where the permission prompt is shown by the act of opening
/// the microphone itself (browsers: `getUserMedia`). [request] always succeeds
/// and a refusal surfaces later as a `MicrophonePermissionException`.
class DeferredMicPermissionService implements MicPermissionService {
  const DeferredMicPermissionService();

  @override
  Future<MicPermission> request() async => MicPermission.granted;

  @override
  Future<void> openSettings() async {}
}
