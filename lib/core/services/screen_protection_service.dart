import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Screen Protection Service to guard against unauthorized screen captures
/// and recording during video calls and live sessions.
class ScreenProtectionService {
  ScreenProtectionService._();
  static final ScreenProtectionService instance = ScreenProtectionService._();

  bool get isScreenshotProtectionEnabled {
    final cfg = RemoteConfigService.instance.remoteConfig;
    if (cfg != null) {
      if (cfg['screenshot_protection_enabled'] != null) {
        return cfg['screenshot_protection_enabled'] == true;
      }
      final flags = cfg['remote_flags'];
      if (flags is Map && flags['screenshot_protection_enabled'] != null) {
        return flags['screenshot_protection_enabled'] == true;
      }
    }
    return true; // Default to secure
  }

  bool get isScreenRecordingProtectionEnabled {
    final cfg = RemoteConfigService.instance.remoteConfig;
    if (cfg != null) {
      if (cfg['screen_recording_protection_enabled'] != null) {
        return cfg['screen_recording_protection_enabled'] == true;
      }
      final flags = cfg['remote_flags'];
      if (flags is Map && flags['screen_recording_protection_enabled'] != null) {
        return flags['screen_recording_protection_enabled'] == true;
      }
    }
    return true; // Default to secure
  }

  void logProtectionStatus() {
    debugPrint(
      '🔒 [ScreenProtectionService] Screenshot Protection: $isScreenshotProtectionEnabled | Screen Recording Protection: $isScreenRecordingProtectionEnabled',
    );
  }
}
