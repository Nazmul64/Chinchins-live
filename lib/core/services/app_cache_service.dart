import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/gift_item.dart';
import '../../features/auth/services/auth_api_service.dart';
import '../../features/wallet/models/payment_option_model.dart';
import '../../features/wallet/services/wallet_api_service.dart';
import 'gifts_api_service.dart';

/// ⚡ AppCacheService: High-Speed In-Memory & Local RAM Cache (<1ms)
/// Pre-fetches catalog, gateways, packages, and user profiles at launch for Zero-Loading UI.
class AppCacheService {
  static List<GiftItem> cachedGifts = [];
  static Map<int, GiftItem> giftMap = {};
  static List<PaymentOption> cachedGateways = [];
  static List<Map<String, dynamic>> cachedPackages = [];
  static Map<String, dynamic>? cachedUserProfile;
  static bool isPreloaded = false;

  /// 🚀 App Launch Pre-fetching (Runs in background without blocking app startup)
  static Future<void> prefetchAllStaticData() async {
    if (isPreloaded) return;

    try {
      // 1. Preload gifts from memory/fallback immediately
      cachedGifts = GiftsApiService.cachedCatalog ?? GiftsApiService.getFallbackGifts();
      if (cachedGifts.isEmpty) {
        cachedGifts = GiftsApiService.getFallbackGifts();
      }
      _rebuildGiftMap();

      // 2. Parallel background API calls for latest catalog & gateways
      final token = await AuthApiService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      await Future.wait([
        // A. Gifts Catalog (Zero-DB Hit Cache from /api/gifts/catalog)
        _fetchGiftsCatalog(headers),
        // B. Payment Gateways (/api/payment/gateways or /api/payment-options)
        _fetchPaymentGateways(headers),
        // C. Coin Packages
        _fetchCoinPackages(headers),
      ], eagerError: false).timeout(const Duration(seconds: 6), onTimeout: () => []);

      isPreloaded = true;
      debugPrint('[AppCacheService] Pre-fetch complete. Cached ${cachedGifts.length} gifts, ${cachedGateways.length} gateways.');
    } catch (e) {
      debugPrint('[AppCacheService] Pre-fetch non-fatal warning: $e');
    }
  }

  static void _rebuildGiftMap() {
    giftMap = {
      for (var g in cachedGifts) (g.giftId > 0 ? g.giftId : int.tryParse(g.id) ?? 0): g
    };
  }

  static Future<void> _fetchGiftsCatalog(Map<String, String> headers) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.gifts), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List? list;
        if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }

        if (list != null && list.isNotEmpty) {
          cachedGifts = list.map((e) => GiftItem.fromJson(e as Map<String, dynamic>)).toList();
          _rebuildGiftMap();
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchPaymentGateways(Map<String, String> headers) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.paymentOptions), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List? list;
        if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }

        if (list != null && list.isNotEmpty) {
          cachedGateways = list.map((e) => PaymentOption.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchCoinPackages(Map<String, String> headers) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.coinPackages), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List? list;
        if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }

        if (list != null && list.isNotEmpty) {
          cachedPackages = List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}
  }

  /// 🎁 Optimistic Gift Trigger: Instantly updates local UI, fires background API
  static Future<Map<String, dynamic>> triggerOptimisticGiftSend({
    required dynamic receiverId,
    required GiftItem gift,
    int quantity = 1,
    String? streamId,
    dynamic callSessionId,
    String contextType = 'live',
  }) async {
    final totalCost = gift.coins * quantity;
    final currentCoins = WalletApiService.getCachedCoins();

    // 1. Check local balance
    if (currentCoins < totalCost) {
      return {'success': false, 'status': false, 'code': 'INSUFFICIENT_BALANCE', 'message': 'Low coin balance. Please recharge.'};
    }

    // 2. Optimistically deduct local coin balance
    WalletApiService.updateCachedCoins(currentCoins - totalCost);

    // 3. Dispatch background API call (<35ms endpoint)
    final giftId = gift.giftId > 0 ? gift.giftId : int.tryParse(gift.id) ?? 1;
    unawaited(
      GiftsApiService.sendGift(
        receiverId: receiverId,
        giftId: giftId,
        quantity: quantity,
        context: contextType,
        streamId: streamId,
        callSessionId: callSessionId,
      ).then((res) {
        if (res['status'] == false && (res['code'] == 'INSUFFICIENT_BALANCE' || res['code'] == 402 || res['code'] == 422)) {
          // Revert balance on actual server failure
          WalletApiService.updateCachedCoins(currentCoins);
        }
      }).catchError((_) {
        // Network failure fallback
      }),
    );

    return {'success': true, 'status': true, 'remaining_coins': currentCoins - totalCost};
  }
}
