import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../../features/auth/services/auth_api_service.dart';
import 'fast_api_client.dart';

/// 🚀 AppPreloader: Global Instant Preloader & In-Memory Config (Zero-Loading UI)
class AppPreloader {
  static Map<String, dynamic> globalConfig = {};
  static bool _isInitialized = false;

  /// Splash Screen Startup Pre-fetch
  static Future<void> initAppData() async {
    if (_isInitialized) return;

    try {
      await FastApiClient.init();
      final token = await AuthApiService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // 1. Try to fetch /api/bootstrap-config or fallback common endpoints
      try {
        final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/bootstrap-config'), headers: headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) {
            globalConfig = Map<String, dynamic>.from(data['data'] ?? data);
          }
        }
      } catch (_) {}

      // 2. Fetch individual modules in parallel if not present in bootstrap-config
      await Future.wait([
        _fetchPaymentMethods(headers),
        _fetchGiftsCatalog(headers),
        _fetchCoinPackages(headers),
        _fetchLevelBadges(headers),
        _fetchWithdrawOptions(headers),
      ], eagerError: false).timeout(const Duration(seconds: 6), onTimeout: () => []);

      _isInitialized = true;
    } catch (e) {
      debugPrint('[AppPreloader] initAppData error: $e');
    }
  }

  static Future<void> _fetchPaymentMethods(Map<String, String> headers) async {
    if (paymentMethods.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse(ApiConstants.paymentMethods), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is Map ? (data['data'] as List?) : (data as List?);
        if (list != null) {
          globalConfig['payment_methods'] = list;
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchGiftsCatalog(Map<String, String> headers) async {
    if (gifts.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse(ApiConstants.gifts), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is Map ? (data['data'] as List?) : (data as List?);
        if (list != null) {
          globalConfig['gifts_catalog'] = list;
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchCoinPackages(Map<String, String> headers) async {
    if (coinPackages.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse(ApiConstants.coinPackages), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is Map ? (data['data'] as List?) : (data as List?);
        if (list != null) {
          globalConfig['coin_packages'] = list;
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchLevelBadges(Map<String, String> headers) async {
    if (levelBadges.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse(ApiConstants.levels), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is Map ? (data['data'] as List?) : (data as List?);
        if (list != null) {
          globalConfig['level_badges'] = list;
        }
      }
    } catch (_) {}
  }

  static Future<void> _fetchWithdrawOptions(Map<String, String> headers) async {
    if (withdrawOptions.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse(ApiConstants.withdrawInfo), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is Map ? (data['data']?['methods'] as List? ?? data['data'] as List?) : null;
        if (list != null) {
          globalConfig['withdraw_options'] = list;
        }
      }
    } catch (_) {}
  }

  static List get paymentMethods => (globalConfig['payment_methods'] as List?) ?? [];
  static List get gifts => (globalConfig['gifts_catalog'] as List?) ?? (globalConfig['gifts'] as List?) ?? [];
  static List get giftsCatalog => gifts;
  static List get coinPackages => (globalConfig['coin_packages'] as List?) ?? (globalConfig['packages'] as List?) ?? [];
  static List get levelBadges => (globalConfig['level_badges'] as List?) ?? (globalConfig['levels'] as List?) ?? [];
  static List get vipFrames => (globalConfig['vip_frames'] as List?) ?? [];
  static Map<String, dynamic> get appSettings => (globalConfig['app_settings'] as Map<String, dynamic>?) ?? {};
  static List get withdrawOptions => (globalConfig['withdraw_options'] as List?) ?? (globalConfig['withdraw_methods'] as List?) ?? (globalConfig['payment_methods'] as List?) ?? [];
  static List get withdrawMethods => withdrawOptions;
}

/// 💾 LocalDatabase: Synchronous 0-loading vault
class LocalDatabase {
  static List get paymentMethods => AppPreloader.paymentMethods;
  static List get giftsCatalog => AppPreloader.giftsCatalog;
  static List get coinPackages => AppPreloader.coinPackages;
  static List get levelBadges => AppPreloader.levelBadges;
  static List get vipFrames => AppPreloader.vipFrames;
  static Map<String, dynamic> get appSettings => AppPreloader.appSettings;
  static List get withdrawMethods => AppPreloader.withdrawMethods;
}
