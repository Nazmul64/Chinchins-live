import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_api_service.dart';

class MatchApiService {
  static dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Get Match tab dashboard data (waiting count, host list, caller status)
  static Future<Map<String, dynamic>?> getMatchData({
    String gender = 'female',
    int limit = 20,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse('${ApiConstants.match}?gender=$gender&limit=$limit');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final res = _safeJsonDecode(response.body);
        if (res != null && res['data'] != null) {
          return res['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[MatchApiService] getMatchData error: $e');
    }
    return null;
  }

  /// Start Instant Random Match ("Start Matching" Button)
  static Future<Map<String, dynamic>> startMatching({
    String callType = 'video',
    String gender = 'female',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(ApiConstants.matchStart);
      final body = jsonEncode({
        'call_type': callType,
        'gender': gender,
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 12));

      final res = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': res?['data'],
          'message': res?['message'] ?? 'Match found successfully.',
        };
      } else if (response.statusCode == 402) {
        return {
          'success': false,
          'code': res?['code'] ?? 'LOW_BALANCE_DEPOSIT_REQUIRED',
          'is_low_balance': true,
          'message': res?['message'] ?? 'Insufficient coin balance.',
          'required_coins': res?['required_coins'] ?? 1800,
          'current_coins': res?['current_coins'] ?? 0,
          'data': res,
        };
      } else {
        return {
          'success': false,
          'message': res?['message'] ?? 'Failed to start match (${response.statusCode})',
          'data': res,
        };
      }
    } catch (e) {
      debugPrint('[MatchApiService] startMatching error: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }
}
