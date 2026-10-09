import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/app_logger.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(VPSConnectionTaskHandler());
}

class VPSConnectionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    AppLogger.info('ForegroundTask', 'VPS Connection background task started.');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep alive heartbeat tick
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    AppLogger.info('ForegroundTask', 'VPS Connection background task destroyed.');
  }
}

class ForegroundTaskService {
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'chinchins_live_foreground_service',
          channelName: 'Chinchins Live Calling Service',
          channelDescription: 'Maintains live incoming call connection with VPS server',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: const NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(30000),
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e, st) {
      AppLogger.error('ForegroundTaskService', 'Error initializing ForegroundTask: $e', st);
    }
  }

  static Future<void> startService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Chinchins Live Active',
        notificationText: 'Connected to VPS calling & messaging server',
        callback: startForegroundCallback,
      );
      AppLogger.info('ForegroundTaskService', 'Foreground Service successfully started');
    } catch (e) {
      debugPrint('[ForegroundTaskService] startService error: $e');
    }
  }

  static Future<void> stopService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        AppLogger.info('ForegroundTaskService', 'Foreground Service stopped');
      }
    } catch (e) {
      debugPrint('[ForegroundTaskService] stopService error: $e');
    }
  }
}
