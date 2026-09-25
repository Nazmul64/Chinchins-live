import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🏛️ LocalVault: High-Speed In-Memory & Local Storage Architecture (0.00ms Zero-Loading)
/// Stores global configuration, catalog, packages, and settings locally for instantaneous UI render.
class LocalVault {
  static final Map<String, dynamic> _vault = {};
  static bool _isInitialized = false;

  /// Default fallback static seeds for instant 0.00ms boot
  static final List<Map<String, dynamic>> _defaultPaymentMethods = [
    {
      'id': 1,
      'name': 'bKash',
      'code': 'bkash',
      'type': 'mobile_banking',
      'number': '01886131499',
      'account_type': 'Merchant / Personal',
      'instructions': 'Send Money or Payment to this bKash number and enter TrxID below.',
      'icon_url': 'https://chinchins.live/uploads/payment/bkash.png',
      'is_active': true,
    },
    {
      'id': 2,
      'name': 'Nagad',
      'code': 'nagad',
      'type': 'mobile_banking',
      'number': '01886131499',
      'account_type': 'Personal',
      'instructions': 'Send Money to this Nagad number and enter TrxID below.',
      'icon_url': 'https://chinchins.live/uploads/payment/nagad.png',
      'is_active': true,
    },
    {
      'id': 3,
      'name': 'Rocket',
      'code': 'rocket',
      'type': 'mobile_banking',
      'number': '01886131499',
      'account_type': 'Personal',
      'instructions': 'Send Money to this Rocket number and enter TrxID below.',
      'icon_url': 'https://chinchins.live/uploads/payment/rocket.png',
      'is_active': true,
    },
    {
      'id': 4,
      'name': 'Upay',
      'code': 'upay',
      'type': 'mobile_banking',
      'number': '01886131499',
      'account_type': 'Personal',
      'instructions': 'Send Money to this Upay number and enter TrxID below.',
      'icon_url': 'https://chinchins.live/uploads/payment/upay.png',
      'is_active': true,
    },
  ];

  static final List<Map<String, dynamic>> _defaultCoinPackages = [
    {'id': 1, 'name': 'Starter Pack', 'coins': 7560, 'bonus_coins': 0, 'total_coins': 7560, 'price': 150.0, 'price_bdt': 150.0, 'badge': '50% OFF'},
    {'id': 2, 'name': 'Basic Pack', 'coins': 8100, 'bonus_coins': 0, 'total_coins': 8100, 'price': 300.0, 'price_bdt': 300.0, 'badge': '17% OFF'},
    {'id': 3, 'name': 'Popular Pack', 'coins': 16380, 'bonus_coins': 1000, 'total_coins': 17380, 'price': 600.0, 'price_bdt': 600.0, 'badge': 'POPULAR'},
    {'id': 4, 'name': 'Super Pack', 'coins': 32940, 'bonus_coins': 3000, 'total_coins': 35940, 'price': 1200.0, 'price_bdt': 1200.0, 'badge': '30% OFF'},
    {'id': 5, 'name': 'Mega Pack', 'coins': 66600, 'bonus_coins': 8000, 'total_coins': 74600, 'price': 2400.0, 'price_bdt': 2400.0, 'badge': '60% OFF'},
    {'id': 6, 'name': 'VIP King Pack', 'coins': 167400, 'bonus_coins': 25000, 'total_coins': 192400, 'price': 6100.0, 'price_bdt': 6100.0, 'badge': '80% OFF'},
    {'id': 7, 'name': 'Whale Sovereign', 'coins': 500000, 'bonus_coins': 100000, 'total_coins': 600000, 'price': 18000.0, 'price_bdt': 18000.0, 'badge': 'KING DEAL'},
  ];

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

      // Seed defaults if not yet populated from disk
      if (!_vault.containsKey('payment_methods') || (_vault['payment_methods'] as List).isEmpty) {
        _vault['payment_methods'] = _defaultPaymentMethods;
      }
      if (!_vault.containsKey('coin_packages') || (_vault['coin_packages'] as List).isEmpty) {
        _vault['coin_packages'] = _defaultCoinPackages;
      }

      _isInitialized = true;
      debugPrint('[LocalVault] Initialized with ${_vault.keys.length} cached entities.');
    } catch (e) {
      debugPrint('[LocalVault] Init error: $e');
      _vault['payment_methods'] = _defaultPaymentMethods;
      _vault['coin_packages'] = _defaultCoinPackages;
      _isInitialized = true;
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
  static List get paymentMethods => (_vault['payment_methods'] as List?) ?? _defaultPaymentMethods;
  static List get coinPackages => (_vault['coin_packages'] as List?) ?? _defaultCoinPackages;
  static List get gifts => (_vault['gifts_catalog'] as List?) ?? [];
  static List get myBagItems => (_vault['my_bag_items'] as List?) ?? [];
  static List get vipFrames => (_vault['vip_frames'] as List?) ?? [];
  static List get weeklyCards => (_vault['weekly_cards'] as List?) ?? [];
  static List get levelBadges => (_vault['level_badges'] as List?) ?? [];
  static Map get withdrawSettings => (_vault['withdraw_settings'] as Map?) ?? {};
  static Map get appBranding => (_vault['app_branding'] as Map?) ?? {};
}
