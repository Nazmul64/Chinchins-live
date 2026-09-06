import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/fast_api_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class VipCardsApiService {
  static Map<String, dynamic>? _cachedVipData;

  /// Fetch all active Monthly & Weekly VIP Card packages, daily schedules, extra perks & countdown timers (Instant SWR)
  /// Endpoint: GET /api/spend-less-get-more
  static Future<Map<String, dynamic>> getVipCards({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedVipData != null) {
      _syncVipCardsInBackground();
      return _cachedVipData!;
    }

    final localCached = await FastApiClient.getCached(ApiConstants.spendLessGetMore);
    if (localCached is Map && localCached['status'] == true && localCached['data'] is Map) {
      _cachedVipData = Map<String, dynamic>.from(localCached['data']);
      _syncVipCardsInBackground();
      return _cachedVipData!;
    }

    final liveData = await _syncVipCardsInBackground();
    if (liveData != null) {
      return liveData;
    }

    // High quality offline / fallback data matching API documentation exactly
    return _getDefaultVipCardsData();
  }

  static Future<Map<String, dynamic>?> _syncVipCardsInBackground() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.spendLessGetMore);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == true && decoded['data'] is Map) {
          await FastApiClient.putCache(ApiConstants.spendLessGetMore, decoded);
          _cachedVipData = Map<String, dynamic>.from(decoded['data']);
          return _cachedVipData;
        }
      }
    } catch (e, st) {
      AppLogger.error('GetVipCardsError', e, st);
    }
    return _cachedVipData;
  }

  /// Fetch Floating VIP / Extra Gems banner configuration & image
  /// Endpoint: GET /api/spend-less-get-more/banner
  static Future<Map<String, dynamic>> getFloatingBanner() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.spendLessGetMoreBanner);
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
      if (vipData['floating_banner'] is Map) {
        return Map<String, dynamic>.from(vipData['floating_banner']);
      }
      if (vipData['banner'] is Map) {
        return Map<String, dynamic>.from(vipData['banner']);
      }
    } catch (_) {}

    return {
      'is_enabled': true,
      'title': 'Extra Gems',
      'tag': 'Monthly Card',
      'image_url': 'https://chinchins.live/assets/images/vip/floating_extra_gems.png',
      'action_type': 'OPEN_PREMIUM_VIP',
      'target_screen': '/premium-vip',
    };
  }

  /// Fetch user active card subscriptions & daily check-in claim status
  /// Endpoint: GET /api/spend-less-get-more/my
  static Future<Map<String, dynamic>?> getMySubscriptions() async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) return null;

      final url = Uri.parse(ApiConstants.spendLessGetMoreMy);
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

  /// Purchase a Monthly/Weekly Card using wallet balance / gems
  /// Endpoint: POST /api/spend-less-get-more/purchase
  static Future<Map<String, dynamic>> purchaseCard({
    dynamic cardId,
    String? cardType,
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

      final url = Uri.parse(ApiConstants.spendLessGetMorePurchase);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final payload = <String, dynamic>{
        'card_id': ?cardId,
        'card_type': ?cardType,
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

  /// Claim today's daily check-in gems & perks for an active card
  /// Endpoint: POST /api/spend-less-get-more/claim
  static Future<Map<String, dynamic>> claimDailyReward({
    dynamic subscriptionId,
    dynamic cardId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Please log in to claim daily rewards.',
        };
      }

      final url = Uri.parse(ApiConstants.spendLessGetMoreClaim);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final payload = <String, dynamic>{
        'subscription_id': ?subscriptionId,
        'card_id': ?cardId,
      };

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

  /// Production fallback cards structure matching RESTful documentation 1:1
  static Map<String, dynamic> _getDefaultVipCardsData() {
    return {
      'banner': {
        'title': 'Spend Less, Get More Gems!',
        'subtitle': 'Update to New User Weekly Card',
        'action_type': 'OPEN_PREMIUM_VIP',
      },
      'floating_banner': {
        'is_enabled': true,
        'title': 'Extra Gems',
        'tag': 'Monthly Card',
        'image_url': 'https://chinchins.live/assets/images/vip/floating_extra_gems.png',
        'action_type': 'OPEN_PREMIUM_VIP',
        'target_screen': '/premium-vip',
      },
      'cards': [
        {
          'id': 1,
          'card_type': 'new_user_weekly',
          'name': 'New User Weekly Card',
          'category_name': 'New User Weekly Card',
          'badge_text': '60% OFF',
          'price_bdt': 300.00,
          'original_price_bdt': 750.00,
          'formatted_price_bdt': '৳ 300',
          'formatted_original_price_bdt': '৳ 750.00',
          'discount_percent': 60,
          'price_coins': 8100,
          'duration_days': 7,
          'instant_reward_coins': 8100,
          'instant_reward_text': 'Gems in total 8100',
          'daily_checkin_total_coins': 2020,
          'daily_checkin_text': 'Gems in total 2020',
          'total_return_coins': 10120,
          'card_color': '#EC4899',
          'banner_tag': 'New User Weekly Card: 10,120 Gems + New Star 3D Avatar Frame!',
          'countdown_timer': '02 : 58 : 15 : 481',
          'extra_rewards': [
            {
              'title': '7 Days NEW STAR Frame',
              'tag': '7days',
              'icon': 'frame_diamond',
              'image_url': 'https://chinchins.live/assets/images/vip/new_star_frame.png',
            },
            {
              'title': '7 Days Newbie Glow',
              'tag': '7days',
              'icon': 'chat_bubble',
              'image_url': null,
            },
            {
              'title': 'Bonus Lucky Cards x7',
              'tag': 'x7',
              'icon': 'lucky_card',
              'image_url': null,
            },
          ],
          'daily_schedule': [
            {'day': 1, 'day_label': '1st', 'coins': 8100, 'extra': 'NEW STAR Avatar Frame'},
            {'day': 2, 'day_label': '2nd', 'coins': 300, 'extra': null},
            {'day': 3, 'day_label': '3rd', 'coins': 210, 'extra': null},
            {'day': 4, 'day_label': '4th', 'coins': 500, 'extra': null},
            {'day': 5, 'day_label': '5th', 'coins': 300, 'extra': null},
            {'day': 6, 'day_label': '6th', 'coins': 210, 'extra': null},
            {'day': 7, 'day_label': '7th', 'coins': 500, 'extra': 'New Star Title Badge'},
          ],
          'user_subscription': {
            'is_subscribed': false,
            'current_day': 1,
            'has_claimed_today': false,
            'claimed_days': [],
          },
        },
        {
          'id': 2,
          'card_type': 'super_monthly',
          'name': 'Super Monthly Card',
          'category_name': 'Super Monthly Card',
          'badge_text': '50% OFF',
          'price_bdt': 1200.00,
          'original_price_bdt': 2400.00,
          'formatted_price_bdt': '৳ 1,200',
          'formatted_original_price_bdt': '৳ 2,400.00',
          'discount_percent': 50,
          'price_coins': 32940,
          'duration_days': 30,
          'instant_reward_coins': 32940,
          'instant_reward_text': 'Gems in total 32940',
          'daily_checkin_total_coins': 26330,
          'daily_checkin_text': 'Gems in total 26330',
          'total_return_coins': 59270,
          'card_color': '#7C4DFF',
          'banner_tag': 'Super Monthly Card: 59,270 Gems + Outfits & Rewards!',
          'extra_rewards': [
            {
              'title': '30 Days 24K Gold Frame',
              'tag': '30days',
              'icon': 'gold_frame',
              'image_url': 'https://chinchins.live/assets/images/vip/gold_frame.png',
            },
            {
              'title': 'Luxury Chat Bubble',
              'tag': '30days',
              'icon': 'bubble',
              'image_url': null,
            },
            {
              'title': 'Bonus Lucky Cards x15',
              'tag': 'x15',
              'icon': 'lucky_card',
              'image_url': null,
            },
          ],
          'daily_schedule': [
            {'day': 1, 'day_label': '1st', 'coins': 32940, 'extra': '24K Gold Frame'},
            {'day': 2, 'day_label': '2nd', 'coins': 900, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'day_label': '3rd', 'coins': 850, 'extra': null},
            {'day': 4, 'day_label': '4th', 'coins': 950, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'day_label': '5th', 'coins': 850, 'extra': null},
            {'day': 6, 'day_label': '6th', 'coins': 900, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'day_label': '7th', 'coins': 1200, 'extra': 'Luxury Chat Bubble'},
            {'day': 15, 'day_label': '15th', 'coins': 1500, 'extra': 'x3 Lucky Cards'},
            {'day': 30, 'day_label': '30th', 'coins': 3000, 'extra': 'Super VIP Badge'},
          ],
          'user_subscription': {
            'is_subscribed': false,
            'current_day': 1,
            'has_claimed_today': false,
            'claimed_days': [],
          },
        },
        {
          'id': 3,
          'card_type': 'luxury_monthly',
          'name': 'Luxury Monthly Card',
          'category_name': 'Luxury Monthly Card',
          'badge_text': '50% OFF',
          'price_bdt': 2400.00,
          'original_price_bdt': 4800.00,
          'formatted_price_bdt': '৳ 2,400',
          'formatted_original_price_bdt': '৳ 4,800.00',
          'discount_percent': 50,
          'price_coins': 66600,
          'duration_days': 30,
          'instant_reward_coins': 66600,
          'instant_reward_text': 'Gems in total 66600',
          'daily_checkin_total_coins': 87110,
          'daily_checkin_text': 'Gems in total 87110',
          'total_return_coins': 153710,
          'card_color': '#2979FF',
          'banner_tag': 'Luxury Monthly Card: 153,710 Gems + Outfits + Free Cards!',
          'extra_rewards': [
            {
              'title': '30 Days 3D Diamond Frame',
              'tag': '30days',
              'icon': 'diamond_frame',
              'image_url': 'https://chinchins.live/assets/images/vip/diamond_frame.png',
            },
            {
              'title': 'VIP Crown Badge',
              'tag': '30days',
              'icon': 'crown',
              'image_url': null,
            },
            {
              'title': 'Bonus Lucky Cards x30',
              'tag': 'x30',
              'icon': 'lucky_card',
              'image_url': null,
            },
          ],
          'daily_schedule': [
            {'day': 1, 'day_label': '1st', 'coins': 66600, 'extra': '3D Diamond Frame'},
            {'day': 2, 'day_label': '2nd', 'coins': 3000, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'day_label': '3rd', 'coins': 2800, 'extra': 'x1 Lucky Card'},
            {'day': 4, 'day_label': '4th', 'coins': 3200, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'day_label': '5th', 'coins': 2900, 'extra': 'x1 Lucky Card'},
            {'day': 6, 'day_label': '6th', 'coins': 3100, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'day_label': '7th', 'coins': 4000, 'extra': 'VIP Crown Badge'},
            {'day': 15, 'day_label': '15th', 'coins': 5000, 'extra': 'x5 Lucky Cards'},
            {'day': 30, 'day_label': '30th', 'coins': 8000, 'extra': 'SVIP Supreme Title'},
          ],
          'user_subscription': {
            'is_subscribed': false,
            'current_day': 1,
            'has_claimed_today': false,
            'claimed_days': [],
          },
        },
        {
          'id': 4,
          'card_type': 'super_weekly',
          'name': 'Super Weekly Card',
          'category_name': 'Super Weekly Card',
          'badge_text': '30% OFF',
          'price_bdt': 450.00,
          'original_price_bdt': 642.86,
          'formatted_price_bdt': '৳ 450',
          'formatted_original_price_bdt': '৳ 642.86',
          'discount_percent': 30,
          'price_coins': 12150,
          'duration_days': 7,
          'instant_reward_coins': 12150,
          'instant_reward_text': 'Gems in total 12150',
          'daily_checkin_total_coins': 2540,
          'daily_checkin_text': 'Gems in total 2540',
          'total_return_coins': 14690,
          'card_color': '#FF4081',
          'banner_tag': 'Super Weekly Card: 14,690 Gems + Outfits!',
          'extra_rewards': [
            {
              'title': '7 Days Emerald Frame',
              'tag': '7days',
              'icon': 'emerald_frame',
              'image_url': 'https://chinchins.live/assets/images/vip/emerald_frame.png',
            },
            {
              'title': 'Super Weekly VIP Badge',
              'tag': '7days',
              'icon': 'weekly_badge',
              'image_url': null,
            },
            {
              'title': 'Bonus Lucky Cards x7',
              'tag': 'x7',
              'icon': 'lucky_card',
              'image_url': null,
            },
          ],
          'daily_schedule': [
            {'day': 1, 'day_label': '1st', 'coins': 12150, 'extra': 'Emerald Frame'},
            {'day': 2, 'day_label': '2nd', 'coins': 400, 'extra': 'x1 Lucky Card'},
            {'day': 3, 'day_label': '3rd', 'coins': 350, 'extra': 'x1 Lucky Card'},
            {'day': 4, 'day_label': '4th', 'coins': 450, 'extra': 'x1 Lucky Card'},
            {'day': 5, 'day_label': '5th', 'coins': 400, 'extra': 'x1 Lucky Card'},
            {'day': 6, 'day_label': '6th', 'coins': 440, 'extra': 'x1 Lucky Card'},
            {'day': 7, 'day_label': '7th', 'coins': 500, 'extra': 'VIP Badge + x2 Lucky Cards'},
          ],
          'user_subscription': {
            'is_subscribed': false,
            'current_day': 1,
            'has_claimed_today': false,
            'claimed_days': [],
          },
        },
      ],
    };
  }
}
