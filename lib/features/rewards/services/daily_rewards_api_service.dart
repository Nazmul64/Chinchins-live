import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import '../models/daily_reward_model.dart';

class DailyRewardsApiService {
  static DailyRewardStatus? _cachedStatus;
  static DailyRewardStatus? get cachedStatus => _cachedStatus;

  /// ValueNotifier so UI across the app can react instantly when rewards or coins update
  static final ValueNotifier<DailyRewardStatus?> statusNotifier = ValueNotifier<DailyRewardStatus?>(null);

  /// Fetch the user's 7-day daily check-in status from Laravel API
  static Future<DailyRewardStatus?> getDailyRewardsStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStatus != null) {
      return _cachedStatus;
    }

    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      };

      // 1. Primary Endpoint: GET /api/daily-rewards/status
      http.Response response;
      try {
        response = await http.get(
          Uri.parse(ApiConstants.dailyRewardsStatus),
          headers: headers,
        ).timeout(const Duration(seconds: 7));
      } catch (_) {
        // Fallback 1: GET /api/daily-claim/status
        try {
          response = await http.get(
            Uri.parse(ApiConstants.dailyClaimStatus),
            headers: headers,
          ).timeout(const Duration(seconds: 5));
        } catch (_) {
          // Fallback 2: GET /api/daily-checkin/status
          response = await http.get(
            Uri.parse(ApiConstants.dailyCheckinStatus),
            headers: headers,
          ).timeout(const Duration(seconds: 5));
        }
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = (decoded['data'] is Map) ? Map<String, dynamic>.from(decoded['data']) : decoded;
          final status = DailyRewardStatus.fromJson(data);
          _cachedStatus = status;
          statusNotifier.value = status;
          return status;
        }
      }
    } catch (e, st) {
      AppLogger.error('DailyRewardsApiService.getDailyRewardsStatus error', e, st);
    }

    return _cachedStatus;
  }

  /// Claim today's daily reward (+50 / +100 coins)
  static Future<Map<String, dynamic>> claimDailyReward() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      };

      // 1. Primary Endpoint: POST /api/daily-rewards/claim
      http.Response response;
      try {
        response = await http.post(
          Uri.parse(ApiConstants.dailyRewardsClaim),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Fallback: POST /api/daily-claim/claim
        response = await http.post(
          Uri.parse(ApiConstants.dailyClaimClaim),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          // Refresh status in background
          getDailyRewardsStatus(forceRefresh: true);
          return {
            'status': true,
            'success': true,
            'message': decoded['message'] ?? 'Claimed successfully!',
            'claimed_day': decoded['claimed_day'] ?? decoded['day'] ?? _cachedStatus?.nextDayNumber,
            'coins_awarded': decoded['coins_awarded'] ?? decoded['coins'] ?? 50,
            'total_balance': decoded['total_balance'] ?? decoded['user_current_coins'] ?? decoded['current_coins'],
            'next_claim_at': decoded['next_claim_at'] ?? decoded['next_available_at'],
          };
        }
      } else if (response.statusCode == 422 || response.statusCode == 400) {
        final decoded = jsonDecode(response.body);
        return {
          'status': false,
          'success': false,
          'message': decoded['message'] ?? 'Please wait 12 hours before claiming next reward.',
          'next_available_at': decoded['next_available_at'] ?? decoded['next_claim_at'],
        };
      }
    } catch (e, st) {
      AppLogger.error('DailyRewardsApiService.claimDailyReward error', e, st);
    }

    return {
      'status': false,
      'success': false,
      'message': 'Failed to connect to reward server. Please try again.',
    };
  }
}
