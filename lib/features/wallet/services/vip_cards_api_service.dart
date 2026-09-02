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
          'card_type': 'new_user',
          'name': 'New User Weekly Card',
          'badge_text': 'HOT',
          'price_bdt': 300,
          'formatted_price_bdt': 'BDT 300.00',
          'price_coins': 8100,
          'duration_days': 7,
          'instant_reward_coins': 8100,
          'daily_checkin_total_coins': 2020,
          'total_return_coins': 10120,
          'card_color': '#FF2D55',
          'banner_tag': 'Normal Recharge = 8100 | Weekly Card = 10120+outfits',
          'daily_schedule': [
            {'day': 1, 'coins': 8100, 'extra': 'Card x1'},
            {'day': 2, 'coins': 300, 'extra': null},
            {'day': 3, 'coins': 210, 'extra': null},
            {'day': 4, 'coins': 500, 'extra': null},
            {'day': 5, 'coins': 350, 'extra': null},
            {'day': 6, 'coins': 300, 'extra': null},
            {'day': 7, 'coins': 360, 'extra': 'Exclusive Badge'},
          ],
          'extra_rewards': [
            {'title': 'Exclusive Avatar Frame', 'tag': 'Free Outfits', 'icon': 'frame'},
            {'title': 'Weekly Card Badge', 'tag': 'SVIP Icon', 'icon': 'badge'},
            {'title': 'Free Lucky Card x1', 'tag': 'Free Card', 'icon': 'card'},
            {'title': 'Entry Glow Effect', 'tag': 'Privilege', 'icon': 'effect'},
          ],
        },
        {
          'id': 2,
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
          'banner_tag': 'Normal Recharge = 32940 | Monthly Card = 59270+outfits',
          'daily_schedule': [
            {'day': 1, 'coins': 32940, 'extra': 'Gold Frame'},
            {'day': 2, 'coins': 1790, 'extra': null},
            {'day': 3, 'coins': 1210, 'extra': null},
            {'day': 4, 'coins': 1790, 'extra': null},
            {'day': 5, 'coins': 1210, 'extra': null},
            {'day': 6, 'coins': 1790, 'extra': null},
            {'day': 7, 'coins': 1790, 'extra': null},
            {'day': 8, 'coins': 656, 'extra': null},
            {'day': 9, 'coins': 656, 'extra': null},
            {'day': 10, 'coins': 1210, 'extra': null},
            {'day': 11, 'coins': 656, 'extra': null},
            {'day': 12, 'coins': 1790, 'extra': null},
            {'day': 13, 'coins': 656, 'extra': null},
            {'day': 14, 'coins': 1790, 'extra': null},
            {'day': 15, 'coins': 1210, 'extra': null},
            {'day': 16, 'coins': 656, 'extra': null},
            {'day': 17, 'coins': 1790, 'extra': null},
            {'day': 18, 'coins': 656, 'extra': null},
            {'day': 19, 'coins': 656, 'extra': null},
            {'day': 20, 'coins': 1210, 'extra': null},
            {'day': 21, 'coins': 1790, 'extra': null},
            {'day': 22, 'coins': 656, 'extra': null},
            {'day': 23, 'coins': 656, 'extra': null},
            {'day': 24, 'coins': 1790, 'extra': null},
            {'day': 25, 'coins': 1210, 'extra': null},
            {'day': 26, 'coins': 656, 'extra': null},
            {'day': 27, 'coins': 1790, 'extra': null},
            {'day': 28, 'coins': 656, 'extra': null},
            {'day': 29, 'coins': 656, 'extra': null},
            {'day': 30, 'coins': 2500, 'extra': 'Gold SVIP Crown'},
          ],
          'extra_rewards': [
            {'title': 'Super VIP Gold Frame', 'tag': 'Gold Frame', 'icon': 'gold_frame'},
            {'title': 'Luxury Chat Bubble', 'tag': 'Special Outfit', 'icon': 'bubble'},
            {'title': 'Privilege Entry Banner', 'tag': 'Entry Anim', 'icon': 'banner'},
            {'title': 'Free Lucky Cards x3', 'tag': 'Free Cards', 'icon': 'card_3'},
          ],
        },
        {
          'id': 3,
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
          'banner_tag': 'Normal Recharge = 66600 | Monthly Card = 153710+outfits+free cards',
          'daily_schedule': [
            {'day': 1, 'coins': 66600, 'extra': 'Diamond Frame'},
            {'day': 2, 'coins': 3500, 'extra': 'x1 Card'},
            {'day': 3, 'coins': 1790, 'extra': 'x1 Card'},
            {'day': 4, 'coins': 3500, 'extra': 'x1 Card'},
            {'day': 5, 'coins': 1790, 'extra': 'x1 Card'},
            {'day': 6, 'coins': 3500, 'extra': 'x1 Card'},
            {'day': 7, 'coins': 3500, 'extra': 'x1 Card'},
            {'day': 8, 'coins': 2953, 'extra': 'x1 Card'},
            {'day': 9, 'coins': 2953, 'extra': 'x1 Card'},
            {'day': 10, 'coins': 2953, 'extra': 'x1 Card'},
            {'day': 11, 'coins': 2953, 'extra': 'x1 Card'},
            {'day': 12, 'coins': 2953, 'extra': 'x1 Card'},
          ],
          'extra_rewards': [
            {'title': 'Diamond Halo Frame', 'tag': 'Luxury Outfit', 'icon': 'diamond_frame'},
            {'title': 'SVIP Crown Badge & Title', 'tag': 'SVIP Status', 'icon': 'crown'},
            {'title': 'Global Room Entry Effect', 'tag': 'Super Entry', 'icon': 'global_entry'},
            {'title': 'Free Lucky Cards x5', 'tag': 'Free Cards', 'icon': 'card_5'},
          ],
        },
        {
          'id': 4,
          'card_type': 'super_weekly',
          'name': 'Super Weekly Card',
          'badge_text': 'POPULAR',
          'price_bdt': 600,
          'formatted_price_bdt': 'BDT 600.00',
          'price_coins': 16200,
          'duration_days': 7,
          'instant_reward_coins': 16200,
          'daily_checkin_total_coins': 5000,
          'total_return_coins': 21200,
          'card_color': '#00E676',
          'banner_tag': 'Normal Recharge = 16200 | Weekly Card = 21200+outfits',
          'daily_schedule': [
            {'day': 1, 'coins': 16200, 'extra': 'Neon Frame'},
            {'day': 2, 'coins': 800, 'extra': null},
            {'day': 3, 'coins': 600, 'extra': null},
            {'day': 4, 'coins': 1000, 'extra': null},
            {'day': 5, 'coins': 700, 'extra': null},
            {'day': 6, 'coins': 800, 'extra': null},
            {'day': 7, 'coins': 1100, 'extra': 'VIP Badge'},
          ],
          'extra_rewards': [
            {'title': 'Neon Glow Frame', 'tag': 'Neon Outfit', 'icon': 'neon_frame'},
            {'title': 'Super Weekly Badge', 'tag': 'VIP Icon', 'icon': 'weekly_badge'},
            {'title': 'Free Lucky Cards x2', 'tag': 'Free Cards', 'icon': 'card_2'},
          ],
        },
      ],
    };
  }
}
