import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../utils/app_logger.dart';

class CallkitService {
  static final CallkitService _instance = CallkitService._internal();
  factory CallkitService() => _instance;
  CallkitService._internal();

  static Function(Map<String, dynamic> data)? onCallAccepted;
  static Function(Map<String, dynamic> data)? onCallDeclined;
  static Function(Map<String, dynamic> data)? onCallTimedOut;

  static bool _isListenerInitialized = false;

  static void init({
    Function(Map<String, dynamic> data)? onAccept,
    Function(Map<String, dynamic> data)? onDecline,
    Function(Map<String, dynamic> data)? onTimeout,
  }) {
    if (onAccept != null) onCallAccepted = onAccept;
    if (onDecline != null) onCallDeclined = onDecline;
    if (onTimeout != null) onCallTimedOut = onTimeout;

    if (_isListenerInitialized) return;
    _isListenerInitialized = true;

    try {
      FlutterCallkitIncoming.onEvent.listen((dynamic event) {
        if (event == null) return;
        AppLogger.info('CallkitService', 'Callkit Event received: $event');

        Map<String, dynamic> extra = {};
        String eventName = '';

        try {
          // Dynamic reflection over CallEvent fields
          final dyn = event as dynamic;
          eventName = (dyn.event ?? dyn.name ?? dyn.type ?? '').toString();
          final rawBody = dyn.body ?? dyn.data;
          if (rawBody is Map && rawBody['extra'] is Map) {
            extra = Map<String, dynamic>.from(rawBody['extra'] as Map);
          } else if (rawBody is Map) {
            extra = Map<String, dynamic>.from(rawBody);
          }
        } catch (_) {}

        final lower = eventName.toLowerCase();
        if (lower.contains('accept')) {
          AppLogger.info('CallkitService', 'User accepted call from CallKit');
          onCallAccepted?.call(extra);
        } else if (lower.contains('decline')) {
          AppLogger.info('CallkitService', 'User declined call from CallKit');
          onCallDeclined?.call(extra);
        } else if (lower.contains('timeout')) {
          AppLogger.info('CallkitService', 'CallKit ringing timeout');
          onCallTimedOut?.call(extra);
        } else if (lower.contains('ended')) {
          AppLogger.info('CallkitService', 'CallKit call ended');
        }
      });
    } catch (e, st) {
      AppLogger.error('CallkitService', 'Error initializing Callkit listener: $e', st);
    }
  }

  /// Show Full-Screen incoming call banner/notification with ringing
  static Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerAvatar,
    required String channelName,
    String callType = 'video',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final params = CallKitParams(
        id: callId,
        nameCaller: callerName.isNotEmpty ? callerName : 'Incoming Call',
        appName: 'Chinchins Live',
        avatar: callerAvatar,
        handle: callType == 'video' ? 'Video Call' : 'Audio Call',
        type: callType == 'video' ? 1 : 0,
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Missed Call',
          callbackText: 'Call Back',
        ),
        duration: 45000, // 45 seconds ringing timeout
        extra: <String, dynamic>{
          'call_id': callId,
          'channel_name': channelName,
          'caller_name': callerName,
          'caller_avatar': callerAvatar,
          'call_type': callType,
          ...?extraData,
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0F0C20',
          actionColor: '#4CAF50',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Incoming Calls',
          missedCallNotificationChannelName: 'Missed Calls',
          isShowCallID: false,
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'videoChat',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(params);
      AppLogger.info('CallkitService', 'Triggered CallKit incoming call UI for callId: $callId');
    } catch (e, st) {
      AppLogger.error('CallkitService', 'Error showing incoming callkit: $e', st);
    }
  }

  /// End specific call
  static Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
      AppLogger.info('CallkitService', 'Ended CallKit call: $callId');
    } catch (e) {
      debugPrint('[CallkitService] endCall error: $e');
    }
  }

  /// End all active call UI
  static Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
      AppLogger.info('CallkitService', 'Ended all CallKit calls');
    } catch (e) {
      debugPrint('[CallkitService] endAllCalls error: $e');
    }
  }
}
