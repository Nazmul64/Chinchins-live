import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class LiveStreamingApiService {
  /// 1. Get list of active live streams
  /// Calls GET /api/lives/active with fallbacks to /api/live/active, /api/live/list, /api/live/streams
  static Future<List<Map<String, dynamic>>> getActiveLiveStreams() async {
    try {
      final token = await AuthApiService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // Try primary endpoint: /api/lives/active
      var response = await http
          .get(Uri.parse(ApiConstants.liveActive), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http
            .get(Uri.parse(ApiConstants.liveActiveAlt), headers: headers)
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 404) {
        response = await http
            .get(Uri.parse(ApiConstants.liveList), headers: headers)
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 404) {
        response = await http
            .get(Uri.parse(ApiConstants.liveStreams), headers: headers)
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dynamic data = decoded['data'] ?? decoded['streams'] ?? decoded['lives'];
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e, st) {
      AppLogger.error('GetActiveLiveStreamsError', e, st);
    }
    return [];
  }

  /// 2. Host starts a live stream
  /// Calls POST /api/live/start
  static Future<Map<String, dynamic>?> startLiveStream({
    required String title,
    String? coverImageUrl,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.liveStart);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'title': title,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty) 'cover_image_url': coverImageUrl,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveCreate), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true || decoded['success'] == true) {
          return decoded['data'] is Map
              ? Map<String, dynamic>.from(decoded['data'] as Map)
              : Map<String, dynamic>.from(decoded as Map);
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
    required dynamic liveStreamId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveEnd);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
        'id': liveStreamId,
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
  /// Calls POST /api/live/join
  static Future<Map<String, dynamic>?> joinLiveStream({
    required dynamic liveStreamId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.liveJoin);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
        'id': liveStreamId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true || decoded['success'] == true) {
          return decoded['data'] is Map
              ? Map<String, dynamic>.from(decoded['data'] as Map)
              : Map<String, dynamic>.from(decoded as Map);
        }
      }
    } catch (e, st) {
      AppLogger.error('JoinLiveStreamError', e, st);
    }
    return null;
  }

  /// 5. Send public live comment message
  /// Calls POST /api/live/message
  static Future<Map<String, dynamic>?> sendLiveMessage({
    required dynamic liveStreamId,
    required String message,
    String type = 'text',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.liveMessage);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
        'message': message,
        'type': type,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveSendMessage(liveStreamId)), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('SendLiveMessageError', e, st);
    }
    return null;
  }

  /// 6. Send virtual gift in live stream (50/50 revenue split)
  /// Calls POST /api/live/gift
  static Future<Map<String, dynamic>?> sendLiveGift({
    required dynamic liveStreamId,
    required dynamic giftId,
    int quantity = 1,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.liveGift);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
        'gift_id': giftId,
        'quantity': quantity,
      };

      var response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.liveSendGift(liveStreamId)), headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('SendLiveGiftError', e, st);
    }
    return null;
  }

  /// 7. Viewer sends Co-Hosting / Multi-Guest join request
  /// Calls POST /api/live/join-request
  static Future<Map<String, dynamic>?> requestJoinCoHost({
    required dynamic liveStreamId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveJoinRequest);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      }
    } catch (e, st) {
      AppLogger.error('RequestJoinCoHostError', e, st);
    }
    return null;
  }

  /// 8. Host responds to Co-Hosting request (accept / reject)
  /// Calls POST /api/live/accept-request
  static Future<Map<String, dynamic>?> respondJoinCoHost({
    required dynamic requestId,
    required String action, // 'accept' or 'reject'
  }) async {
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

  /// 9. Host kicks guest from video grid
  /// Calls POST /api/live/kick-guest
  static Future<bool> kickGuest({
    required dynamic liveStreamId,
    required dynamic guestUserId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.liveKickGuest);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'live_stream_id': liveStreamId,
        'live_id': liveStreamId,
        'guest_user_id': guestUserId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e, st) {
      AppLogger.error('KickGuestError', e, st);
      return false;
    }
  }
}
