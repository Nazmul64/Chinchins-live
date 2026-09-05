import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/gift_item.dart';
import '../../features/auth/services/auth_api_service.dart';

class GiftsApiService {
  // In-Memory Fast Caches for Zero-Lag Instant Rendering
  static final Map<String, UserGiftsData> _receivedGiftsMemCache = {};
  static List<GiftItem>? _catalogMemCache;
  static Map<String, int> _categoriesMemCache = {};
  static int? _userCoinBalance;

  /// Safe JSON decode
  static dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Get cached received gifts instantly without waiting for network
  static UserGiftsData? getCachedReceivedGifts(String userId) {
    return _receivedGiftsMemCache[userId];
  }

  /// Get cached catalog instantly
  static List<GiftItem>? get cachedCatalog => _catalogMemCache;
  static int? get cachedUserCoins => _userCoinBalance;

  /// 1. Fetch User Received Gifts, Charm Level, Top Fan, and Summary
  static Future<UserGiftsData?> getReceivedGifts(
    dynamic userId, {
    bool forceRefresh = false,
  }) async {
    final key = userId.toString();

    // If cache exists and no forceRefresh, return immediately for instant response
    if (!forceRefresh && _receivedGiftsMemCache.containsKey(key)) {
      // Trigger background silent refresh without blocking UI
      _silentRefreshReceivedGifts(key);
      return _receivedGiftsMemCache[key];
    }

    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Primary URL
      Uri uri = Uri.parse(ApiConstants.giftsReceived(key));
      http.Response response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 404) {
        // Fallback endpoint: /api/profile/{userId}/gifts
        uri = Uri.parse(ApiConstants.profileGifts(key));
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null && data['status'] == true && data['data'] != null) {
          final result = UserGiftsData.fromJson(data);
          _receivedGiftsMemCache[key] = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] getReceivedGifts error: $e');
    }

    // Return memory cache fallback if network failed
    return _receivedGiftsMemCache[key];
  }

  /// Silent background refresher
  static void _silentRefreshReceivedGifts(String userId) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      Uri uri = Uri.parse(ApiConstants.giftsReceived(userId));
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null && data['status'] == true && data['data'] != null) {
          _receivedGiftsMemCache[userId] = UserGiftsData.fromJson(data);
        }
      }
    } catch (_) {}
  }

  /// 2. Fetch In-App Gifts Store Catalog
  static Future<List<GiftItem>> getGiftsCatalog({
    String? category,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _catalogMemCache != null && _catalogMemCache!.isNotEmpty) {
      if (category != null && category.isNotEmpty && category != 'all') {
        return _catalogMemCache!.where((g) => g.category.toLowerCase() == category.toLowerCase()).toList();
      }
      return _catalogMemCache!;
    }

    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }

      Uri uri = Uri.parse(ApiConstants.giftsCatalog).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = _safeJsonDecode(response.body);
        if (json != null) {
          final data = json['data'] ?? json;

          // Parse user balance
          if (data['user_balance'] != null && data['user_balance']['coins'] != null) {
            _userCoinBalance = data['user_balance']['coins'] is int
                ? data['user_balance']['coins']
                : int.tryParse('${data['user_balance']['coins']}');
          }

          // Parse categories
          if (data['categories'] is Map<String, dynamic>) {
            _categoriesMemCache = Map<String, int>.from(data['categories']);
          }

          // Parse gifts list
          List? giftsJson;
          if (data['gifts'] is List) {
            giftsJson = data['gifts'] as List;
          } else if (data is List) {
            giftsJson = data;
          }

          if (giftsJson != null) {
            final parsedGifts = giftsJson
                .whereType<Map<String, dynamic>>()
                .map((item) => GiftItem.fromJson(item))
                .toList();

            _catalogMemCache = parsedGifts;
            if (category != null && category.isNotEmpty && category != 'all') {
              return parsedGifts.where((g) => g.category.toLowerCase() == category.toLowerCase()).toList();
            }
            return parsedGifts;
          }
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] getGiftsCatalog error: $e');
    }

    return _catalogMemCache ?? [];
  }

  /// 3. Send Gift to Host / User (Supports Live Stream Reverb Broadcast)
  static Future<Map<String, dynamic>> sendGift({
    required dynamic receiverId,
    required dynamic giftId,
    int quantity = 1,
    String context = 'profile',
    String? streamId,
    dynamic callSessionId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) {
        return {
          'status': false,
          'message': 'Please login to send gifts.',
        };
      }

      final payload = <String, dynamic>{
        'receiver_id': receiverId is int ? receiverId : int.tryParse('$receiverId') ?? receiverId,
        'gift_id': giftId is int ? giftId : int.tryParse('$giftId') ?? giftId,
        'quantity': quantity,
        'context': context,
        if (streamId != null && streamId.isNotEmpty) 'stream_id': streamId,
        if (callSessionId != null) 'call_session_id': callSessionId,
      };

      Uri uri = Uri.parse(ApiConstants.sendGift);
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(response.body);
      if (data != null && data is Map<String, dynamic>) {
        if (response.statusCode == 200 && (data['status'] == true || data['status'] == 'true')) {
          // Invalidate cache for receiver so their profile updates immediately
          _receivedGiftsMemCache.remove(receiverId.toString());

          // Update sender remaining coins if provided
          if (data['remaining_balance'] != null) {
            _userCoinBalance = data['remaining_balance'] is int
                ? data['remaining_balance']
                : int.tryParse('${data['remaining_balance']}');
          } else if (data['data']?['sender']?['remaining_coins'] != null) {
            _userCoinBalance = data['data']['sender']['remaining_coins'] is int
                ? data['data']['sender']['remaining_coins']
                : int.tryParse('${data['data']['sender']['remaining_coins']}');
          }

          return data;
        } else {
          return {
            'status': false,
            'message': data['message'] ?? 'Failed to send gift.',
            'code': response.statusCode,
            'shortage': data['shortage'],
          };
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] sendGift error: $e');
      return {
        'status': false,
        'message': 'Error sending gift: $e',
      };
    }

    return {
      'status': false,
      'message': 'Unable to connect to gifts server.',
    };
  }

  /// 4. Get Host's Top Fans Leaderboard
  static Future<List<Map<String, dynamic>>> getTopFans(dynamic userId) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(ApiConstants.profileTopFans(userId));
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null && data['data'] != null && data['data']['top_fans'] is List) {
          return List<Map<String, dynamic>>.from(data['data']['top_fans']);
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] getTopFans error: $e');
    }
    return [];
  }

  /// 5. Send Love / Like Heart to Host
  static Future<Map<String, dynamic>?> sendLike({
    required dynamic userId,
    int count = 1,
    String context = 'call',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(ApiConstants.profileLike(userId));
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'count': count,
          'context': context,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] sendLike error: $e');
    }
    return null;
  }

  /// Invalidate all memory caches
  static void clearCache() {
    _receivedGiftsMemCache.clear();
    _catalogMemCache = null;
    _categoriesMemCache.clear();
    _userCoinBalance = null;
  }
}
