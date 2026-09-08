import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/gift_item.dart';
import '../../features/auth/services/auth_api_service.dart';
import '../../features/wallet/services/wallet_api_service.dart';

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

  /// 2. Fetch In-App Gifts Store Catalog (Full metadata including categories_list & user_balance)
  static Future<Map<String, dynamic>> getGiftsCatalogFull({
    String? category,
    bool forceRefresh = false,
  }) async {
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
      var response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        uri = Uri.parse(ApiConstants.giftsStore).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200) {
        final json = _safeJsonDecode(response.body);
        if (json != null) {
          final data = json['data'] ?? json;

          // Parse user balance
          if (data['user_balance'] != null) {
            final b = data['user_balance'];
            if (b is Map && b['coins'] != null) {
              _userCoinBalance = b['coins'] is int ? b['coins'] : int.tryParse('${b['coins']}');
            } else if (b is int) {
              _userCoinBalance = b;
            }
          }

          // Parse categories list if available
          List<Map<String, dynamic>> categoriesList = [];
          if (data['categories_list'] is List) {
            categoriesList = List<Map<String, dynamic>>.from(data['categories_list']);
          } else {
            categoriesList = getPredefinedGiftCategories();
          }

          // Parse gifts list
          List? giftsJson;
          if (data['gifts'] is List) {
            giftsJson = data['gifts'] as List;
          } else if (data is List) {
            giftsJson = data;
          }

          List<GiftItem> parsedGifts = [];
          if (giftsJson != null) {
            parsedGifts = giftsJson
                .whereType<Map<String, dynamic>>()
                .map((item) => GiftItem.fromJson(item))
                .toList();
            _catalogMemCache = parsedGifts;
          }

          // Parse dynamic multipliers from API: [1, 10, 66, 99, 520, 1314]
          List<int> multipliers = [1, 10, 66, 99, 520, 1314];
          if (data['multipliers'] is List) {
            final parsedM = (data['multipliers'] as List)
                .map((m) => m is int ? m : int.tryParse('$m') ?? 0)
                .where((m) => m > 0)
                .toList();
            if (parsedM.isNotEmpty) {
              multipliers = parsedM;
            }
          }

          int defaultMultiplier = 1;
          if (data['default_multiplier'] != null) {
            defaultMultiplier = data['default_multiplier'] is int
                ? data['default_multiplier']
                : int.tryParse('${data['default_multiplier']}') ?? 1;
          }

          final effectiveCoins = _userCoinBalance ?? WalletApiService.getCachedCoins();

          return {
            'user_balance': {
              'coins': effectiveCoins,
              'formatted_coins': GiftItem.formatCoinValue(effectiveCoins),
            },
            'categories_list': categoriesList,
            'gifts': parsedGifts,
            'multipliers': multipliers,
            'default_multiplier': defaultMultiplier,
          };
        }
      }
    } catch (e) {
      debugPrint('[GiftsApiService] getGiftsCatalogFull error: $e');
    }

    final effectiveCoins = _userCoinBalance ?? WalletApiService.getCachedCoins();
    return {
      'user_balance': {
        'coins': effectiveCoins,
        'formatted_coins': GiftItem.formatCoinValue(effectiveCoins),
      },
      'categories_list': getPredefinedGiftCategories(),
      'gifts': _catalogMemCache ?? getFallbackGifts(),
      'multipliers': [1, 10, 66, 99, 520, 1314],
      'default_multiplier': 1,
    };
  }

  /// Get predefined 12 categories with colors and icons
  static List<Map<String, dynamic>> getPredefinedGiftCategories() {
    return [
      { 'key': 'all', 'label': 'All', 'emoji': '🎁', 'icon': 'fa-gift', 'color': 0xFF64748B, 'count': 160 },
      { 'key': 'hot', 'label': 'Hot', 'emoji': '🔥', 'icon': 'fa-fire', 'color': 0xFFF43F5E, 'count': 71 },
      { 'key': 'lucky', 'label': 'Lucky', 'emoji': '🍀', 'icon': 'fa-clover', 'color': 0xFF10B981, 'count': 20 },
      { 'key': 'svip', 'label': 'SVIP', 'emoji': '👑', 'icon': 'fa-crown', 'color': 0xFFF59E0B, 'count': 12 },
      { 'key': 'intimacy', 'label': 'Intimacy', 'emoji': '💖', 'icon': 'fa-heart', 'color': 0xFFEC4899, 'count': 10 },
      { 'key': 'wealth', 'label': 'Wealth', 'emoji': '💰', 'icon': 'fa-coins', 'color': 0xFFEAB308, 'count': 8 },
      { 'key': 'festival', 'label': 'Festival', 'emoji': '🎉', 'icon': 'fa-champagne-glasses', 'color': 0xFF8B5CF6, 'count': 10 },
      { 'key': 'bag', 'label': 'Bag', 'emoji': '🎒', 'icon': 'fa-bag-shopping', 'color': 0xFF06B6D4, 'count': 5 },
      { 'key': 'popular', 'label': 'Popular', 'emoji': '⭐', 'icon': 'fa-star', 'color': 0xFF3B82F6, 'count': 5 },
      { 'key': 'romantic', 'label': 'Romantic', 'emoji': '💕', 'icon': 'fa-heart-circle-bolt', 'color': 0xFFFB7185, 'count': 5 },
      { 'key': 'luxury', 'label': 'Luxury', 'emoji': '💎', 'icon': 'fa-gem', 'color': 0xFF6366F1, 'count': 5 },
      { 'key': 'effects', 'label': 'Effects/3D', 'emoji': '⚡', 'icon': 'fa-bolt', 'color': 0xFF14B8A6, 'count': 5 },
      { 'key': 'vip', 'label': 'VIP', 'emoji': '🌟', 'icon': 'fa-award', 'color': 0xFFA855F7, 'count': 4 },
    ];
  }

  /// Get fallback gifts catalog for offline / immediate load
  static List<GiftItem> getFallbackGifts() {
    return [
      const GiftItem(
        id: '1',
        giftId: 1,
        name: 'Trophy Cup',
        coins: 500,
        formattedCoins: '500',
        category: 'hot',
        badge: 'HOT',
        emoji: '🏆',
      ),
      const GiftItem(
        id: '2',
        giftId: 2,
        name: 'Mystery Box',
        coins: 888,
        formattedCoins: '888',
        category: 'hot',
        badge: 'MUST WIN',
        emoji: '📦',
      ),
      const GiftItem(
        id: '3',
        giftId: 3,
        name: 'Lucky Chest',
        coins: 1000,
        formattedCoins: '1K',
        category: 'lucky',
        badge: 'x500 WIN',
        emoji: '💎',
      ),
      const GiftItem(
        id: '4',
        giftId: 4,
        name: 'Love Letter',
        coins: 520,
        formattedCoins: '520',
        category: 'intimacy',
        badge: '520',
        emoji: '💌',
      ),
      const GiftItem(
        id: '5',
        giftId: 5,
        name: 'Bengal Tiger',
        coins: 28000,
        formattedCoins: '28K',
        category: 'svip',
        badge: 'SVIP',
        emoji: '🐯',
      ),
      const GiftItem(
        id: '6',
        giftId: 6,
        name: 'Gold Ingot',
        coins: 5000,
        formattedCoins: '5K',
        category: 'wealth',
        badge: 'RICH',
        emoji: '🪙',
      ),
      const GiftItem(
        id: '7',
        giftId: 7,
        name: 'Sky Lanterns',
        coins: 1200,
        formattedCoins: '1.2K',
        category: 'festival',
        badge: 'FESTIVAL',
        emoji: '🏮',
      ),
      const GiftItem(
        id: '8',
        giftId: 8,
        name: 'Rose Bouquet',
        coins: 99,
        formattedCoins: '99',
        category: 'popular',
        badge: 'POPULAR',
        emoji: '🌹',
      ),
      const GiftItem(
        id: '9',
        giftId: 9,
        name: 'Supercar',
        coins: 35000,
        formattedCoins: '35K',
        category: 'luxury',
        badge: 'LUXURY',
        emoji: '🏎️',
      ),
      const GiftItem(
        id: '10',
        giftId: 10,
        name: 'Fire Dragon',
        coins: 50000,
        formattedCoins: '50K',
        category: 'effects',
        badge: '3D',
        emoji: '🐉',
      ),
      const GiftItem(
        id: '11',
        giftId: 11,
        name: 'Sovereign Crown',
        coins: 75000,
        formattedCoins: '75K',
        category: 'vip',
        badge: 'KING',
        emoji: '👑',
      ),
      const GiftItem(
        id: '12',
        giftId: 12,
        name: 'Lucky Tortoise',
        coins: 200,
        formattedCoins: '200',
        category: 'bag',
        badge: 'BAG',
        emoji: '🐢',
      ),
    ];
  }

  /// 2. Fetch In-App Gifts Store Catalog
  static Future<List<GiftItem>> getGiftsCatalog({
    String? category,
    bool forceRefresh = false,
  }) async {
    final full = await getGiftsCatalogFull(category: category, forceRefresh: forceRefresh);
    if (full['gifts'] is List<GiftItem>) {
      final list = full['gifts'] as List<GiftItem>;
      if (category != null && category.isNotEmpty && category != 'all') {
        return list.where((g) => g.category.toLowerCase() == category.toLowerCase()).toList();
      }
      return list;
    }
    return _catalogMemCache ?? getFallbackGifts();
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
