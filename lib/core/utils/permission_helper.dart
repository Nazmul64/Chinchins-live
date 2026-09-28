import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static bool _isRequesting = false;

  /// Request Camera & Microphone permissions safely without concurrent race conditions
  static Future<bool> requestCallPermissions({bool isAudioOnly = false}) async {
    if (_isRequesting) {
      debugPrint('[PermissionHelper] Permission request already in progress, skipping concurrent call.');
      return true;
    }
    _isRequesting = true;

    try {
      final List<Permission> permissions = [
        Permission.microphone,
        if (!isAudioOnly) Permission.camera,
      ];

      // Check current status first to avoid redundant system dialogs
      bool allAlreadyGranted = true;
      for (final perm in permissions) {
        final status = await perm.status;
        if (!status.isGranted) {
          allAlreadyGranted = false;
          break;
        }
      }

      if (allAlreadyGranted) {
        return true;
      }

      final Map<Permission, PermissionStatus> results = await permissions.request();
      final micGranted = results[Permission.microphone]?.isGranted ?? false;
      final camGranted = isAudioOnly || (results[Permission.camera]?.isGranted ?? false);

      return micGranted && camGranted;
    } catch (e) {
      debugPrint('[PermissionHelper] Permission request error: $e');
      return false;
    } finally {
      _isRequesting = false;
    }
  }
}
