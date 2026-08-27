import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class CallApiService {
  /// 1. Get Call Settings, Rates, and User Free Trial Eligibility
  static Future<Map<String, dynamic>?> getCallConfig() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callConfig);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('CallConfigError', e, st);
    }
    return null;
  }

  /// 2. Match Random Online Female Host for Instant 1-Tap Calling
  static Future<Map<String, dynamic>?> randomMatch({
    String callType = 'video',
    String gender = 'female',
    bool autoInitiate = false,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callRandomMatch);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final payload = {
        'call_type': callType,
        'gender': gender,
        'auto_initiate': autoInitiate,
      };

      AppLogger.request(
        method: 'POST [Random Match]',
        url: url.toString(),
        headers: headers,
        fields: payload,
      );

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      AppLogger.response(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('RandomMatchError', e, st);
    }
    return null;
  }

  /// 3. Initiate Call (Supports 0-Coin New User Free Trial & Balance Checks)
  static Future<Map<String, dynamic>> initiateCall({
    required dynamic receiverId,
    String callType = 'video',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callInitiate);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final payload = {
        'receiver_id': receiverId,
        'call_type': callType,
      };

      AppLogger.request(
        method: 'POST [Call Initiate]',
        url: url.toString(),
        headers: headers,
        fields: payload,
      );

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      AppLogger.response(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (e) {
        return {
          'success': false,
          'message': 'Server response error (${response.statusCode})',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'is_free_trial': decoded['data']?['is_free_trial'] == true,
          'free_duration_seconds': decoded['data']?['free_duration_seconds'] ?? 10,
          'call_id': decoded['data']?['call_id'] ?? decoded['data']?['id'],
          'channel_name': decoded['data']?['channel_name'],
          'rate_per_minute': decoded['data']?['rate_per_minute'] ?? 100,
          'data': decoded['data'],
          'message': decoded['message'] ?? 'Call initiated successfully.',
        };
      } else if (response.statusCode == 402 || decoded['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        return {
          'success': false,
          'is_low_balance': true,
          'code': 'LOW_BALANCE_DEPOSIT_REQUIRED',
          'message': decoded['message'] ?? 'Insufficient coins balance. Please recharge now.',
          'current_coins': decoded['current_coins'] ?? 0,
          'required_coins': decoded['required_coins'] ?? 100,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to initiate call (${response.statusCode})',
        };
      }
    } catch (e, st) {
      AppLogger.error('InitiateCallError', e, st);
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// 4. Connect / Start Call when receiver answers
  static Future<Map<String, dynamic>?> startCall({required int callId}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callStart);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final payload = {'call_id': callId};

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('StartCallError', e, st);
    }
    return null;
  }

  /// 5. Heartbeat Interval Pulse (Deducts coins, credits 50% to host, checks low balance)
  static Future<Map<String, dynamic>> deductIntervalPulse({
    required int callId,
    required int elapsedSeconds,
    int coins = 100,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callDeductInterval);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final payload = {
        'call_id': callId,
        'elapsed_seconds': elapsedSeconds,
        'coins': coins,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (_) {}

      if (response.statusCode == 200) {
        return {
          'success': true,
          'is_free_trial': decoded['is_free_trial'] == true,
          'free_seconds_remaining': decoded['free_seconds_remaining'] ?? 0,
          'current_coins': decoded['data']?['current_coins'],
          'coins_deducted': decoded['data']?['coins_deducted'] ?? 0,
          'host_earned_coins': decoded['data']?['host_earned_coins'] ?? 0,
          'should_terminate_call': false,
          'message': decoded['message'] ?? 'Interval processed',
        };
      } else if (response.statusCode == 402 || decoded['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        return {
          'success': false,
          'code': 'LOW_BALANCE_DEPOSIT_REQUIRED',
          'should_terminate_call': true,
          'redirect_to_deposit': true,
          'message': decoded['message'] ?? 'Your balance is insufficient to continue calling. Please deposit now.',
          'current_coins': decoded['current_coins'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'should_terminate_call': decoded['should_terminate_call'] == true,
          'message': decoded['message'] ?? 'Pulse error (${response.statusCode})',
        };
      }
    } catch (e, st) {
      AppLogger.error('DeductPulseError', e, st);
      return {
        'success': false,
        'should_terminate_call': false,
        'message': 'Pulse connection issue: $e',
      };
    }
  }

  /// 6. End Call Session
  static Future<Map<String, dynamic>?> endCall({
    required int callId,
    required int durationSeconds,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callEnd);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final payload = {
        'call_id': callId,
        'duration_seconds': durationSeconds,
      };

      AppLogger.request(
        method: 'POST [Call End]',
        url: url.toString(),
        headers: headers,
        fields: payload,
      );

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('EndCallError', e, st);
    }
    return null;
  }

  /// 7. Get User Call History
  static Future<List<Map<String, dynamic>>> getCallHistory({int page = 1}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse('${ApiConstants.callHistory}?page=$page');
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] != null) {
          if (decoded['data'] is List) {
            return List<Map<String, dynamic>>.from(decoded['data']);
          }
          if (decoded['data'] is Map && decoded['data']['data'] is List) {
            return List<Map<String, dynamic>>.from(decoded['data']['data']);
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('CallHistoryError', e, st);
    }
    return [];
  }
}
