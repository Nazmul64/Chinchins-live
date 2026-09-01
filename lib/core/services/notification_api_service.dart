import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/app_notification.dart';
import '../utils/app_logger.dart';
import '../../features/auth/services/auth_api_service.dart';

class NotificationApiService {
  static final NotificationApiService instance = NotificationApiService._internal();
  NotificationApiService._internal();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<AppNotification>> notificationsNotifier =
      ValueNotifier<List<AppNotification>>([]);

  Timer? _pollingTimer;

  List<AppNotification> get notifications => notificationsNotifier.value;
  int get unreadCount => unreadCountNotifier.value;

  /// Start polling for real-time notification alerts
  void startNotificationPolling({Duration interval = const Duration(seconds: 15)}) {
    _pollingTimer?.cancel();
    fetchNotifications();
    _pollingTimer = Timer.periodic(interval, (_) => fetchNotifications());
  }

  void stopNotificationPolling() {
    _pollingTimer?.cancel();
  }

  /// Fetch notifications list and unread count from VPS
  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ??
          savedUser?['user_id']?.toString() ??
          savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      http.Response response;
      final url = Uri.parse(ApiConstants.notifications);

      try {
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      } catch (_) {
        final fallbackUrl = Uri.parse(ApiConstants.userNotifications);
        response = await http.get(fallbackUrl, headers: headers).timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['status'] == true || decoded['data'] != null)) {
          final data = decoded['data'];
          int unread = 0;
          List<dynamic> rawList = [];

          if (data is Map) {
            unread = data['unread_count'] is int
                ? data['unread_count']
                : int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
            if (data['notifications'] is List) {
              rawList = data['notifications'] as List;
            }
          } else if (data is List) {
            rawList = data;
          }

          final list = rawList
              .whereType<Map<String, dynamic>>()
              .map((n) => AppNotification.fromJson(n))
              .toList();

          // If unread count wasn't explicitly given, count unread items in the list
          if (unread == 0 && list.isNotEmpty) {
            unread = list.where((n) => !n.isRead).length;
          }

          unreadCountNotifier.value = unread;
          notificationsNotifier.value = list;
          return list;
        }
      }
    } catch (e, st) {
      AppLogger.error('FetchNotificationsError', e, st);
    }
    return notificationsNotifier.value;
  }

  /// Trigger test push notification for debugging / testing
  static Future<Map<String, dynamic>> testPushNotification({
    required dynamic userId,
    String type = 'incoming_call',
    String title = 'Test Call Alert 📞',
    String body = 'Incoming test video call ring from server.',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.testPushNotification);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : {'status': response.statusCode == 200};
    } catch (e, st) {
      AppLogger.error('TestPushError', e, st);
      return {'status': false, 'message': e.toString()};
    }
  }
}
