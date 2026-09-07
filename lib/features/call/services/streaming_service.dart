import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import '../screens/agora_call_screen.dart';
import '../screens/video_call_screen.dart';

class StreamingService {
  /// Fetch the active streaming engine & credentials from Laravel API Engine
  /// Supports POST /api/calls, POST /api/stream/session-token, and POST /api/calls/initiate
  static Future<Map<String, dynamic>> fetchSessionToken({
    required String channelName,
    String callType = 'video',
    String role = 'publisher',
    dynamic targetUserId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'channel_name': channelName,
        'call_type': callType,
        'role': role,
        if (targetUserId != null) 'target_user_id': targetUserId,
      };

      // 1. Try primary RESTful calling endpoint: /api/calls
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/calls'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      // 2. Fallback to /api/stream/session-token if 404
      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/stream/session-token'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 6));
      }

      // 3. Fallback to /api/calls/initiate if still 404
      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/calls/initiate'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e, st) {
      AppLogger.error('StreamingService.fetchSessionToken error', e, st);
    }

    // Default to Hostinger VPS WebRTC engine
    return {
      'driver': 'vps_webrtc',
      'channel_name': channelName,
      'call_type': callType,
    };
  }

  /// Refresh Agora RTC token automatically before expiry
  static Future<String> refreshAgoraToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'channel_name': channelName,
        'uid': uid,
        'role': role,
      };

      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/agora/token/refresh'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/stream/token/refresh'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final String? newToken = decoded['token']?.toString() ??
              decoded['rtc_token']?.toString() ??
              decoded['data']?['token']?.toString();
          if (newToken != null && newToken.isNotEmpty) {
            return newToken;
          }
        }
      }
    } catch (e) {
      AppLogger.error('StreamingService.refreshAgoraToken error', e);
    }
    return '';
  }

  /// Check active driver from public endpoint
  static Future<String> getActiveDriver() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/stream/driver');
      final response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = decoded['data'] ?? decoded;
          if (data['active_driver'] != null) return data['active_driver'].toString();
          if (data['driver'] != null) return data['driver'].toString();
        }
      }
    } catch (_) {}
    return 'vps_webrtc';
  }

  /// Request permissions and dynamically launch Agora or VPS WebRTC Screen
  static Future<void> startDynamicCall({
    required BuildContext context,
    required ModelProfile model,
    required String channelName,
    int? callId,
    String callType = 'video',
    bool isFreeTrial = false,
    int freeDurationSeconds = 16,
    int ratePerMinute = 100,
    bool isIncoming = false,
    String? dialToneUrl,
  }) async {
    // 1. Request Camera and Microphone permissions
    try {
      await [Permission.camera, Permission.microphone].request();
    } catch (_) {}

    // 2. Fetch Session Token & Driver with targetUserId
    final sessionData = await fetchSessionToken(
      channelName: channelName,
      callType: callType,
      targetUserId: model.id.isNotEmpty ? model.id : model.accountId,
    );

    final String driver = sessionData['driver']?.toString().toLowerCase() ?? 'vps_webrtc';
    final String? agoraAppId = sessionData['app_id']?.toString() ?? sessionData['agora_app_id']?.toString();
    final String? agoraToken = sessionData['token']?.toString() ??
        sessionData['rtc_token']?.toString() ??
        sessionData['agora_token']?.toString();
    final bool isTempToken = sessionData['is_temp_token'] == true;
    final String activeChannelName = sessionData['channel_name']?.toString() ?? channelName;
    final bool debugMode = sessionData['debug_mode'] == true || sessionData['sdk_logging'] == true;
    final String logLevel = sessionData['log_level']?.toString() ?? 'info';

    if (!context.mounted) return;

    // 3. Dynamic Router Switcher
    if (driver == 'agora' && agoraAppId != null && agoraAppId.isNotEmpty) {
      // Launch Agora Cloud Engine Call Screen
      final dynamic rawUid = sessionData['agora_uid'] ?? sessionData['uid'] ?? sessionData['user_id'];
      final int agoraUid = rawUid is int ? rawUid : (int.tryParse(rawUid?.toString() ?? '0') ?? 0);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgoraCallScreen(
            model: model,
            callId: callId,
            channelName: activeChannelName,
            appId: agoraAppId,
            token: agoraToken ?? '',
            uid: agoraUid,
            isTempToken: isTempToken,
            isFreeTrial: isFreeTrial,
            freeDurationSeconds: freeDurationSeconds,
            ratePerMinute: ratePerMinute,
            isIncoming: isIncoming,
            dialToneUrl: dialToneUrl,
            isVideo: callType == 'video',
            debugMode: debugMode,
            logLevel: logLevel,
          ),
        ),
      );
    } else {
      // Launch Hostinger VPS WebRTC + Reverb WebSocket Call Screen (Unchanged)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            model: model,
            callId: callId,
            channelName: channelName,
            isFreeTrial: isFreeTrial,
            freeDurationSeconds: freeDurationSeconds,
            ratePerMinute: ratePerMinute,
            isIncoming: isIncoming,
            dialToneUrl: dialToneUrl,
          ),
        ),
      );
    }
  }
}
