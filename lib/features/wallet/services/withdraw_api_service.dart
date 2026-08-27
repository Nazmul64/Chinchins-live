import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class WithdrawApiService {
  /// 1. Get Withdrawal Configuration, Limits, User Balance & Payout Methods
  static Future<Map<String, dynamic>?> getWithdrawInfo() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.withdrawInfo);
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 12));

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
      AppLogger.error('WithdrawInfoError', e, st);
    }
    return null;
  }

  /// 2. Dynamic Real-time Calculation / Preview API
  static Future<Map<String, dynamic>?> calculateWithdrawal({required int coins}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.withdrawCalculate);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final body = jsonEncode({'coins': coins});

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('WithdrawCalculateError', e, st);
    }
    return null;
  }

  /// 3. Submit Withdrawal Request (Cash Out)
  static Future<Map<String, dynamic>> submitWithdrawal({
    required int coins,
    int? paymentMethodId,
    String? paymentMethod,
    required String accountNumber,
    String accountType = 'Personal',
    String? userNote,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.withdrawSubmit);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      String methodCode = (paymentMethod ?? 'bkash').toLowerCase().trim();
      if (methodCode.contains('bkash')) {
        methodCode = 'bkash';
      } else if (methodCode.contains('nagad')) {
        methodCode = 'nagad';
      } else if (methodCode.contains('rocket')) {
        methodCode = 'rocket';
      } else if (methodCode.contains('upay')) {
        methodCode = 'upay';
      }

      final payload = <String, dynamic>{
        'coins': coins,
        'account_number': accountNumber.trim(),
        'account_type': accountType,
        'payment_method': methodCode,
      };

      if (paymentMethodId != null) {
        payload['payment_method_id'] = paymentMethodId;
      }
      if (userId != null) {
        payload['user_id'] = userId;
      }
      if (userNote != null && userNote.trim().isNotEmpty) {
        payload['user_note'] = userNote.trim();
      }

      final body = jsonEncode(payload);

      AppLogger.request(
        method: 'POST [Withdraw Submit]',
        url: url.toString(),
        headers: headers,
        fields: payload,
      );

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

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
        AppLogger.error('WithdrawSubmitDecodeError', 'Invalid server response: ${response.body}');
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}',
        };
      }

      final isSuccess = response.statusCode == 200 ||
          response.statusCode == 201 ||
          decoded['status'] == true ||
          decoded['status'] == 'success';

      if (isSuccess) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Withdrawal request submitted successfully! Pending admin approval.',
          'data': decoded['data'],
        };
      } else {
        String errorMsg = decoded['message'] ?? 'Failed to submit withdrawal (${response.statusCode})';
        if (decoded['errors'] is Map) {
          final errMap = decoded['errors'] as Map;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null && errMap[firstKey] is List && (errMap[firstKey] as List).isNotEmpty) {
            errorMsg = (errMap[firstKey] as List).first.toString();
          }
        }
        return {
          'success': false,
          'message': errorMsg,
          'errors': decoded['errors'],
          'data': decoded['data'],
        };
      }
    } catch (e, st) {
      AppLogger.error('WithdrawSubmitException', e, st);
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// 4. Get User's Past Withdrawal History (with status badges, trxId & admin notes)
  static Future<List<Map<String, dynamic>>> getWithdrawHistory({int page = 1}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse('${ApiConstants.withdrawHistory}?page=$page');
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 12));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

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
      AppLogger.error('WithdrawHistoryError', e, st);
    }
    return [];
  }

  /// 5. Get Single Withdrawal Details
  static Future<Map<String, dynamic>?> getWithdrawDetails(int id) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.withdrawDetails(id.toString()));
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('WithdrawDetailsError', e, st);
    }
    return null;
  }
}
