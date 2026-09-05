import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class VipCardsApiService {
  /// Fetch all available VIP Privilege Cards (New User, Super Monthly, Luxury Monthly, Super Weekly)
  static Future<Map<String, dynamic>> getVipCards() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.vipCards);
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
      AppLogger.error('GetVipCardsError', e, st);
    }

    // High quality offline / fallback data matching API documentation exactly
    return _getDefaultVipCardsData();
  }

  /// Fetch Floating VIP banner configuration & image
  static Future<Map<String, dynamic>> getFloatingBanner() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.vipBanner);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
      }
    } catch (e, st) {
      AppLogger.error('GetFloatingBannerError', e, st);
    }

    // Try extracting banner from getVipCards
    try {
      final vipData = await getVipCards();
      if (vipData['banner'] is Map) {
        return Map<String, dynamic>.from(vipData['banner']);
      }
      if (vipData['floating_banner'] is Map) {
        return Map<String, dynamic>.from(vipData['floating_banner']);
      }
    } catch (_) {}

    return {
      'is_enabled': true,
      'title': 'Extra Gems',
      'tag': 'Monthly Card',
      'image_url': 'https://chinchins.live/assets/images/vip/floating_extra_gems.png',
      'action_type': 'OPEN_PREMIUM_VIP',
    };
  }

  /// Fetch user active subscriptions & today claim status
  static Future<Map<String, dynamic>?> getMySubscriptions() async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) return null;

      final url = Uri.parse(ApiConstants.vipCardsMySubscriptions);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
      }
    } catch (e, st) {
      AppLogger.error('GetMySubscriptionsError', e, st);
    }
    return null;
  }

  /// Purchase / activate VIP Privilege Card
  static Future<Map<String, dynamic>> purchaseCard({
    required int cardId,
    String paymentMethod = 'coins',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Please log in to purchase VIP privilege cards.',
        };
      }

      final url = Uri.parse(ApiConstants.vipCardsPurchase);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final payload = {
        'card_id': cardId,
        'payment_method': paymentMethod,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          return {
            'success': true,
            'message': decoded['message'] ?? 'VIP card activated successfully!',
            'data': decoded['data'],
          };
        } else {
          return {
            'success': false,
            'message': decoded['message'] ?? 'Failed to activate VIP card.',
            'required_coins': decoded['required_coins'],
            'current_coins': decoded['current_coins'],
            'redirect_to_deposit': decoded['redirect_to_deposit'] == true,
          };
        }
      }
    } catch (e, st) {
      AppLogger.error('PurchaseCardError', e, st);
    }

    return {
      'success': false,
      'message': 'Connection timeout. Please check your internet connection.',
    };
  }

  /// Claim Daily Schedule Check-in Reward
  static Future<Map<String, dynamic>> claimDailyReward({required int cardId}) async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Please log in to claim daily rewards.',
        };
      }

      final url = Uri.parse(ApiConstants.vipCardsClaimDaily);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final payload = {'card_id': cardId};

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (response.statusCode == 200 || decoded['status'] == true) {
          return {
            'success': true,
            'message': decoded['message'] ?? 'Daily bonus claimed successfully!',
            'data': decoded['data'],
          };
        } else {
          return {
            'success': false,
            'message': decoded['message'] ?? 'Reward already claimed today.',
            'current_day': decoded['current_day'],
            'claimed_days': decoded['claimed_days'],
          };
        }
      }
    } catch (e, st) {
      AppLogger.error('ClaimDailyRewardError', e, st);
    }

    return {
      'success': false,
      'message': 'Network error while claiming reward. Please try again.',
    };
  }

  /// Default fallback cards structure
  static Map<String, dynamic> _getDefaultVipCardsData() {
    return {
      'banner': {
        'title': 'Spend Less, Get More Gems!',
        'subtitle': 'Update to New User Weekly Card',
        'action_type': 'OPEN_VIP_CARDS',
      },
      'cards': [
        {
          'id': 1,
          'card_type': 'trial_3day',
          'name': 'Trial 3-Day VIP Card',
          'badge_text': 'TRIAL',
          'price_bdt': 150,
          'formatted_price_bdt': 'BDT 150.00',
          'price_coins': 3000,
          'duration_days': 3,
          'instant_reward_coins': 3000,
          'daily_checkin_total_coins': 1500,
          'total_return_coins': 4500,
          'card_color': '#FF9800',
          'banner_tag': 'Trial Recharge = 3000 | VIP Total = 4500 Gems',
          'daily_schedule': [
            {'day': 1, 'coins': 3000, 'extra': '3D Star Frame'},
            {'day': 2, 'coins': 750, 'extra': null},
            {'day': 3, 'coins': 750, 'extra': 'Chat Glow'},
          ],
          'extra_rewards': [
            {'title': '3D Star Avatar Frame', 'tag': 'Trial Outfit', 'icon': 'star_frame'},
            {'title': 'VIP Chat Glow', 'tag': 'Privilege', 'icon': 'glow'},
          ],
        },
        {
          'id': 2,
          'card_type': 'super_weekly',
          'name': 'Super Weekly Card',
          'badge_text': 'POPULAR',
          'price_bdt': 450,
          'formatted_price_bdt': 'BDT 450.00',
          'price_coins': 12150,
          'duration_days': 7,
          'instant_reward_coins': 12150,
          'daily_checkin_total_coins': 2540,
          'total_return_coins': 14690,
          'card_color': '#00E676',
          'banner_tag': 'Recharge = 12150 | Return = 14690 + 7x Lucky Cards',
          'daily_schedule': [
            {'day': 1, 'coins': 12150, 'extra': 'Emerald Frame'},
            {'day': 2, 'coins': 400, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'coins': 350, 'extra': 'x1 Lucky Card'},
            {'day': 4, 'coins': 450, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'coins': 400, 'extra': 'x1 Lucky Card'},
            {'day': 6, 'coins': 440, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'coins': 500, 'extra': 'VIP Badge + x2 Lucky Cards'},
          ],
          'extra_rewards': [
            {'title': 'Emerald Avatar Frame', 'tag': 'Weekly Outfit', 'icon': 'emerald_frame'},
            {'title': 'Super Weekly VIP Badge', 'tag': 'VIP Icon', 'icon': 'weekly_badge'},
            {'title': '7x Lucky Cards', 'tag': 'Free Cards', 'icon': 'lucky_cards_7'},
          ],
        },
        {
          'id': 3,
          'card_type': 'super_monthly',
          'name': 'Super Monthly Card',
          'badge_text': 'BEST VALUE',
          'price_bdt': 1200,
          'formatted_price_bdt': 'BDT 1,200.00',
          'price_coins': 32940,
          'duration_days': 30,
          'instant_reward_coins': 32940,
          'daily_checkin_total_coins': 26330,
          'total_return_coins': 59270,
          'card_color': '#7C4DFF',
          'banner_tag': 'Recharge = 32940 | Return = 59270 + 15x Lucky Cards',
          'daily_schedule': [
            {'day': 1, 'coins': 32940, 'extra': '24K Gold Frame'},
            {'day': 2, 'coins': 900, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'coins': 850, 'extra': null},
            {'day': 4, 'coins': 950, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'coins': 850, 'extra': null},
            {'day': 6, 'coins': 900, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'coins': 1200, 'extra': 'Luxury Chat Bubble'},
          ],
          'extra_rewards': [
            {'title': '24K Gold Frame', 'tag': 'Gold Outfit', 'icon': 'gold_frame'},
            {'title': 'Luxury Chat Bubble', 'tag': 'Special Bubble', 'icon': 'bubble'},
            {'title': '15x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_15'},
          ],
        },
        {
          'id': 4,
          'card_type': 'luxury_monthly',
          'name': 'Luxury Monthly Card',
          'badge_text': '50% OFF',
          'price_bdt': 2400,
          'formatted_price_bdt': 'BDT 2,400.00',
          'price_coins': 66600,
          'duration_days': 30,
          'instant_reward_coins': 66600,
          'daily_checkin_total_coins': 87110,
          'total_return_coins': 153710,
          'card_color': '#2979FF',
          'banner_tag': 'Recharge = 66600 | Return = 153710 + 30x Lucky Cards',
          'daily_schedule': [
            {'day': 1, 'coins': 66600, 'extra': '3D Diamond Frame'},
            {'day': 2, 'coins': 3000, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'coins': 2800, 'extra': 'x1 Lucky Card'},
            {'day': 4, 'coins': 3200, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'coins': 2900, 'extra': 'x1 Lucky Card'},
            {'day': 6, 'coins': 3100, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'coins': 4000, 'extra': 'VIP Crown Badge'},
          ],
          'extra_rewards': [
            {'title': '3D Diamond Frame', 'tag': 'Luxury Outfit', 'icon': 'diamond_frame'},
            {'title': 'VIP Crown Badge', 'tag': 'SVIP Status', 'icon': 'crown'},
            {'title': '30x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_30'},
          ],
        },
        {
          'id': 5,
          'card_type': 'svip_quarterly',
          'name': 'SVIP Quarterly 90-Day',
          'badge_text': 'SVIP 90D',
          'price_bdt': 6500,
          'formatted_price_bdt': 'BDT 6,500.00',
          'price_coins': 200000,
          'duration_days': 90,
          'instant_reward_coins': 200000,
          'daily_checkin_total_coins': 250000,
          'total_return_coins': 450000,
          'card_color': '#FF5722',
          'banner_tag': 'Recharge = 200K | Return = 450K + Fire Dragon Frame',
          'daily_schedule': [
            {'day': 1, 'coins': 200000, 'extra': 'Fire Dragon Frame'},
            {'day': 2, 'coins': 2800, 'extra': 'x2 Lucky Cards'},
            {'day': 3, 'coins': 2800, 'extra': null},
            {'day': 7, 'coins': 5000, 'extra': 'Supersonic Jet Entry'},
          ],
          'extra_rewards': [
            {'title': 'Fire Dragon Frame', 'tag': 'Animated Frame', 'icon': 'dragon_frame'},
            {'title': 'Supersonic Jet Entry', 'tag': 'Room Entry', 'icon': 'jet_entry'},
            {'title': '100x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_100'},
          ],
        },
        {
          'id': 6,
          'card_type': 'royal_semi_annual',
          'name': 'Royal Semi-Annual (180D)',
          'badge_text': 'ROYAL',
          'price_bdt': 12000,
          'formatted_price_bdt': 'BDT 12,000.00',
          'price_coins': 450000,
          'duration_days': 180,
          'instant_reward_coins': 450000,
          'daily_checkin_total_coins': 550000,
          'total_return_coins': 1000000,
          'card_color': '#FFD700',
          'banner_tag': 'Recharge = 450K | Return = 1,000,000 Gems (1 Million)',
          'daily_schedule': [
            {'day': 1, 'coins': 450000, 'extra': '24K Sovereign Crown'},
            {'day': 2, 'coins': 3100, 'extra': 'x3 Lucky Cards'},
            {'day': 7, 'coins': 7500, 'extra': 'Golden Nickname'},
          ],
          'extra_rewards': [
            {'title': '24K Sovereign Crown Frame', 'tag': 'Royal Outfit', 'icon': 'sovereign_crown'},
            {'title': 'Golden Nickname', 'tag': 'Chat Privilege', 'icon': 'golden_name'},
            {'title': '250x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_250'},
          ],
        },
        {
          'id': 7,
          'card_type': 'galactic_annual',
          'name': 'Galactic Annual (365D)',
          'badge_text': 'ANNUAL',
          'price_bdt': 22000,
          'formatted_price_bdt': 'BDT 22,000.00',
          'price_coins': 1000000,
          'duration_days': 365,
          'instant_reward_coins': 1000000,
          'daily_checkin_total_coins': 1250000,
          'total_return_coins': 2250000,
          'card_color': '#00E5FF',
          'banner_tag': 'Recharge = 1M | Return = 2,250,000 Gems + Space Battleship',
          'daily_schedule': [
            {'day': 1, 'coins': 1000000, 'extra': 'Cyber Neon Ultra Frame'},
            {'day': 2, 'coins': 3500, 'extra': 'x5 Lucky Cards'},
            {'day': 7, 'coins': 10000, 'extra': 'Space Battleship Entry'},
          ],
          'extra_rewards': [
            {'title': 'Cyber Neon Ultra Frame', 'tag': 'Ultra Outfit', 'icon': 'cyber_frame'},
            {'title': 'Space Battleship Entry', 'tag': 'Full Screen Entry', 'icon': 'battleship'},
            {'title': '500x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_500'},
          ],
        },
        {
          'id': 8,
          'card_type': 'black_diamond_sovereign',
          'name': 'Black Diamond Sovereign (365D)',
          'badge_text': 'GOD-TIER',
          'price_bdt': 50000,
          'formatted_price_bdt': 'BDT 50,000.00',
          'price_coins': 3000000,
          'duration_days': 365,
          'instant_reward_coins': 3000000,
          'daily_checkin_total_coins': 3000000,
          'total_return_coins': 6000000,
          'card_color': '#E040FB',
          'banner_tag': 'Supreme Return = 6,000,000 Gems (6 Million) + God-Tier Frame',
          'daily_schedule': [
            {'day': 1, 'coins': 3000000, 'extra': 'Mythic Emperor Frame'},
            {'day': 2, 'coins': 8500, 'extra': 'x10 Lucky Cards'},
            {'day': 7, 'coins': 25000, 'extra': 'Global Server Shout'},
          ],
          'extra_rewards': [
            {'title': 'Mythic Emperor God-Tier Frame', 'tag': 'Apex Outfit', 'icon': 'mythic_emperor'},
            {'title': 'Unlimited Global Broadcasts', 'tag': 'Apex Perk', 'icon': 'broadcast'},
            {'title': '1000x Lucky Cards', 'tag': 'Free Cards', 'icon': 'card_1000'},
          ],
        },
      ],
    };
  }
}
