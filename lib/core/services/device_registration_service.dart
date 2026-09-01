import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../utils/app_logger.dart';
import '../../features/auth/services/auth_api_service.dart';

class DeviceRegistrationService {
  static const String _prefKeyDeviceId = 'app_unique_device_id';
  static const String _prefKeyFcmToken = 'app_fcm_push_token';

  /// Generate or retrieve persistent hardware UUID
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_prefKeyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      final random = Random();
      final chars = 'abcdef0123456789';
      String generateSegment(int len) =>
          List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();

      deviceId =
          '${generateSegment(8)}-${generateSegment(4)}-${generateSegment(4)}-${generateSegment(4)}-${generateSegment(12)}';
      await prefs.setString(_prefKeyDeviceId, deviceId);
    }
    return deviceId;
  }

  /// Save FCM or Push Notification token locally
  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyFcmToken, token);
  }

  /// Get stored FCM token
  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyFcmToken);
  }

  /// Register device on the VPS server for push notifications and call wake-up
  static Future<Map<String, dynamic>?> registerDevice({
    String? fcmToken,
    dynamic userId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final effectiveUserId = userId ??
          savedUser?['id'] ??
          savedUser?['user_id'] ??
          savedUser?['account_id'];

      final deviceId = await getOrCreateDeviceId();
      final activeFcmToken = fcmToken ??
          (await getFcmToken()) ??
          'chinchins_push_token_${deviceId.substring(0, 8)}';

      String deviceType = 'android';
      if (Platform.isIOS) {
        deviceType = 'ios';
      } else if (Platform.isWindows) {
        deviceType = 'windows';
      } else if (Platform.isMacOS) {
        deviceType = 'macos';
      } else if (Platform.isLinux) {
        deviceType = 'linux';
      }

      final payload = {
        'user_id': effectiveUserId,
        'fcm_token': activeFcmToken,
        'device_type': deviceType,
        'device_brand': Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'Apple' : 'Desktop'),
        'device_model': Platform.isAndroid ? 'Android Smartphone' : (Platform.isIOS ? 'iPhone' : 'PC'),
        'os_version': Platform.operatingSystemVersion,
        'app_version': '1.0.0',
        'device_id': deviceId,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (effectiveUserId != null) 'X-User-Id': effectiveUserId.toString(),
      };

      final url = Uri.parse(ApiConstants.appDeviceRegister);
      http.Response response;

      try {
        response = await http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        final fallbackUrl = Uri.parse(ApiConstants.deviceRegister);
        response = await http
            .post(fallbackUrl, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        AppLogger.info('DeviceRegister', 'Device successfully registered: $deviceId');
        return decoded is Map<String, dynamic> ? decoded : {'status': true};
      }
    } catch (e, st) {
      AppLogger.error('DeviceRegisterError', e, st);
    }
    return null;
  }
}
