import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/fast_api_client.dart';
import '../../auth/services/auth_api_service.dart';

class ChatApiService {
  /// Global real-time unread badge notifier for bottom bar and header
  static final ValueNotifier<int> totalUnreadBadgeNotifier = ValueNotifier<int>(0);

  static dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Helper to get current user ID
  static Future<String?> _getCurrentUserId() async {
    final savedUser = await AuthApiService.getSavedUser();
    return savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();
  }

  /// Get conversations list (Inbox) - Instant SWR Cached + Network Sync
  static Future<Map<String, dynamic>?> getConversations({bool forceRefresh = false}) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final queryParams = <String, String>{};
      if (currentUserId != null && currentUserId.isNotEmpty) {
        queryParams['user_id'] = currentUserId;
      }

      // Check fast cache first
      final cached = FastApiClient.getCachedSync(ApiConstants.messages, queryParams);
      if (cached is Map && cached['data'] is Map) {
        final data = cached['data'] as Map<String, dynamic>;
        if (data['total_unread_badge'] is int) {
          totalUnreadBadgeNotifier.value = data['total_unread_badge'] as int;
        }
      }

      final uri = Uri.parse(ApiConstants.messages).replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final res = _safeJsonDecode(response.body);
        if (res != null && res['data'] != null) {
          final data = res['data'] as Map<String, dynamic>;
          if (data['total_unread_badge'] is int) {
            totalUnreadBadgeNotifier.value = data['total_unread_badge'] as int;
          }
          await FastApiClient.putCache(ApiConstants.messages, res, queryParams);
          return data;
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getConversations error: $e');
    }

    // If network fails, return cached copy
    final fallbackCached = await FastApiClient.getCached(ApiConstants.messages);
    if (fallbackCached is Map && fallbackCached['data'] is Map) {
      return fallbackCached['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Get messages with a specific user
  static Future<Map<String, dynamic>?> getMessagesWithUser(dynamic targetUserId, {int page = 1, int perPage = 50}) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (currentUserId != null && currentUserId.isNotEmpty) 'user_id': currentUserId,
      };

      final url = Uri.parse(ApiConstants.messagesByUser(targetUserId)).replace(queryParameters: queryParams);
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final res = _safeJsonDecode(response.body);
        if (res != null && res['data'] != null) {
          return res['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getMessagesWithUser error: $e');
    }
    return null;
  }

