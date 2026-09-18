import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class LiveStreamingApiService {
  /// 1. Get list of active live streams
  /// Calls GET /api/lives/active with pagination and fallbacks
  static Future<List<Map<String, dynamic>>> getActiveLiveStreams({int page = 1, int perPage = 20}) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final queryParams = '?page=$page&per_page=$perPage';
      
      final endpoints = [
        '${ApiConstants.liveActive}$queryParams',
        '${ApiConstants.liveActiveAlt}$queryParams',
        '${ApiConstants.liveList}$queryParams',
        '${ApiConstants.liveStreamActive}$queryParams',
        '${ApiConstants.liveStreams}$queryParams',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .get(Uri.parse(endpoint), headers: headers)
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List) {
              return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
            if (decoded is Map) {
              final dynamic data = decoded['data'] ?? decoded['streams'] ?? decoded['lives'] ?? decoded['items'];
              if (data is List) {
                return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              } else if (data is Map && data['data'] is List) {
                return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
              }
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e, st) {
      AppLogger.error('GetActiveLiveStreamsError', e, st);
    }
    return [];
  }

  /// 2. Host starts a live stream
  /// Calls POST /api/live/start, POST /api/v1/stream/start, POST /api/v1/live/start
  static Future<Map<String, dynamic>?> startLiveStream({
    required String title,
    String? coverImageUrl,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'title': title,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty) 'cover_image': coverImageUrl,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty) 'cover_image_url': coverImageUrl,
      };

      final endpoints = [
        ApiConstants.liveStart,
        ApiConstants.liveStartV1,
        ApiConstants.liveStartV1Alt,
        ApiConstants.liveCreate,
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final decoded = jsonDecode(response.body);
            if (decoded['status'] == true || decoded['success'] == true || decoded['status'] == 'success') {
              return decoded['data'] is Map
                  ? Map<String, dynamic>.from(decoded['data'] as Map)
                  : Map<String, dynamic>.from(decoded as Map);
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e, st) {
      AppLogger.error('StartLiveStreamError', e, st);
    }
    return null;
  }

  /// 3. Host ends a live stream
  /// Calls POST /api/live/end
  static Future<Map<String, dynamic>?> endLiveStream({
    dynamic roomId,
    dynamic liveStreamId,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveEnd);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'live_stream_id': id,
        'live_id': id,
        'id': id,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('EndLiveStreamError', e, st);
    }
    return null;
  }

  /// 4. Audience joins a live stream
  /// Calls POST /api/live/join or POST /api/stream/join
  static Future<Map<String, dynamic>?> joinLiveStream({
    dynamic roomId,
    dynamic liveStreamId,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'room_id': id,
        'live_stream_id': id,
        'stream_id': id,
        'live_id': id,
        'id': id,
      };

      final endpoints = [
        ApiConstants.liveJoin,
        '${ApiConstants.baseUrl}/stream/join',
        '${ApiConstants.baseUrl}/live-stream/join',
        '${ApiConstants.baseUrl}/v1/stream/join',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final decoded = jsonDecode(response.body);
            if (decoded['status'] == true || decoded['success'] == true || decoded['status'] == 'success') {
              return decoded['data'] is Map
                  ? Map<String, dynamic>.from(decoded['data'] as Map)
                  : Map<String, dynamic>.from(decoded as Map);
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e, st) {
      AppLogger.error('JoinLiveStreamError', e, st);
    }
    return null;
  }

  /// 4b. Audience leaves a live stream
  /// Calls POST /api/live/leave
  static Future<bool> leaveLiveStream({
    dynamic roomId,
    dynamic liveStreamId,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return false;
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveLeave);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'live_stream_id': id,
        'live_id': id,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (e, st) {
      AppLogger.error('LeaveLiveStreamError', e, st);
      return false;
    }
  }

  /// 5. Send public live comment message
  /// Calls POST /api/live/send-message, POST /api/live/comment, POST /api/v1/stream/comment
  static Future<Map<String, dynamic>?> sendLiveMessage({
    dynamic roomId,
    dynamic liveStreamId,
    required String message,
    String type = 'text',
    dynamic giftId,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'room_id': id,
        'live_stream_id': id,
        'stream_id': id,
        'live_id': id,
        'message': message,
        'type': type,
        if (giftId != null) 'gift_id': giftId,
      };

      final endpoints = [
        ApiConstants.liveSendMessage,
        '${ApiConstants.baseUrl}/live/comment',
        '${ApiConstants.baseUrl}/v1/stream/comment',
        ApiConstants.liveComment,
        ApiConstants.liveStreamComment,
        ApiConstants.liveMessage,
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final decoded = jsonDecode(response.body);
            return decoded['data'] is Map
                ? Map<String, dynamic>.from(decoded['data'] as Map)
                : Map<String, dynamic>.from(decoded as Map);
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e, st) {
      AppLogger.error('SendLiveMessageError', e, st);
    }
    return null;
  }

  /// 6. Send virtual gift in live stream (50/50 revenue split)
  /// Calls POST /api/live/send-gift, POST /api/live/gift, POST /api/v1/stream/send-gift
  static Future<Map<String, dynamic>?> sendLiveGift({
    dynamic roomId,
    dynamic liveStreamId,
    required dynamic giftId,
    int quantity = 1,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'room_id': id,
        'live_stream_id': id,
        'stream_id': id,
        'live_id': id,
        'gift_id': giftId,
        'quantity': quantity,
      };

      final endpoints = [
        ApiConstants.liveSendGift,
        '${ApiConstants.baseUrl}/live/gift',
        '${ApiConstants.baseUrl}/v1/stream/send-gift',
        ApiConstants.liveGift,
        ApiConstants.liveStreamSendGift,
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final decoded = jsonDecode(response.body);
            return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e, st) {
      AppLogger.error('SendLiveGiftError', e, st);
    }
    return null;
  }

  /// 7. Co-Host Action: Invite, Accept, Reject, Remove
  /// Calls POST /api/live/cohost-action (Aliases: /api/live/handle-cohost)
  static Future<Map<String, dynamic>?> cohostAction({
    dynamic roomId,
    dynamic liveStreamId,
    required dynamic targetUserId,
    required String action, // 'invite', 'accept', 'reject', 'remove'
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveCohostAction);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'target_user_id': targetUserId,
        'action': action,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveHandleCohost), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('CohostActionError', e, st);
    }
    return null;
  }

  /// 7b. Viewer sends Co-Hosting request (Compatibility helper)
  static Future<Map<String, dynamic>?> requestJoinCoHost({
    dynamic roomId,
    dynamic liveStreamId,
  }) async {
    final savedUser = await AuthApiService.getSavedUser();
    final myUserId = savedUser?['id'] ?? savedUser?['account_id'];
    return cohostAction(
      roomId: roomId ?? liveStreamId,
      targetUserId: myUserId,
      action: 'invite',
    );
  }

  /// 7c. Host responds to Co-Hosting request (Compatibility helper)
  static Future<Map<String, dynamic>?> respondJoinCoHost({
    required dynamic requestId,
    required String action,
    dynamic roomId,
    dynamic liveStreamId,
    dynamic targetUserId,
  }) async {
    if (targetUserId != null) {
      return cohostAction(
        roomId: roomId ?? liveStreamId,
        targetUserId: targetUserId,
        action: action,
      );
    }
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveAcceptRequest);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'request_id': requestId,
        'action': action,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('RespondJoinCoHostError', e, st);
    }
    return null;
  }

  /// 7d. Host kicks guest from video grid (Compatibility helper)
  static Future<bool> kickGuest({
    dynamic roomId,
    dynamic liveStreamId,
    required dynamic guestUserId,
  }) async {
    final res = await cohostAction(
      roomId: roomId ?? liveStreamId,
      targetUserId: guestUserId,
      action: 'remove',
    );
    return res != null;
  }

  /// 8. WebRTC Signaling: Offer, Answer, ICE Candidate
  /// Calls POST /api/live/signal (Aliases: /api/v1/stream/signal, /api/live/send-signal)
  static Future<Map<String, dynamic>?> sendWebRTCSignal({
    dynamic roomId,
    dynamic liveStreamId,
    required dynamic toUserId,
    required String type, // 'offer', 'answer', 'candidate'
    required dynamic data,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveSignal);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'to_user_id': toUserId,
        'type': type,
        'data': data,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveSendSignal), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveStreamSignal), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('SendWebRTCSignalError', e, st);
    }
    return null;
  }

  /// 9. Audio Mute / Unmute Toggle
  /// Calls POST /api/live/mute-toggle (Aliases: /api/live/toggle-mute)
  static Future<Map<String, dynamic>?> toggleMute({
    dynamic roomId,
    dynamic liveStreamId,
    required dynamic targetUserId,
    required bool isMuted,
    bool mutedByHost = false,
  }) async {
    try {
      final id = (roomId ?? liveStreamId)?.toString();
      if (id == null) return null;
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveMuteToggle);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'target_user_id': targetUserId,
        'is_muted': isMuted,
        'muted_by_host': mutedByHost,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveToggleMute), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('ToggleMuteError', e, st);
    }
    return null;
  }

  /// 10. Send Live Like Reaction
  /// Calls POST /api/live/like
  static Future<Map<String, dynamic>?> sendLiveLike({
    required dynamic roomId,
    int count = 1,
  }) async {
    try {
      final id = roomId.toString();
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveLike);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'room_id': id,
        'stream_id': id,
        'live_id': id,
        'count': count,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('SendLiveLikeError', e, st);
    }
    return null;
  }

  /// 11. Get Live Viewers list
  /// Calls GET /api/live/viewers
  static Future<List<Map<String, dynamic>>> getLiveViewers({required dynamic roomId}) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse('${ApiConstants.liveViewers}?room_id=$roomId');
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (decoded is Map && decoded['data'] is List) {
          return (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e, st) {
      AppLogger.error('GetLiveViewersError', e, st);
    }
    return [];
  }
}
