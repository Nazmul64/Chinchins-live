import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/fast_api_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class LevelBasesApiService {
  static List<Map<String, dynamic>> _cachedBases = [];

  /// Fetch master list of all Level Bases & Avatar Frames (Instant SWR)
  static Future<List<Map<String, dynamic>>> getAllProfileBases() async {
    if (_cachedBases.isNotEmpty) {
      _syncProfileBasesInBackground();
      return _cachedBases;
    }

    final localCached = await FastApiClient.getCached(ApiConstants.profileBases);
    if (localCached is Map && localCached['status'] == true && localCached['data'] is List) {
      _cachedBases = (localCached['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      _syncProfileBasesInBackground();
      return _cachedBases;
    }

    final liveBases = await _syncProfileBasesInBackground();
    if (liveBases.isNotEmpty) {
      return liveBases;
    }

    return _getDefaultLevelBases();
  }

  static Future<List<Map<String, dynamic>>> _syncProfileBasesInBackground() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileBases);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is List) {
          await FastApiClient.putCache(ApiConstants.profileBases, decoded);
          _cachedBases = (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          return _cachedBases;
        }
      }
    } catch (e, st) {
      AppLogger.error('GetAllProfileBasesError', e, st);
    }
    return _cachedBases;
  }

  /// Fetch User Level status & progression stats (Instant SWR)
  static Future<Map<String, dynamic>?> getUserLevelStatus({
    String? userId,
    String? accountId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      String urlStr = ApiConstants.levelStatus;
      if (userId != null && userId.isNotEmpty) {
        urlStr += '?user_id=$userId';
      } else if (accountId != null && accountId.isNotEmpty) {
        urlStr += '?account_id=$accountId';
      }

      final cached = await FastApiClient.getCached(urlStr);
      if (cached is Map && cached['status'] == true && cached['data'] is Map) {
        // Asynchronously update in background
        _syncUserLevelStatusInBackground(urlStr, token);
        return Map<String, dynamic>.from(cached['data']);
      }

      return await _syncUserLevelStatusInBackground(urlStr, token);
    } catch (e, st) {
      AppLogger.error('GetUserLevelStatusError', e, st);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _syncUserLevelStatusInBackground(String urlStr, String? token) async {
    try {
      final url = Uri.parse(urlStr);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          await FastApiClient.putCache(urlStr, decoded);
          return Map<String, dynamic>.from(decoded['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get default SVG frame URL for a given level
  static String getFrameUrlForLevel(int level) {
    final bases = _getDefaultLevelBases();
    final match = bases.firstWhere(
      (b) => b['level'] == level,
      orElse: () {
        // Find highest level <= target
        Map<String, dynamic> fallback = bases.first;
        for (final b in bases) {
          if ((b['level'] as int) <= level) {
            fallback = b;
          }
        }
        return fallback;
      },
    );
    return match['frame_image_url'] as String;
  }

  static List<Map<String, dynamic>> _getDefaultLevelBases() {
    return [
      {
        'id': 1,
        'level': 0,
        'name': 'Level 0 - Novice Cadet Standard',
        'required_coins': 0,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_novice_cadet.svg',
        'badge_icon': 'user',
        'badge_color': '#94a3b8',
        'glow_color': 'rgba(148, 163, 184, 0.3)',
        'privilege_text': 'Standard Profile Frame',
        'is_active': true,
      },
      {
        'id': 2,
        'level': 1,
        'name': 'Level 1 - Bronze Star Starter',
        'required_coins': 1000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_bronze_star.svg',
        'badge_icon': 'star',
        'badge_color': '#f97316',
        'glow_color': 'rgba(249, 115, 22, 0.45)',
        'privilege_text': 'Bronze Star Starter Avatar Frame',
        'is_active': true,
      },
      {
        'id': 3,
        'level': 2,
        'name': 'Level 2 - Fatima Dollar Ring Rich Gold',
        'required_coins': 5000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_dollar_ring.svg',
        'badge_icon': 'gem',
        'badge_color': '#10b981',
        'glow_color': 'rgba(16, 185, 129, 0.5)',
        'privilege_text': 'Dollar Ring Gold Laurel & Coin Glow',
        'is_active': true,
      },
      {
        'id': 4,
        'level': 3,
        'name': 'Level 3 - Maryam Circus Gentleman Rich',
        'required_coins': 15000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_circus_gentleman.svg',
        'badge_icon': 'crown',
        'badge_color': '#f59e0b',
        'glow_color': 'rgba(245, 158, 11, 0.55)',
        'privilege_text': 'Circus Gentleman Gold Hat & Rich Ribbon',
        'is_active': true,
      },
      {
        'id': 5,
        'level': 4,
        'name': 'Level 4 - Abdul TOP 3 Stage Spotlight',
        'required_coins': 50000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_top3_spotlight.svg',
        'badge_icon': 'bolt',
        'badge_color': '#a855f7',
        'glow_color': 'rgba(168, 85, 247, 0.6)',
        'privilege_text': 'Top 3 Purple Stage Spotlight Frame',
        'is_active': true,
      },
      {
        'id': 6,
        'level': 5,
        'name': 'Level 5 - Momo Blue Captain Sailor Wheel',
        'required_coins': 150000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_blue_captain.svg',
        'badge_icon': 'shield',
        'badge_color': '#00f0ff',
        'glow_color': 'rgba(0, 240, 255, 0.65)',
        'privilege_text': 'Blue Captain Ship Steering Wheel & Anchor Frame',
        'is_active': true,
      },
      {
        'id': 7,
        'level': 6,
        'name': 'Level 6 - Omar Devil Horns Flame Crest',
        'required_coins': 350000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_devil_horns.svg',
        'badge_icon': 'fire',
        'badge_color': '#ef4444',
        'glow_color': 'rgba(239, 68, 68, 0.7)',
        'privilege_text': 'Flaming Devil Horns & Crimson Red Ruby Frame',
        'is_active': true,
      },
      {
        'id': 8,
        'level': 7,
        'name': 'Level 7 - Amir Cricket Superstar Gold',
        'required_coins': 800000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_cricket_superstar.svg',
        'badge_icon': 'star',
        'badge_color': '#eab308',
        'glow_color': 'rgba(234, 179, 8, 0.75)',
        'privilege_text': 'Cricket Superstar Gold Helmet, Bat & Ball Frame',
        'is_active': true,
      },
      {
        'id': 9,
        'level': 8,
        'name': 'Level 8 - Zainab Cyber Neon Speedometer',
        'required_coins': 1500000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_cyber_speedometer.svg',
        'badge_icon': 'bolt',
        'badge_color': '#06b6d4',
        'glow_color': 'rgba(6, 182, 212, 0.8)',
        'privilege_text': 'Cyber Speedometer Cyan Shield & Neon Aura Frame',
        'is_active': true,
      },
      {
        'id': 10,
        'level': 9,
        'name': 'Level 9 - Priya Luxury Rose Garden Queen',
        'required_coins': 3000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_rose_garden.svg',
        'badge_icon': 'heart',
        'badge_color': '#ec4899',
        'glow_color': 'rgba(236, 72, 153, 0.85)',
        'privilege_text': 'Luxury Pink Rose Crown & Golden Heart Frame',
        'is_active': true,
      },
      {
        'id': 11,
        'level': 10,
        'name': 'Level 10 - QUEEN Imperial Diamond Wings',
        'required_coins': 5000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_queen_imperial.svg',
        'badge_icon': 'crown',
        'badge_color': '#d946ef',
        'glow_color': 'rgba(217, 70, 239, 0.88)',
        'privilege_text': 'Imperial Queen Diamond Crown & Angel Wings Base',
        'is_active': true,
      },
      {
        'id': 12,
        'level': 11,
        'name': 'Level 11 - KING Golden Royal Winged Crown',
        'required_coins': 8000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_king_royal.svg',
        'badge_icon': 'crown',
        'badge_color': '#eab308',
        'glow_color': 'rgba(234, 179, 8, 0.9)',
        'privilege_text': 'Supreme King 24K Gold Wings Base & Global Shout',
        'is_active': true,
      },
      {
        'id': 13,
        'level': 12,
        'name': 'Level 12 - Superbike Nitro Racer Helmet',
        'required_coins': 12000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_superbike_rider.svg',
        'badge_icon': 'bolt',
        'badge_color': '#6366f1',
        'glow_color': 'rgba(99, 102, 241, 0.92)',
        'privilege_text': 'Superbike Helmet, Spinning Wheel & Flame Burst Frame',
        'is_active': true,
      },
      {
        'id': 14,
        'level': 13,
        'name': 'Level 13 - Fire Phoenix Immortal',
        'required_coins': 18000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_phoenix_immortal.svg',
        'badge_icon': 'fire',
        'badge_color': '#f97316',
        'glow_color': 'rgba(249, 115, 22, 0.94)',
        'privilege_text': 'Phoenix Immortal Wings & Sunflare Avatar Frame',
        'is_active': true,
      },
      {
        'id': 15,
        'level': 14,
        'name': 'Level 14 - Ocean Leviathan Poseidon',
        'required_coins': 25000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_ocean_poseidon.svg',
        'badge_icon': 'water',
        'badge_color': '#0284c7',
        'glow_color': 'rgba(2, 132, 199, 0.96)',
        'privilege_text': 'Poseidon Gold Trident & Deep Ocean Water Wave Frame',
        'is_active': true,
      },
      {
        'id': 16,
        'level': 15,
        'name': 'Level 15 - Supreme Sovereign God-Tier',
        'required_coins': 40000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_supreme_sovereign.svg',
        'badge_icon': 'sun',
        'badge_color': '#f59e0b',
        'glow_color': 'rgba(245, 158, 11, 0.98)',
        'privilege_text': 'Supreme Sovereign God-Tier 24K Gold Sunburst & Diamond Aura',
        'is_active': true,
      },
    ];
  }
}
