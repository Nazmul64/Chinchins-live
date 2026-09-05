import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class LevelBasesApiService {
  /// Fetch master list of all Level Bases & Avatar Frames
  static Future<List<Map<String, dynamic>>> getAllProfileBases() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileBases);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is List) {
          return (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e, st) {
      AppLogger.error('GetAllProfileBasesError', e, st);
    }

    return _getDefaultLevelBases();
  }

  /// Fetch User Level status & progression stats
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

      final url = Uri.parse(urlStr);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
      }
    } catch (e, st) {
      AppLogger.error('GetUserLevelStatusError', e, st);
    }

    return null;
  }

  static List<Map<String, dynamic>> _getDefaultLevelBases() {
    return [
      {
        'id': 1,
        'level': 0,
        'name': 'Level 0 - Novice Cadet',
        'required_coins': 0,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_royal_gold.svg',
        'badge_icon': 'user',
        'badge_color': '#94a3b8',
        'glow_color': 'rgba(148, 163, 184, 0.3)',
        'privilege_text': 'Standard Profile Frame',
        'is_active': true,
      },
      {
        'id': 2,
        'level': 1,
        'name': 'Level 1 - Bronze Star',
        'required_coins': 1000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_royal_gold.svg',
        'badge_icon': 'star',
        'badge_color': '#10b981',
        'glow_color': 'rgba(16, 185, 129, 0.45)',
        'privilege_text': 'Unlocks Bronze Star Animated Avatar Frame',
        'is_active': true,
      },
      {
        'id': 3,
        'level': 2,
        'name': 'Level 2 - Silver Wings',
        'required_coins': 5000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_diamond_wings.svg',
        'badge_icon': 'star',
        'badge_color': '#06b6d4',
        'glow_color': 'rgba(6, 182, 212, 0.45)',
        'privilege_text': 'Unlocks Silver Wings Animated Avatar Frame',
        'is_active': true,
      },
      {
        'id': 4,
        'level': 3,
        'name': 'Level 3 - Golden Sparkle',
        'required_coins': 15000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_royal_gold.svg',
        'badge_icon': 'gem',
        'badge_color': '#f59e0b',
        'glow_color': 'rgba(245, 158, 11, 0.5)',
        'privilege_text': 'Unlocks Golden Sparkle Avatar Frame & Profile Glow',
        'is_active': true,
      },
      {
        'id': 5,
        'level': 4,
        'name': 'Level 4 - Cyber Neon',
        'required_coins': 50000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_cyber_neon.svg',
        'badge_icon': 'bolt',
        'badge_color': '#00f0ff',
        'glow_color': 'rgba(0, 240, 255, 0.6)',
        'privilege_text': 'Unlocks Cyber Neon Animated Avatar Frame & Blue Beam',
        'is_active': true,
      },
      {
        'id': 6,
        'level': 5,
        'name': 'Level 5 - Emerald Dragon',
        'required_coins': 150000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_emerald_dragon.svg',
        'badge_icon': 'shield',
        'badge_color': '#10b981',
        'glow_color': 'rgba(16, 185, 129, 0.65)',
        'privilege_text': 'Unlocks Emerald Dragon Avatar Frame & Special Chat Badge',
        'is_active': true,
      },
      {
        'id': 7,
        'level': 6,
        'name': 'Level 6 - Ruby Phoenix',
        'required_coins': 350000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_ruby_phoenix.svg',
        'badge_icon': 'fire',
        'badge_color': '#ef4444',
        'glow_color': 'rgba(239, 68, 68, 0.7)',
        'privilege_text': 'Unlocks Ruby Phoenix Flaming Avatar Frame & Room Entry',
        'is_active': true,
      },
      {
        'id': 8,
        'level': 7,
        'name': 'Level 7 - Amethyst Royal',
        'required_coins': 800000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_amethyst_royal.svg',
        'badge_icon': 'crown',
        'badge_color': '#a855f7',
        'glow_color': 'rgba(168, 85, 247, 0.75)',
        'privilege_text': 'Unlocks Amethyst Royal SVIP Avatar Frame & Purple Glow',
        'is_active': true,
      },
      {
        'id': 9,
        'level': 8,
        'name': 'Level 8 - Solar Flare',
        'required_coins': 1500000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_solar_flare.svg',
        'badge_icon': 'sun',
        'badge_color': '#f97316',
        'glow_color': 'rgba(249, 115, 22, 0.8)',
        'privilege_text': 'Unlocks Solar Flare Supernova Avatar Frame & Gold Badge',
        'is_active': true,
      },
      {
        'id': 10,
        'level': 9,
        'name': 'Level 9 - Celestial Diamond',
        'required_coins': 3000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_celestial_diamond.svg',
        'badge_icon': 'gem',
        'badge_color': '#38bdf8',
        'glow_color': 'rgba(56, 189, 248, 0.85)',
        'privilege_text': 'Unlocks Celestial Diamond Ultra Luxury Frame & Halo Glow',
        'is_active': true,
      },
      {
        'id': 11,
        'level': 10,
        'name': 'Level 10 - Mythic Emperor',
        'required_coins': 5000000,
        'frame_image_url': 'https://chinchins.live/uploads/bases/profile_base_svip_crown.svg',
        'badge_icon': 'crown',
        'badge_color': '#f43f5e',
        'glow_color': 'rgba(244, 63, 94, 0.9)',
        'privilege_text': 'Supreme Mythic Emperor God-Tier Base Frame & Global Shout',
        'is_active': true,
      },
    ];
  }
}
