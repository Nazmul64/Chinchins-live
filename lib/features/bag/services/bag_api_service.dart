import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/models/bag_item.dart';
import '../../../core/services/fast_api_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class BagApiService {
  static BagInventoryData? _cachedInventory;
  static List<BagStoreItem>? _cachedStoreCatalog;

  /// 1. Fetch User Bag Inventory with SWR caching (0.00ms response)
  static Future<BagInventoryData> getBagInventory({
    String category = 'all',
    String status = 'all',
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, dynamic>{
      'category': category,
      'status': status,
    };

    if (!forceRefresh && _cachedInventory != null) {
      _syncBagInventoryInBackground(queryParams);
      return _cachedInventory!;
    }

    final localCached = await FastApiClient.getCached(ApiConstants.bag, queryParams);
    if (localCached is Map && localCached['status'] == true) {
      _cachedInventory = BagInventoryData.fromJson(Map<String, dynamic>.from(localCached));
      _syncBagInventoryInBackground(queryParams);
      return _cachedInventory!;
    }

    final liveData = await _syncBagInventoryInBackground(queryParams);
    if (liveData != null) {
      return liveData;
    }

    return _getDefaultInventoryData(category, status);
  }

  static Future<BagInventoryData?> _syncBagInventoryInBackground(Map<String, dynamic> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      Uri uri = Uri.parse(ApiConstants.bag).replace(
        queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
      );

      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true) {
          await FastApiClient.putCache(ApiConstants.bag, decoded, queryParams);
          _cachedInventory = BagInventoryData.fromJson(Map<String, dynamic>.from(decoded));
          return _cachedInventory;
        }
      }
    } catch (e, st) {
      AppLogger.error('BagInventorySyncError', e, st);
    }
    return _cachedInventory;
  }

  /// 2. Fetch Store Catalog
  static Future<List<BagStoreItem>> getStoreCatalog({
    String category = 'all',
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, dynamic>{
      if (category != 'all') 'category': category,
    };

    if (!forceRefresh && _cachedStoreCatalog != null && _cachedStoreCatalog!.isNotEmpty) {
      _syncStoreCatalogInBackground(queryParams);
      return _filterCatalog(_cachedStoreCatalog!, category);
    }

    final localCached = await FastApiClient.getCached(ApiConstants.bagStore, queryParams);
    if (localCached is Map && localCached['status'] == true) {
      final root = (localCached['data'] is Map) ? localCached['data'] as Map : localCached;
      final rawList = root['items'] is List ? root['items'] as List : (localCached['items'] is List ? localCached['items'] as List : []);
      if (rawList.isNotEmpty) {
        final items = rawList.whereType<Map<String, dynamic>>().map((i) => BagStoreItem.fromJson(i)).toList();
        _cachedStoreCatalog = items;
        _syncStoreCatalogInBackground(queryParams);
        return _filterCatalog(items, category);
      }
    }

    final liveCatalog = await _syncStoreCatalogInBackground(queryParams);
    if (liveCatalog.isNotEmpty) {
      return _filterCatalog(liveCatalog, category);
    }

    return _filterCatalog(_getDefaultStoreCatalog(), category);
  }

  static List<BagStoreItem> _filterCatalog(List<BagStoreItem> list, String category) {
    if (category == 'all') return list;
    return list.where((item) => item.category.toLowerCase() == category.toLowerCase()).toList();
  }

  static Future<List<BagStoreItem>> _syncStoreCatalogInBackground(Map<String, dynamic> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      Uri uri = Uri.parse(ApiConstants.bagStore).replace(
        queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true) {
          await FastApiClient.putCache(ApiConstants.bagStore, decoded, queryParams);
          final root = (decoded['data'] is Map) ? decoded['data'] as Map : decoded;
          final rawList = root['items'] is List ? root['items'] as List : (decoded['items'] is List ? decoded['items'] as List : []);
          final items = rawList.whereType<Map<String, dynamic>>().map((i) => BagStoreItem.fromJson(i)).toList();
          _cachedStoreCatalog = items;
          return items;
        }
      }
    } catch (e, st) {
      AppLogger.error('StoreCatalogSyncError', e, st);
    }
    return _cachedStoreCatalog ?? [];
  }

  /// 3. Search Recipient User by 8-Digit Account ID or Name for Gifting
  static Future<Map<String, dynamic>?> searchUserByAccountId(String query) async {
    if (query.trim().isEmpty) return null;
    final cleanQuery = query.trim();

    try {
      final token = await AuthApiService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // 1. Try GET /api/bag/search-user?q={cleanQuery}
      final searchUrl = Uri.parse('${ApiConstants.bagSearchUser}?q=${Uri.encodeComponent(cleanQuery)}');
      final res = await http.get(searchUrl, headers: headers).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
      }

      // 2. Fallback to GET /api/search?q={cleanQuery}
      final globalSearchUrl = Uri.parse('${ApiConstants.search}?q=${Uri.encodeComponent(cleanQuery)}');
      final gRes = await http.get(globalSearchUrl, headers: headers).timeout(const Duration(seconds: 6));
      if (gRes.statusCode == 200) {
        final decoded = jsonDecode(gRes.body);
        if (decoded is Map && decoded['data'] is Map) {
          final data = decoded['data'] as Map;
          if (data['user'] is Map) {
            return Map<String, dynamic>.from(data['user']);
          }
          if (data['users'] is List && (data['users'] as List).isNotEmpty) {
            return Map<String, dynamic>.from((data['users'] as List).first);
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('BagSearchUserError', e, st);
    }
    return null;
  }

  /// 4. Gift Bag Item directly to a recipient by 8-Digit Account ID
  static Future<Map<String, dynamic>> giftItem({
    required String receiverAccountId,
    int? bagItemId,
    int? userBagItemId,
    int? receiverId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.bagGift);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final bodyMap = <String, dynamic>{
        'receiver_account_id': receiverAccountId,
      };
      if (bagItemId != null) bodyMap['bag_item_id'] = bagItemId;
      if (userBagItemId != null) bodyMap['user_bag_item_id'] = userBagItemId;
      if (receiverId != null) bodyMap['receiver_id'] = receiverId;

      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final success = response.statusCode == 200 || decoded['status'] == true;
        if (success) {
          _cachedInventory = null;
        }
        return {
          'success': success,
          'message': decoded['message'] ?? (success ? 'Gift sent successfully!' : 'Failed to send gift.'),
          'new_balance': decoded['data']?['new_coins_balance'] ?? decoded['new_balance'],
        };
      }
    } catch (e, st) {
      AppLogger.error('BagGiftError', e, st);
    }
    return {
      'success': false,
      'message': 'Failed to send gift. Please check connection and try again.',
    };
  }

  /// 5. Equip or Use Item
  static Future<Map<String, dynamic>> useOrEquipItem(int bagItemId) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.bagUse);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http
          .post(url, headers: headers, body: jsonEncode({
            'user_bag_item_id': bagItemId,
            'bag_item_id': bagItemId,
          }))
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          _cachedInventory = null;
          return {
            'success': true,
            'message': decoded['message'] ?? 'Action successful!',
            'action': decoded['action'] ?? 'equipped',
            'category': decoded['category'],
            'new_balance': decoded['new_balance'],
            'coins_added': decoded['coins_added'],
          };
        } else {
          return {
            'success': false,
            'message': decoded['message'] ?? 'Failed to use/equip item.',
          };
        }
      }
    } catch (e, st) {
      AppLogger.error('BagUseError', e, st);
    }
    return {
      'success': false,
      'message': 'Network error while equipping item.',
    };
  }

  /// 6. Unequip Item for a given Category
  static Future<Map<String, dynamic>> unequipItem(String category, {int? userBagItemId}) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.bagUnequip);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final bodyMap = <String, dynamic>{
        'category': category,
      };
      if (userBagItemId != null) bodyMap['user_bag_item_id'] = userBagItemId;

      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          _cachedInventory = null;
          return {'success': true, 'message': decoded['message'] ?? 'Item unequipped.'};
        }
      }
    } catch (e, st) {
      AppLogger.error('BagUnequipError', e, st);
    }
    return {'success': false, 'message': 'Failed to unequip item.'};
  }

  /// 7. Purchase Item from Store
  static Future<Map<String, dynamic>> purchaseItem(int itemId, {int quantity = 1}) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.bagPurchase);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'bag_item_id': itemId,
              'item_id': itemId,
              'quantity': quantity,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          _cachedInventory = null;
          return {
            'success': true,
            'message': decoded['message'] ?? 'Purchased successfully! Added to your bag.',
            'new_balance': decoded['data']?['new_coins_balance'] ?? decoded['new_balance'],
          };
        } else if (response.statusCode == 402 || decoded['code'] == 'INSUFFICIENT_FUNDS') {
          return {
            'success': false,
            'is_insufficient': true,
            'message': decoded['message'] ?? 'Insufficient gems balance.',
            'shortage': decoded['data']?['shortage'],
          };
        } else {
          return {
            'success': false,
            'message': decoded['message'] ?? 'Failed to purchase item.',
          };
        }
      }
    } catch (e, st) {
      AppLogger.error('BagPurchaseError', e, st);
    }
    return {
      'success': false,
      'message': 'Network error while purchasing item.',
    };
  }

  /// Default mock inventory fallback
  static BagInventoryData _getDefaultInventoryData(String category, String status) {
    return const BagInventoryData(
      activeCategory: 'all',
      activeStatus: 'all',
      categories: [
        BagCategory(slug: 'coupon', name: 'Coupon', nameBn: 'কুপন', icon: 'coupon', iconUrl: 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg', count: 0),
        BagCategory(slug: 'avatar_frame', name: 'Avatar frame', nameBn: 'এভাটার ফ্রেম', icon: 'avatar_frame', iconUrl: 'https://chinchins.live/uploads/my_bag/frame_royal_amethyst.svg', count: 0),
        BagCategory(slug: 'chat_style', name: 'Chat style', nameBn: 'চ্যাট স্টাইল', icon: 'chat_style', iconUrl: 'https://chinchins.live/uploads/my_bag/chat_bubble_neon_pink.svg', count: 0),
        BagCategory(slug: 'profile_card', name: 'Profile card', nameBn: 'প্রোফাইল কার্ড', icon: 'profile_card', iconUrl: 'https://chinchins.live/uploads/my_bag/profile_card_aurora_galaxy.svg', count: 0),
        BagCategory(slug: 'entrance_bubble', name: 'Entrance bubble', nameBn: 'এন্ট্রান্স বাবল', icon: 'entrance_bubble', iconUrl: 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold_crown.svg', count: 0),
        BagCategory(slug: 'big_entrance', name: 'Big entrance', nameBn: 'বিগ এন্ট্রান্স', icon: 'big_entrance', iconUrl: 'https://chinchins.live/uploads/my_bag/big_entrance_sports_car.svg', count: 0),
      ],
      counts: {'unused': 0, 'used': 0, 'expired': 0, 'total': 0},
      items: [],
    );
  }

  /// Default store catalog fallback (Clean 11 Items matching all 6 categories with production SVGs)
  static List<BagStoreItem> _getDefaultStoreCatalog() {
    return const [
      // 1. Coupon (কুপন)
      BagStoreItem(
        id: 1,
        name: '50% Off Recharge Coupon',
        category: 'coupon',
        categoryName: 'Coupon',
        priceCoins: 0,
        formattedPrice: 'Free',
        couponCoins: 0,
        badge: '50% OFF',
        imageUrl: 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg',
        daysValid: 7,
        durationText: '7 Days',
        description: 'Gives 50% extra gems on next diamond purchase.',
      ),
      BagStoreItem(
        id: 2,
        name: 'Mega Sale 500 Coin Voucher',
        category: 'coupon',
        categoryName: 'Coupon',
        priceCoins: 300,
        formattedPrice: '300 Gems',
        couponCoins: 500,
        badge: 'SALE',
        imageUrl: 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg',
        daysValid: 30,
        durationText: '30 Days',
        description: 'Instantly redeems for 500 coins in wallet.',
      ),

      // 2. Avatar frame (এভাটার ফ্রেম)
      BagStoreItem(
        id: 3,
        name: 'Royal Amethyst Frame',
        category: 'avatar_frame',
        categoryName: 'Avatar frame',
        priceCoins: 1500,
        formattedPrice: '1,500 Gems',
        badge: 'POPULAR',
        imageUrl: 'https://chinchins.live/uploads/my_bag/frame_royal_amethyst.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),
      BagStoreItem(
        id: 4,
        name: 'Royal Cyber Neon Frame',
        category: 'avatar_frame',
        categoryName: 'Avatar frame',
        priceCoins: 2500,
        formattedPrice: '2,500 Gems',
        badge: 'HOT',
        imageUrl: 'https://chinchins.live/uploads/bases/profile_base_cyber_neon.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),

      // 3. Chat style (চ্যাট স্টাইল)
      BagStoreItem(
        id: 5,
        name: 'Neon Pink Chat Bubble',
        category: 'chat_style',
        categoryName: 'Chat style',
        priceCoins: 1200,
        formattedPrice: '1,200 Gems',
        badge: 'NEW',
        imageUrl: 'https://chinchins.live/uploads/my_bag/chat_bubble_neon_pink.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),
      BagStoreItem(
        id: 6,
        name: 'Luxury Rose Gold Bubble',
        category: 'chat_style',
        categoryName: 'Chat style',
        priceCoins: 2000,
        formattedPrice: '2,000 Gems',
        badge: 'VIP',
        imageUrl: 'https://chinchins.live/uploads/my_bag/chat_bubble_gold.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),

      // 4. Profile card (প্রোফাইল কার্ড)
      BagStoreItem(
        id: 7,
        name: 'Aurora Galaxy Card',
        category: 'profile_card',
        categoryName: 'Profile card',
        priceCoins: 3500,
        formattedPrice: '3,500 Gems',
        badge: 'PREMIUM',
        imageUrl: 'https://chinchins.live/uploads/my_bag/profile_card_aurora_galaxy.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),
      BagStoreItem(
        id: 8,
        name: 'Midnight Nebula Profile Card',
        category: 'profile_card',
        categoryName: 'Profile card',
        priceCoins: 4000,
        formattedPrice: '4,000 Gems',
        imageUrl: 'https://chinchins.live/uploads/my_bag/profile_card_nebula.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),

      // 5. Entrance bubble (এন্ট্রান্স বাবল)
      BagStoreItem(
        id: 9,
        name: 'Gold Crown Entrance Bubble',
        category: 'entrance_bubble',
        categoryName: 'Entrance bubble',
        priceCoins: 5000,
        formattedPrice: '5,000 Gems',
        badge: 'ROYAL',
        imageUrl: 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold_crown.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),
      BagStoreItem(
        id: 10,
        name: 'Golden Crest Entrance Bubble',
        category: 'entrance_bubble',
        categoryName: 'Entrance bubble',
        priceCoins: 4500,
        formattedPrice: '4,500 Gems',
        imageUrl: 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold.svg',
        daysValid: 30,
        durationText: '30 Days',
      ),

      // 6. Big entrance (বিগ এন্ট্রান্স)
      BagStoreItem(
        id: 11,
        name: 'Luxury Supercar Big Entrance',
        category: 'big_entrance',
        categoryName: 'Big entrance',
        priceCoins: 12000,
        formattedPrice: '12,000 Gems',
        badge: 'SUPERCAR',
        imageUrl: 'https://chinchins.live/uploads/my_bag/big_entrance_sports_car.svg',
        daysValid: 7,
        durationText: '7 Days',
      ),
    ];
  }
}
