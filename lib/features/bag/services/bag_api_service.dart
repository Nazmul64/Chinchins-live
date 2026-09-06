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
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

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
    if (localCached is Map && localCached['status'] == true && localCached['items'] is List) {
      final items = (localCached['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => BagStoreItem.fromJson(i))
          .toList();
      _cachedStoreCatalog = items;
      _syncStoreCatalogInBackground(queryParams);
      return _filterCatalog(items, category);
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
        if (decoded is Map && decoded['status'] == true && decoded['items'] is List) {
          await FastApiClient.putCache(ApiConstants.bagStore, decoded, queryParams);
          final items = (decoded['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map((i) => BagStoreItem.fromJson(i))
              .toList();
          _cachedStoreCatalog = items;
          return items;
        }
      }
    } catch (e, st) {
      AppLogger.error('StoreCatalogSyncError', e, st);
    }
    return _cachedStoreCatalog ?? [];
  }

  /// 3. Equip or Use Item
  static Future<Map<String, dynamic>> useOrEquipItem(int bagItemId) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.bagUse);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode({'bag_item_id': bagItemId}))
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          // Invalidate inventory cache to refresh state
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

  /// 4. Unequip Item for a given Category
  static Future<Map<String, dynamic>> unequipItem(String category) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.bagUnequip);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode({'category': category}))
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

  /// 5. Purchase Item from Store
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
            'new_balance': decoded['new_balance'],
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
        BagCategory(slug: 'coupon', name: 'Coupon', nameBn: 'কুপন', icon: 'coupon', count: 0),
        BagCategory(slug: 'avatar_frame', name: 'Avatar frame', nameBn: 'এভাটার ফ্রেম', icon: 'avatar_frame', count: 0),
        BagCategory(slug: 'chat_style', name: 'Chat style', nameBn: 'চ্যাট স্টাইল', icon: 'chat_style', count: 0),
        BagCategory(slug: 'profile_card', name: 'Profile card', nameBn: 'প্রোফাইল কার্ড', icon: 'profile_card', count: 0),
        BagCategory(slug: 'entrance_bubble', name: 'Entrance bubble', nameBn: 'এন্ট্রান্স বাবল', icon: 'entrance_bubble', count: 0),
        BagCategory(slug: 'big_entrance', name: 'Big entrance', nameBn: 'বিগ এন্ট্রান্স', icon: 'big_entrance', count: 0),
      ],
      counts: {'unused': 0, 'used': 0, 'expired': 0, 'total': 0},
      items: [],
    );
  }

  /// Default store catalog fallback
  static List<BagStoreItem> _getDefaultStoreCatalog() {
    return const [
      BagStoreItem(
        id: 1,
        name: 'Mega Sale 500 Coin Voucher',
        category: 'coupon',
        categoryName: 'Coupon',
        priceCoins: 300,
        couponCoins: 500,
        imageUrl: 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg',
        daysValid: 30,
      ),
      BagStoreItem(
        id: 2,
        name: 'Royal Cyber Neon Frame',
        category: 'avatar_frame',
        categoryName: 'Avatar frame',
        priceCoins: 5000,
        imageUrl: 'https://chinchins.live/uploads/bases/profile_base_cyber_neon.svg',
        daysValid: 30,
      ),
      BagStoreItem(
        id: 3,
        name: 'Luxury Rose Gold Chat Bubble',
        category: 'chat_style',
        categoryName: 'Chat style',
        priceCoins: 3500,
        imageUrl: 'https://chinchins.live/uploads/my_bag/chat_bubble_gold.svg',
        daysValid: 30,
      ),
      BagStoreItem(
        id: 4,
        name: 'Midnight Nebula Profile Card',
        category: 'profile_card',
        categoryName: 'Profile card',
        priceCoins: 6000,
        imageUrl: 'https://chinchins.live/uploads/my_bag/profile_card_nebula.svg',
        daysValid: 30,
      ),
      BagStoreItem(
        id: 5,
        name: 'Golden Crest Entrance Bubble',
        category: 'entrance_bubble',
        categoryName: 'Entrance bubble',
        priceCoins: 8000,
        imageUrl: 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold.svg',
        daysValid: 30,
      ),
      BagStoreItem(
        id: 6,
        name: 'Supercar Cyber Phantom',
        category: 'big_entrance',
        categoryName: 'Big entrance',
        priceCoins: 15000,
        imageUrl: 'https://chinchins.live/uploads/my_bag/big_entrance_sports_car.svg',
        daysValid: 7,
      ),
    ];
  }
}
