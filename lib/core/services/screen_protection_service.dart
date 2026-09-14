import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Screen Protection Service to guard against unauthorized screen captures
/// and recording during video calls and live sessions.
class ScreenProtectionService {
  ScreenProtectionService._();
  static final ScreenProtectionService instance = ScreenProtectionService._();

  bool get isScreenshotProtectionEnabled =>
      RemoteConfigService.instance.config.isScreenshotProtectionEnabled;

  bool get isScreenRecordingProtectionEnabled =>
      RemoteConfigService.instance.config.isScreenRecordingProtectionEnabled;

  void logProtectionStatus() {
    debugPrint(
      '🔒 [ScreenProtectionService] Screenshot Protection: $isScreenshotProtectionEnabled | Screen Recording Protection: $isScreenRecordingProtectionEnabled',
    );
  }
}
