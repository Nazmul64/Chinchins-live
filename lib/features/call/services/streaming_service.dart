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
  /// Fetch the active streaming engine & credentials from Admin Settings
  /// Returns driver ('agora' or 'vps_webrtc') along with Agora credentials or VPS WebRTC config
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

      final url = Uri.parse('${ApiConstants.baseUrl}/stream/session-token');
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

      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        // Fallback to alias endpoint
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/v1/stream/initialize'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));
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

  /// Check active driver from public endpoint
  static Future<String> getActiveDriver() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/stream/driver');
      final response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['driver'] != null) {
          return decoded['driver'].toString();
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
    final String? agoraAppId = sessionData['agora_app_id']?.toString();
    final String? agoraToken = sessionData['agora_token']?.toString();
    final bool isTempToken = sessionData['is_temp_token'] == true;
    final String activeChannelName = sessionData['channel_name']?.toString() ?? channelName;

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
          ),
        ),
      );
    } else {
      // Launch Hostinger VPS WebRTC + Reverb WebSocket Call Screen
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
