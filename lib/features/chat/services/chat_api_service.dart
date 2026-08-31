import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
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

  /// Get conversations list (Inbox) - Real Dynamic Server Data
  static Future<Map<String, dynamic>?> getConversations() async {
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
          return data;
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getConversations error: $e');
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
        }
        if (duration != null) {
          request.fields['duration'] = duration.toString();
        }

        if (voiceFile != null && voiceFile.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('voice_file', voiceFile.path));
        }
        if (imageFile != null && imageFile.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);
        final res = _safeJsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'data': res?['data'],
            'message': res?['message'] ?? 'Message sent successfully.',
          };
        } else if (response.statusCode == 402) {
          return {
            'success': false,
            'code': res?['code'] ?? 'MESSAGE_LIMIT_REACHED',
            'is_limit_reached': true,
            'message': res?['message'] ?? 'Free limit reached. Coins required.',
            'data': res,
          };
        } else {
          return {
            'success': false,
            'message': res?['message'] ?? 'Failed to send message (${response.statusCode})',
          };
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
          return {
            'success': true,
            'data': res?['data'],
            'message': res?['message'] ?? 'Message sent successfully.',
          };
        } else if (response.statusCode == 402) {
          return {
            'success': false,
            'code': res?['code'] ?? 'MESSAGE_LIMIT_REACHED',
            'is_limit_reached': true,
            'message': res?['message'] ?? 'Free limit reached. Coins required.',
            'data': res,
          };
        } else {
          return {
            'success': false,
            'message': res?['message'] ?? 'Failed to send message (${response.statusCode})',
          };
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
}
