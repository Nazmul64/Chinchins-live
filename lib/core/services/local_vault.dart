import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🏛️ LocalVault: High-Speed In-Memory & Local Storage Architecture (0.00ms Zero-Loading)
/// Stores global configuration, catalog, packages, and settings locally for instantaneous UI render.
class LocalVault {
  static final Map<String, dynamic> _vault = {};
  static bool _isInitialized = false;

  /// Initialize local vault from device disk cache at app start
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        'payment_methods',
        'coin_packages',
        'gifts_catalog',
        'my_bag_items',
        'vip_frames',
        'weekly_cards',
        'level_badges',
        'withdraw_settings',
        'app_branding',
      ];

      for (final key in keys) {
        final raw = prefs.getString('local_vault_$key');
        if (raw != null && raw.isNotEmpty) {
          try {
            _vault[key] = jsonDecode(raw);
          } catch (_) {}
        }
      }
      _isInitialized = true;
      debugPrint('[LocalVault] Initialized with ${_vault.keys.length} cached entities.');
    } catch (e) {
      debugPrint('[LocalVault] Init error: $e');
    }
  }

  /// Sync all bootstrap data in background at app launch (from /api/bootstrap-config)
  static Future<void> syncBootstrapData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      void put(String key, dynamic val) {
        if (val != null) {
          _vault[key] = val;
          prefs.setString('local_vault_$key', jsonEncode(val));
        }
      }

      put('payment_methods', data['payment_methods']);
      put('coin_packages', data['coin_packages']);
      put('gifts_catalog', data['gifts_catalog'] ?? data['gifts']);
      put('my_bag_items', data['my_bag_items'] ?? data['bag_items']);
      put('vip_frames', data['vip_frames']);
      put('weekly_cards', data['weekly_cards']);
      put('level_badges', data['level_badges']);
      put('withdraw_settings', data['withdrawal_settings'] ?? data['withdraw_settings']);
      put('app_branding', data['app_settings'] ?? data['app_branding']);

      debugPrint('[LocalVault] Bootstrap synchronized to local disk and memory.');
    } catch (e) {
      debugPrint('[LocalVault] Sync error: $e');
    }
  }

  // Synchronous getters (0.00ms execution, no Future or await required)
  static List get paymentMethods => (_vault['payment_methods'] as List?) ?? [];
  static List get coinPackages => (_vault['coin_packages'] as List?) ?? [];
  static List get gifts => (_vault['gifts_catalog'] as List?) ?? [];
  static List get myBagItems => (_vault['my_bag_items'] as List?) ?? [];
  static List get vipFrames => (_vault['vip_frames'] as List?) ?? [];
  static List get weeklyCards => (_vault['weekly_cards'] as List?) ?? [];
  static List get levelBadges => (_vault['level_badges'] as List?) ?? [];
  static Map get withdrawSettings => (_vault['withdraw_settings'] as Map?) ?? {};
  static Map get appBranding => (_vault['app_branding'] as Map?) ?? {};
}