  /// Send message (Text, Voice, or Image)
  static Future<Map<String, dynamic>> sendMessage({
    required dynamic receiverId,
    String? message,
    String type = 'text',
    File? voiceFile,
    File? imageFile,
    int? duration,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final uri = Uri.parse(ApiConstants.messageSend);

      // If sending file (Voice or Image) -> multipart
      if (voiceFile != null || imageFile != null) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);
        request.fields['receiver_id'] = receiverId.toString();
        request.fields['type'] = type;
        if (currentUserId != null) {
          request.fields['user_id'] = currentUserId;
          request.fields['sender_id'] = currentUserId;
        }
        if (message != null && message.isNotEmpty) {
          request.fields['message'] = message;
        } else if (voiceFile != null) {
          request.fields['message'] = '[Voice Note]';
        } else if (imageFile != null) {
          request.fields['message'] = 'Photo';
        }

        if (duration != null) {
          request.fields['duration'] = duration.toString();
        }

        if (voiceFile != null && voiceFile.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('voice_file', voiceFile.path));
          request.files.add(await http.MultipartFile.fromPath('file', voiceFile.path));
        }
        if (imageFile != null && imageFile.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));
          request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);
        final res = _safeJsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final String msg = (res?['message'] ?? '').toString().toLowerCase();
          final bool isLimit = res?['can_message'] == false ||
              res?['show_recharge_modal'] == true ||
              res?['code'] == 'MESSAGE_LIMIT_REACHED' ||
              res?['is_limit_reached'] == true ||
              (res?['status'] == false && res?['success'] != true) ||
              msg.contains('limit') ||
              msg.contains('recharge') ||
              msg.contains('insufficient') ||
              msg.contains('low balance') ||
              (msg.contains('coin') && (msg.contains('need') || msg.contains('not enough') || msg.contains('zero')));

          if (isLimit) {
            return {
              'success': false,
              'code': 'MESSAGE_LIMIT_REACHED',
              'is_limit_reached': true,
              'show_recharge_modal': true,
              'message': res?['message'] ?? 'Free limit reached. Coins required.',
              'data': res,
              'recharge_modal_data': res?['recharge_modal_data'] ??
                  (res?['data'] is Map ? (res?['data'] as Map)['recharge_modal_data'] : null) ??
                  res,
            };
          }

          return {
            'success': true,
            'data': res?['data'],
            'message': res?['message'] ?? 'Message sent successfully.',
          };
        } else {
          final String msg = (res?['message'] ?? '').toString().toLowerCase();
          final bool isLimit = response.statusCode == 402 ||
              res?['code'] == 'MESSAGE_LIMIT_REACHED' ||
              res?['is_limit_reached'] == true ||
              res?['show_recharge_modal'] == true ||
              msg.contains('limit') ||
              msg.contains('recharge') ||
              msg.contains('insufficient') ||
              msg.contains('low balance') ||
              (msg.contains('coin') && (msg.contains('need') || msg.contains('not enough') || msg.contains('zero')));

          if (isLimit) {
            return {
              'success': false,
              'code': 'MESSAGE_LIMIT_REACHED',
              'is_limit_reached': true,
              'show_recharge_modal': true,
              'message': res?['message'] ?? 'Free limit reached. Coins required.',
              'data': res,
              'recharge_modal_data': res?['recharge_modal_data'] ?? (res?['data'] is Map ? (res?['data'] as Map)['recharge_modal_data'] : null) ?? res,
            };
          } else {
            return {
              'success': false,
              'message': res?['message'] ?? 'Failed to send message (${response.statusCode})',
            };
          }
        }
      } else {
        final Map<String, dynamic> payload = {
          'receiver_id': receiverId,
          'type': type,
          if (currentUserId != null) 'user_id': currentUserId,
          if (currentUserId != null) 'sender_id': currentUserId,
        };
        if (message != null && message.isNotEmpty) {
          payload['message'] = message;
        }
        if (duration != null) {
          payload['duration'] = duration;
        }
        final body = jsonEncode(payload);

        final response = await http.post(
          uri,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: body,
        ).timeout(const Duration(seconds: 10));

        final res = _safeJsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final String msg = (res?['message'] ?? '').toString().toLowerCase();
          final bool isLimit = res?['can_message'] == false ||
              res?['show_recharge_modal'] == true ||
              res?['code'] == 'MESSAGE_LIMIT_REACHED' ||
              res?['is_limit_reached'] == true ||
              (res?['status'] == false && res?['success'] != true) ||
              msg.contains('limit') ||
              msg.contains('recharge') ||
              msg.contains('insufficient') ||
              msg.contains('low balance') ||
              (msg.contains('coin') && (msg.contains('need') || msg.contains('not enough') || msg.contains('zero')));

          if (isLimit) {
            return {
              'success': false,
              'code': 'MESSAGE_LIMIT_REACHED',
              'is_limit_reached': true,
              'show_recharge_modal': true,
              'message': res?['message'] ?? 'Free limit reached. Coins required.',
              'data': res,
              'recharge_modal_data': res?['recharge_modal_data'] ??
                  (res?['data'] is Map ? (res?['data'] as Map)['recharge_modal_data'] : null) ??
                  res,
            };
          }

          return {
            'success': true,
            'data': res?['data'],
            'message': res?['message'] ?? 'Message sent successfully.',
          };
        } else {
          final String msg = (res?['message'] ?? '').toString().toLowerCase();
          final bool isLimit = response.statusCode == 402 ||
              res?['code'] == 'MESSAGE_LIMIT_REACHED' ||
              res?['is_limit_reached'] == true ||
              res?['show_recharge_modal'] == true ||
              msg.contains('limit') ||
              msg.contains('recharge') ||
              msg.contains('insufficient') ||
              msg.contains('low balance') ||
              (msg.contains('coin') && (msg.contains('need') || msg.contains('not enough') || msg.contains('zero')));

          if (isLimit) {
            return {
              'success': false,
              'code': 'MESSAGE_LIMIT_REACHED',
              'is_limit_reached': true,
              'show_recharge_modal': true,
              'message': res?['message'] ?? 'Free limit reached. Coins required.',
              'data': res,
              'recharge_modal_data': res?['recharge_modal_data'] ?? (res?['data'] is Map ? (res?['data'] as Map)['recharge_modal_data'] : null) ?? res,
            };
          } else {
            return {
              'success': false,
              'message': res?['message'] ?? 'Failed to send message (${response.statusCode})',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] sendMessage error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Check chat permission & free message limits before typing or sending (POST /api/chat/check-permission)
  static Future<Map<String, dynamic>> checkChatPermission({
    required dynamic receiverId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final url = Uri.parse(ApiConstants.checkChatPermission);
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final payload = {
        'receiver_id': int.tryParse(receiverId.toString()) ?? receiverId,
        if (currentUserId != null) 'user_id': currentUserId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      final res = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 402) {
        if (res is Map<String, dynamic>) {
          final bool canMsg = res['can_message'] == true;
          final bool showModal = res['show_recharge_modal'] == true ||
              res['code'] == 'MESSAGE_LIMIT_REACHED' ||
              res['status'] == false ||
              !canMsg;

          return {
            'status': res['status'] ?? canMsg,
            'can_message': canMsg,
            'show_recharge_modal': showModal,
            'code': res['code'],
            'message': res['message'],
            'user_gems': res['user_gems'] ?? 0,
            'free_messages_remaining': res['free_messages_remaining'] ?? 0,
            'recharge_modal_data': res['recharge_modal_data'] ??
                (res['data'] is Map ? (res['data'] as Map)['recharge_modal_data'] : null) ??
                res,
          };
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] checkChatPermission error: $e');
    }
    return {'status': true, 'can_message': true};
  }

  /// Mark messages as read
  static Future<bool> markAsRead(dynamic senderId) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final payload = {
        'sender_id': senderId,
        if (currentUserId != null) 'user_id': currentUserId,
      };

      final response = await http.post(
        Uri.parse(ApiConstants.messagesRead),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatApiService] markAsRead error: $e');
      return false;
    }
  }

  /// Block a user (POST /api/chat/block or /api/user/block)
  static Future<Map<String, dynamic>> blockUser(dynamic targetUserId, {String? reason}) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final payload = {
        'target_user_id': targetUserId,
        'user_id': targetUserId,
        if (reason != null) 'reason': reason,
      };

      var response = await http.post(
        Uri.parse(ApiConstants.chatBlock),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        // Fallback to alias endpoint
        response = await http.post(
          Uri.parse(ApiConstants.userBlock),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));
      }

      final res = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'is_blocked': res?['is_blocked'] ?? true,
          'message': res?['message'] ?? 'Successfully blocked user.',
        };
      } else {
        return {
          'success': false,
          'message': res?['message'] ?? 'Could not block user.',
        };
      }
    } catch (e) {
      debugPrint('[ChatApiService] blockUser error: $e');
      return {
        'success': false,
        'message': 'Error blocking user: $e',
      };
    }
  }

  /// Unblock a user (POST /api/chat/unblock or /api/user/unblock)
  static Future<Map<String, dynamic>> unblockUser(dynamic targetUserId) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final payload = {
        'target_user_id': targetUserId,
        'user_id': targetUserId,
      };

      var response = await http.post(
        Uri.parse(ApiConstants.chatUnblock),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        // Fallback to alias endpoint
        response = await http.post(
          Uri.parse(ApiConstants.userUnblock),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));
      }

      final res = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'is_blocked': false,
          'message': res?['message'] ?? 'Successfully unblocked user.',
        };
      } else {
        return {
          'success': false,
          'message': res?['message'] ?? 'Could not unblock user.',
        };
      }
    } catch (e) {
      debugPrint('[ChatApiService] unblockUser error: $e');
      return {
        'success': false,
        'message': 'Error unblocking user: $e',
      };
    }
  }

  /// Get list of blocked users
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final url = Uri.parse('${ApiConstants.baseUrl}/user/blocked-list');
      var response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        final fallbackUrl = Uri.parse('${ApiConstants.baseUrl}/chat/blocked-list');
        response = await http.get(fallbackUrl, headers: headers).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final res = _safeJsonDecode(response.body);
        if (res is Map && res['data'] is List) {
          return List<Map<String, dynamic>>.from(
            (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } else if (res is List) {
          return List<Map<String, dynamic>>.from(
            res.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getBlockedUsers error: $e');
    }
    return [];
  }

  /// Submit user report (POST /api/chat/report or /api/user/report)
  static Future<Map<String, dynamic>> reportUser({
    required dynamic reportedUserId,
    required String reasonType,
    String? description,
    File? proofImage,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final currentUserId = await _getCurrentUserId();

      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      if (proofImage != null && proofImage.existsSync()) {
        final request = http.MultipartRequest('POST', Uri.parse(ApiConstants.chatReport));
        request.headers.addAll(headers);
        request.fields['reported_user_id'] = reportedUserId.toString();
        request.fields['user_id'] = reportedUserId.toString();
        request.fields['reason_type'] = reasonType;
        if (description != null && description.isNotEmpty) {
          request.fields['description'] = description;
        }
        request.files.add(await http.MultipartFile.fromPath('proof_image', proofImage.path));
        request.files.add(await http.MultipartFile.fromPath('image', proofImage.path));

        final streamed = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamed);
        final res = _safeJsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'message': res?['message'] ?? 'Thank you. Your report has been submitted.',
          };
        } else {
          return {
            'success': false,
            'message': res?['message'] ?? 'Failed to submit report (${response.statusCode})',
          };
        }
      } else {
        final payload = {
          'reported_user_id': reportedUserId,
          'user_id': reportedUserId,
          'reason_type': reasonType,
          if (description != null) 'description': description,
        };

        var response = await http.post(
          Uri.parse(ApiConstants.chatReport),
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse(ApiConstants.userReport),
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 10));
        }

        final res = _safeJsonDecode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'message': res?['message'] ?? 'Thank you. Your report has been submitted.',
          };
        } else {
          return {
            'success': false,
            'message': res?['message'] ?? 'Failed to submit report.',
          };
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] reportUser error: $e');
      return {
        'success': false,
        'message': 'Error submitting report: $e',
      };
    }
  }

  /// Get predefined report complaint categories
  static List<Map<String, String>> getPredefinedReportReasons() {
    return [
      {'key': 'sexual_content', 'title': 'Adult / Sexual related content'},
      {'key': 'harassment', 'title': 'Abuse, threat, or hate speech'},
      {'key': 'fraud_scam', 'title': 'Fraud, financial scam, or fake profile'},
      {'key': 'unreasonable_demands', 'title': 'Unreasonable demands / Harassment'},
      {'key': 'child_abuse', 'title': 'Child sexual abuse and exploitation'},
      {'key': 'other', 'title': 'Other rule violations'},
    ];
  }
}
