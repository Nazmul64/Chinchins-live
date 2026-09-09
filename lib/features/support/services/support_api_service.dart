import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import '../models/support_message_model.dart';

class SupportApiService {
  static List<SupportMessageModel> _cachedMessages = [];

  /// 1. Fetch Message History between Current User & Admin Support
  static Future<List<SupportMessageModel>> getSupportMessages() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final currentUserId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.supportMessages);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List? rawList;
        if (decoded is Map && decoded['data'] is List) {
          rawList = decoded['data'] as List;
        } else if (decoded is List) {
          rawList = decoded;
        }

        if (rawList != null) {
          final list = rawList
              .map((e) => SupportMessageModel.fromJson(
                    Map<String, dynamic>.from(e),
                    currentUserId: currentUserId,
                  ))
              .toList();
          _cachedMessages = list;
          return list;
        }
      }
    } catch (e, st) {
      AppLogger.error('SupportGetMessagesError', e, st);
    }
    return _cachedMessages;
  }

  /// 2. Send Message (Text, Screenshot/Image, Voice Note) to Admin Support
  static Future<SupportMessageModel?> sendMessage({
    String? message,
    String type = 'text',
    File? imageFile,
    File? audioFile,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final currentUserId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.supportSend);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (currentUserId != null) request.headers['X-User-Id'] = currentUserId;

      request.fields['type'] = type;
      if (message != null && message.trim().isNotEmpty) {
        request.fields['message'] = message.trim();
      }

      if (imageFile != null && imageFile.existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
        request.files.add(await http.MultipartFile.fromPath('screenshot', imageFile.path));
      }

      if (audioFile != null && audioFile.existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('voice', audioFile.path));
        request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is Map) {
          final msg = SupportMessageModel.fromJson(
            Map<String, dynamic>.from(decoded['data']),
            currentUserId: currentUserId,
          );
          _cachedMessages.add(msg);
          return msg;
        }
      }
    } catch (e, st) {
      AppLogger.error('SupportSendMessageError', e, st);
    }
    return null;
  }

  /// 3. Upload Media Attachment Standalone Endpoint (stored in uploads/admin_support_for_user/)
  static Future<String?> uploadMedia(File file) async {
    try {
      final token = await AuthApiService.getToken();
      final uri = Uri.parse(ApiConstants.supportUpload);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          String? media = decoded['media_url']?.toString() ??
              decoded['url']?.toString() ??
              decoded['relative_path']?.toString();
          if (media != null && media.isNotEmpty) {
            if (!media.startsWith('http://') && !media.startsWith('https://')) {
              if (media.startsWith('/')) {
                media = 'https://chinchins.live$media';
              } else {
                media = 'https://chinchins.live/$media';
              }
            }
            return media;
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('SupportUploadMediaError', e, st);
    }
    return null;
  }

  /// 4. Get Unread Admin Support Messages Counter
  static Future<int> getUnreadCount() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final currentUserId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.supportUnreadCount);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['unread_count'] != null) {
          return int.tryParse('${decoded['unread_count']}') ?? 0;
        }
      }
    } catch (e, st) {
      AppLogger.error('SupportUnreadCountError', e, st);
    }
    return 0;
  }
}
