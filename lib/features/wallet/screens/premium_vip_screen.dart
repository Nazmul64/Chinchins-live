import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/vip_cards_api_service.dart';
import '../services/wallet_api_service.dart';
import 'deposit_screen.dart';

class PremiumVipScreen extends StatefulWidget {
  final int initialCardIndex;

  const PremiumVipScreen({
    super.key,
    this.initialCardIndex = 0,
  });

  @override
  State<PremiumVipScreen> createState() => _PremiumVipScreenState();
}

class _PremiumVipScreenState extends State<PremiumVipScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadVipData();
  }

  Future<void> _loadVipData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        WalletApiService.getWalletBalance().catchError((_) => null),
        VipCardsApiService.getVipCards().catchError((_) => <String, dynamic>{}),
        VipCardsApiService.getMySubscriptions().catchError((_) => null),
      ]);

      final dynamic rawVip = results[1];
      final Map<String, dynamic> vipData = rawVip is Map<String, dynamic>
          ? rawVip
          : (rawVip is Map ? Map<String, dynamic>.from(rawVip) : <String, dynamic>{});
      final dynamic rawSub = results[2];
      final Map<String, dynamic>? subData = rawSub is Map<String, dynamic> ? rawSub : null;

      final rawCards = vipData['cards'] as List? ?? [];
      List<Map<String, dynamic>> parsedCards = rawCards.map((c) => Map<String, dynamic>.from(c)).toList();

      if (parsedCards.isEmpty) {
        parsedCards = _getFallbackVipCards();
      }

      // Merge active subscriptions
      if (subData != null && subData['subscriptions'] is List) {
        final List subList = subData['subscriptions'];
        for (final card in parsedCards) {
          final cardId = card['id'];
          final matchedSub = subList.firstWhere(
            (s) => s['card_id'] == cardId || s['card_type'] == card['card_type'],
            orElse: () => null,
          );
          if (matchedSub != null) {
            card['user_subscription'] = {
              'is_subscribed': matchedSub['is_active'] == true,
              'subscription_id': matchedSub['subscription_id'],
              'has_claimed_today': matchedSub['has_claimed_today'] == true,
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _cards = parsedCards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cards = _getFallbackVipCards();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFallbackVipCards() {
    return [
      {
        'id': 2,
        'card_type': 'super_monthly',
        'name': 'Super Monthly Card',
        'badge_title': 'Super Monthly Card',
        'price_bdt': 1200,
        'original_price_bdt': 2400.00,
        'formatted_price': '৳ 1200',
        'formatted_original_price': '৳ 2400.00',
        'instant_reward_coins': 32940,
        'daily_checkin_total_coins': 26330,
        'extra_rewards': [
          {'name': 'Gold Frame', 'duration': '30days', 'icon': 'frame'},
          {'name': 'Chat Bubble', 'duration': '30days', 'icon': 'bubble'},
          {'name': 'Gold Crown', 'duration': '30days', 'icon': 'crown'},
          {'name': 'Lucky Card', 'duration': 'x 3', 'icon': 'card'},
        ],
      },
      {
        'id': 3,
        'card_type': 'luxury_monthly',
        'name': 'Luxury Monthly Card',
        'badge_title': 'Luxury Monthly Card',
        'price_bdt': 2400,
        'original_price_bdt': 4800.00,
        'formatted_price': '৳ 2400',
        'formatted_original_price': '৳ 4800.00',
        'instant_reward_coins': 66600,
        'daily_checkin_total_coins': 87110,
        'extra_rewards': [
          {'name': 'Diamond Frame', 'duration': '30days', 'icon': 'frame'},
          {'name': 'Luxury Bubble', 'duration': '30days', 'icon': 'bubble'},
          {'name': 'SVIP Title', 'duration': '30days', 'icon': 'crown'},
          {'name': 'Lucky Card', 'duration': 'x 30', 'icon': 'card'},
        ],
      },
      {
        'id': 4,
        'card_type': 'super_weekly',
        'name': 'Super Weekly Card',
        'badge_title': 'Super Weekly Card',
        'price_bdt': 450,
        'original_price_bdt': 642.86,
        'formatted_price': '৳ 450',
        'formatted_original_price': '৳ 642.86',
        'instant_reward_coins': 12150,
        'daily_checkin_total_coins': 2540,
        'extra_rewards': [
          {'name': 'Neon Frame', 'duration': '7days', 'icon': 'frame'},
          {'name': 'Chat Bubble', 'duration': '7days', 'icon': 'bubble'},
          {'name': 'Weekly Badge', 'duration': '7days', 'icon': 'crown'},
          {'name': 'Lucky Card', 'duration': 'x 2', 'icon': 'card'},
        ],
      },
    ];
  }

  Future<void> _handlePurchase(Map<String, dynamic> card) async {
    if (_isActionInProgress) return;

    final String cardName = card['badge_title'] ?? card['name'] ?? 'VIP Privilege Card';
    final int priceBdt = (card['price_bdt'] is int)
        ? card['price_bdt'] as int
        : (int.tryParse(card['price_bdt']?.toString() ?? '0') ?? 0);
    final String formattedPrice = card['formatted_price'] ?? '৳ $priceBdt';
    final int instantCoins = card['instant_reward_coins'] ?? 0;
    final int cardId = card['id'] ?? 1;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1A26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Activate $cardName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will instantly receive $instantCoins Gems + Daily Check-in Bonus + Exclusive Outfits & Badges for $formattedPrice.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFE8D3BF),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Pay $formattedPrice',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionInProgress = true);

    try {
      final res = await VipCardsApiService.purchaseCard(cardId: cardId);
      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? '$cardName activated successfully!'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
        _loadVipData();
      } else {
        if (res['redirect_to_deposit'] == true || (res['message'] != null && res['message'].toString().contains('balance'))) {
          // Open deposit screen with package details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DepositScreen(
                selectedPackage: {
                  'price': priceBdt,
                  'price_bdt': priceBdt,
                  'coins': instantCoins,
                  'title': cardName,
                },
                onDepositSuccess: () => _loadVipData(),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Failed to activate VIP Card'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0A12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Premium VIP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5722), Color(0xFFFF3D00)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Dev mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonPink),
            )
          : RefreshIndicator(
              color: AppColors.neonPink,
              backgroundColor: const Color(0xFF1B1A26),
              onRefresh: _loadVipData,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return _buildVipCardItem(card);
                },
              ),
            ),
    );
  }

  Widget _buildVipCardItem(Map<String, dynamic> card) {
    final String title = card['badge_title'] ?? card['name'] ?? 'VIP Privilege Card';
    final int instantCoins = (card['instant_reward_coins'] is int)
        ? card['instant_reward_coins'] as int
        : (int.tryParse(card['instant_reward_coins']?.toString() ?? '0') ?? 0);
    final int dailyCoins = (card['daily_checkin_total_coins'] is int)
        ? card['daily_checkin_total_coins'] as int
        : (int.tryParse(card['daily_checkin_total_coins']?.toString() ?? '0') ?? 0);

    final int priceBdt = (card['price_bdt'] is int)
        ? card['price_bdt'] as int
        : (int.tryParse(card['price_bdt']?.toString() ?? '0') ?? 0);
    final String formattedPrice = card['formatted_price'] ?? '৳ $priceBdt';

    final dynamic origPrice = card['original_price_bdt'] ?? (priceBdt * 2.0);
    final String formattedOriginalPrice = card['formatted_original_price'] ??
        (origPrice is num ? '৳ ${origPrice.toStringAsFixed(2)}' : '৳ $origPrice');

    final List extraRewards = (card['extra_rewards'] is List)
        ? card['extra_rewards'] as List
        : [
            {'duration': '30days', 'icon': 'frame'},
            {'duration': '30days', 'icon': 'bubble'},
            {'duration': '30days', 'icon': 'crown'},
            {'duration': 'x 30', 'icon': 'card'},
          ];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Card Box
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.fromLTRB(14, 28, 14, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF14131C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // 3-Column Reward Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Instant Reward
                    Expanded(
                      flex: 4,
                      child: _buildColumnBox(
                        header: 'Instant Reward',
                        coinAmount: instantCoins,
                        showPlus: true,
                      ),
                    ),

                    // Column 2: Daily Check-in Bonus
                    Expanded(
                      flex: 4,
                      child: _buildColumnBox(
                        header: 'Daily Check-in Bonus',
                        coinAmount: dailyCoins,
                        showPlus: false,
                      ),
                    ),

                    // Column 3: Extra Reward Grid
                    Expanded(
                      flex: 4,
                      child: _buildExtraRewardsColumn(extraRewards),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Champagne / Gold Rounded Buy Button
                GestureDetector(
                  onTap: () => _handlePurchase(card),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFAF0E6),
                          Color(0xFFEAD4C0),
                          Color(0xFFDCBFAB),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEAD4C0).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedPrice,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          formattedOriginalPrice,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metallic Header Title Badge on Top
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9E9DA8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnBox({
    required String header,
    required int coinAmount,
    required bool showPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          // Header
          Text(
            header,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Gem Pile Image Graphic with Plus Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGemsChestGraphic(),
              if (showPlus) ...[
                const SizedBox(width: 4),
                Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Subtitle
          Text(
            'Gems in total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),

          // Bold Count
          Text(
            '$coinAmount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExtraRewardsColumn(List extraRewards) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          // Header
          Text(
            'Extra Reward',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // 2x2 Reward Items
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildRewardItemBadge(
                tag: extraRewards.isNotEmpty ? extraRewards[0]['duration'] ?? '30days' : '30days',
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF00E5FF),
              ),
              _buildRewardItemBadge(
                tag: extraRewards.length > 1 ? extraRewards[1]['duration'] ?? '30days' : '30days',
                icon: Icons.chat_bubble_rounded,
                iconColor: const Color(0xFF64B5F6),
              ),
              _buildRewardItemBadge(
                tag: extraRewards.length > 2 ? extraRewards[2]['duration'] ?? '30days' : '30days',
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFFFD54F),
              ),
              _buildRewardItemBadge(
                tag: extraRewards.length > 3 ? extraRewards[3]['duration'] ?? 'x 30' : 'x 30',
                icon: Icons.confirmation_number_rounded,
                iconColor: const Color(0xFFFFB74D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItemBadge({
    required String tag,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Duration White Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Reward Icon Graphic
        Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGemsChestGraphic() {
    return Container(
      width: 44,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.diamond_rounded,
          color: Color(0xFFFFD700),
          size: 28,
          shadows: [
            Shadow(color: Color(0xFFFFAB00), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}
