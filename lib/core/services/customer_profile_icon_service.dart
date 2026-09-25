import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../widgets/cached_image_loader.dart';

/// 📱 CustomerProfileIconService: High-Speed Local Storage & Dynamic Icon Management for "Me" Profile Screen
/// Ensures 0.00ms instantaneous local render with background ETag & SWR cache revalidation.
class CustomerProfileIconService {
  static const String _storageKey = 'local_vault_customer_profile_icons';
  static const String _versionKey = 'local_vault_customer_profile_icons_etag';
  static Map<String, Map<String, dynamic>> _iconMap = {};
  static bool _isInitialized = false;

  /// Default clean icon fallback definitions
  static const Map<String, String> _defaultIconUrls = {
    'my_gems': 'https://chinchins.live/uploads/customer_profile_icon/default_my_gems.png',
    'beans_center': 'https://chinchins.live/uploads/customer_profile_icon/default_beans_center.png',
    'spend_less_card': 'https://chinchins.live/uploads/customer_profile_icon/default_spend_less_card.png',
    'svip': 'https://chinchins.live/uploads/customer_profile_icon/default_svip.png',
    'my_bag': 'https://chinchins.live/uploads/customer_profile_icon/default_my_bag.png',
    'gems_center': 'https://chinchins.live/uploads/customer_profile_icon/default_gems_center.png',
    'payment_details': 'https://chinchins.live/uploads/customer_profile_icon/default_payment_details.png',
    'my_level': 'https://chinchins.live/uploads/customer_profile_icon/default_my_level.png',
    'sign_in': 'https://chinchins.live/uploads/customer_profile_icon/default_sign_in.png',
    'reward': 'https://chinchins.live/uploads/customer_profile_icon/default_reward.png',
  };

  /// 1. Initialize icons from local storage immediately at app launch (0.00ms)
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _iconMap = decoded.map(
            (k, v) => MapEntry(k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}),
          );
        }
      }
      _isInitialized = true;
      debugPrint('[CustomerProfileIconService] Initialized with ${_iconMap.length} profile icons.');
    } catch (e) {
      debugPrint('[CustomerProfileIconService] Init error: $e');
      _isInitialized = true;
    }
  }

  /// 2. Get icon URL with 0.00ms synchronous delay
  static String getIconUrl(String key) {
    if (_iconMap.containsKey(key)) {
      final item = _iconMap[key];
      final url = item?['icon_url'] ?? item?['image_url'] ?? item?['default_icon_url'];
      if (url != null && url.toString().trim().isNotEmpty) {
        return CachedImageLoader.normalize(url.toString().trim());
      }
    }
    final fallback = _defaultIconUrls[key];
    return fallback != null ? CachedImageLoader.normalize(fallback) : '';
  }

  /// 3. Get item metadata (title, badge_text, badge_color)
  static Map<String, dynamic>? getIconData(String key) {
    return _iconMap[key];
  }

  /// 4. Synchronize all 10 icons in background via /api/customer-profile-icons with ETag
  static Future<void> syncIconsBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEtag = prefs.getString(_versionKey) ?? '';

      final uri = Uri.parse(ApiConstants.customerProfileIcons);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (currentEtag.isNotEmpty) 'If-None-Match': currentEtag,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 304) {
        debugPrint('[CustomerProfileIconService] Cache validated (304 Not Modified).');
        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['success'] == true || decoded['status'] == true)) {
          final data = decoded['data'];
          final etag = response.headers['etag'] ?? data?['version_hash'] ?? '';
          
          final Map<String, Map<String, dynamic>> newMap = {};
          
          if (data is Map && data['map'] is Map) {
            final rawMap = data['map'] as Map;
            for (final entry in rawMap.entries) {
              if (entry.value is Map) {
                newMap[entry.key.toString()] = Map<String, dynamic>.from(entry.value as Map);
              }
            }
          } else if (data is Map && data['icons'] is List) {
            for (final item in data['icons']) {
              if (item is Map && item['key'] != null) {
                newMap[item['key'].toString()] = Map<String, dynamic>.from(item);
              }
            }
          } else if (decoded['icons'] is List) {
            for (final item in decoded['icons']) {
              if (item is Map && item['key'] != null) {
                newMap[item['key'].toString()] = Map<String, dynamic>.from(item);
              }
            }
          }

          if (newMap.isNotEmpty) {
            _iconMap = newMap;
            await prefs.setString(_storageKey, jsonEncode(newMap));
            if (etag.isNotEmpty) {
              await prefs.setString(_versionKey, etag);
            }
            debugPrint('[CustomerProfileIconService] Successfully cached ${newMap.length} dynamic profile icons.');
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomerProfileIconService] Sync error (using local cache): $e');
    }
  }
}
