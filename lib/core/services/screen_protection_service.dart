import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'remote_config_service.dart';

/// Screen Protection Service to control screen capture/recording permissions.
class ScreenProtectionService {
  ScreenProtectionService._();
  static final ScreenProtectionService instance = ScreenProtectionService._();

  static const MethodChannel _channel =
      MethodChannel('com.chinchins.live/screen_protection');

  bool get isScreenshotProtectionEnabled =>
      RemoteConfigService.instance.config.isScreenshotProtectionEnabled;

  bool get isScreenRecordingProtectionEnabled =>
      RemoteConfigService.instance.config.isScreenRecordingProtectionEnabled;

  /// Disable secure window flag to allow screenshots & screen recordings
  Future<void> allowScreenshots() async {
    try {
      await _channel.invokeMethod('clearSecure');
      debugPrint('🔓 [ScreenProtectionService] Screenshot & Screen Recording allowed.');
    } catch (e) {
      debugPrint('⚠️ [ScreenProtectionService] Failed to clear secure flag: $e');
    }
  }

  /// Sync protection state
  Future<void> syncProtection() async {
    try {
      final shouldProtect = isScreenshotProtectionEnabled || isScreenRecordingProtectionEnabled;
      await _channel.invokeMethod('setSecure', {'secure': shouldProtect});
    } catch (_) {}
  }

  void logProtectionStatus() {
    debugPrint(
      '🔓 [ScreenProtectionService] Screenshot Protection: $isScreenshotProtectionEnabled | Screen Recording Protection: $isScreenRecordingProtectionEnabled',
    );
  }
}
