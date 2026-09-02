import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/vip_cards_api_service.dart';
import '../services/wallet_api_service.dart';

class MonthlyCardScreen extends StatefulWidget {
  final int initialCardIndex;

  const MonthlyCardScreen({
    super.key,
    this.initialCardIndex = 0,
  });

  @override
  State<MonthlyCardScreen> createState() => _MonthlyCardScreenState();
}

class _MonthlyCardScreenState extends State<MonthlyCardScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  int _userGems = 0;

  Timer? _countdownTimer;
  Duration _mockTimerDuration = const Duration(days: 6, hours: 23, minutes: 59, seconds: 59);

  @override
  void initState() {
    super.initState();
    _loadCardsAndSession();
    _startTimerTicker();
  }

  void _startTimerTicker() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_mockTimerDuration.inSeconds > 0) {
            _mockTimerDuration = _mockTimerDuration - const Duration(seconds: 1);
          }
        });
      }
    });
  }

  String _formatCountdown(Duration d) {
    final days = d.inDays.toString().padLeft(2, '0');
    final hours = (d.inHours % 24).toString().padLeft(2, '0');
    final mins = (d.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$days : $hours : $mins : $secs';
  }

  Future<void> _loadCardsAndSession() async {
    final balanceData = await WalletApiService.getWalletBalance();
    final vipData = await VipCardsApiService.getVipCards();
    final subData = await VipCardsApiService.getMySubscriptions();

    if (!mounted) return;

    final rawCards = vipData['cards'] as List? ?? [];
    final List<Map<String, dynamic>> parsedCards = rawCards.map((c) => Map<String, dynamic>.from(c)).toList();

    int initialIdx = widget.initialCardIndex;
    if (initialIdx >= parsedCards.length) initialIdx = 0;

    _tabController?.dispose();
    _tabController = TabController(
      length: parsedCards.length,
      initialIndex: initialIdx,
      vsync: this,
    );
    _tabController!.addListener(() {
      if (mounted) setState(() {});
    });

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
            'claimed_days': matchedSub['claimed_days'] ?? [],
            'countdown_timer': matchedSub['countdown_timer'],
            'current_day': matchedSub['current_day'] ?? 1,
          };
        }
      }
    }

    final coinsVal = balanceData?['coins'] ?? balanceData?['user_coins'] ?? 0;

    setState(() {
      _cards = parsedCards;
      _userGems = coinsVal is int ? coinsVal : int.tryParse(coinsVal.toString()) ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _purchaseCard(Map<String, dynamic> card) async {
    if (_isActionInProgress) return;
    final int cardId = card['id'] ?? 1;
    final int priceCoins = card['price_coins'] ?? 0;
    final String cardName = card['name'] ?? 'VIP Privilege Card';

    // Show Confirmation Sheet / Dialog
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E162B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.neonPink, width: 1.5)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.stars_rounded, color: AppColors.gemYellow, size: 48),
              const SizedBox(height: 10),
              Text(
                'Activate $cardName',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: ${card['formatted_price_bdt']} ($priceCoins Gems)\nYou currently have $_userGems Gems',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm & Buy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);

    final res = await VipCardsApiService.purchaseCard(cardId: cardId);

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Card activated! Instant reward credited.'),
          backgroundColor: AppColors.onlineGreen,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadCardsAndSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Insufficient balance or error.'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _claimDailyBonus(Map<String, dynamic> card) async {
    if (_isActionInProgress) return;
    final int cardId = card['id'] ?? 1;

    setState(() => _isActionInProgress = true);

    final res = await VipCardsApiService.claimDailyReward(cardId: cardId);

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Daily check-in reward claimed!'),
          backgroundColor: AppColors.onlineGreen,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadCardsAndSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Already claimed today.'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E162B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.neonPink, width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.gemYellow),
            SizedBox(width: 8),
            Text('VIP Privilege Rules', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Instant Reward:\nUpon purchasing any Weekly or Monthly VIP card, the instant gems are credited to your main wallet balance immediately.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            SizedBox(height: 10),
            Text(
              '2. Daily Check-in Schedule:\nLog into the app daily and open this page to claim your daily bonus gems into your wallet.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            SizedBox(height: 10),
            Text(
              '3. Outfits & Privilege Badges:\nAvatar frames, SVIP crowns, and entry animations are unlocked automatically for the duration of the active card.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It', style: TextStyle(color: AppColors.neonPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _tabController == null || _cards.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B18),
        body: Center(child: CircularProgressIndicator(color: AppColors.neonPink)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Monthly Card',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 22),
            onPressed: _showRulesDialog,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.neonPink,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabAlignment: TabAlignment.start,
              tabs: _cards.map((c) {
                String title = c['name'] ?? 'Card';
                if (title.contains('New User')) {
                  title = 'New User';
                } else if (title.contains('Super Monthly')) {
                  title = 'Super Monthly';
                } else if (title.contains('Luxury Monthly')) {
                  title = 'Luxury Monthly';
                } else if (title.contains('Super Weekly')) {
                  title = 'Super Weekly';
                }
                return Tab(text: title);
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _cards.map((card) => _buildCardTabContent(card)).toList(),
      ),
    );
  }

  Widget _buildCardTabContent(Map<String, dynamic> card) {
    final sub = card['user_subscription'] ?? {};
    final bool isSubscribed = sub['is_subscribed'] == true;
    final bool hasClaimedToday = sub['has_claimed_today'] == true;
    final List schedule = card['daily_schedule'] as List? ?? [];
    final String cardType = card['card_type'] ?? 'new_user';

    // Theme Gradients matching Screenshot 2, 3, 4, 5
    LinearGradient heroGradient;
    Color accentColor;
    if (cardType == 'super_monthly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF2C194D), Color(0xFF19112E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF7C4DFF);
    } else if (cardType == 'luxury_monthly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF142B59), Color(0xFF0B1733)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF2979FF);
    } else if (cardType == 'super_weekly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF0F3826), Color(0xFF091F15)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF00E676);
    } else {
      // New User Weekly Card
      heroGradient = const LinearGradient(
        colors: [Color(0xFF4A1A2E), Color(0xFF250D1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = AppColors.neonPink;
    }

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO CARD BANNER (Matching Screenshot 2, 3, 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card['name'] ?? 'VIP Privilege Card',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text('Get ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${card['total_return_coins']}',
                                    style: const TextStyle(color: AppColors.gemYellow, fontSize: 14, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'by paying 💎 ${card['price_coins']} price',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              // Countdown Timer Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  _formatCountdown(_mockTimerDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 3D Card Graphic on Right
                        Container(
                          width: 80,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: AppColors.neonPink.withValues(alpha: 0.6), blurRadius: 14),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.card_membership_rounded, color: Colors.white, size: 40),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comparison Pill Tag
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        card['banner_tag'] ?? 'Normal Recharge = ${card['instant_reward_coins']} | Card = ${card['total_return_coins']}+outfits',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. REWARDS BREAKDOWN (3 BOXES: Instant + Daily Check-in + Extra)
              Row(
                children: [
                  // Instant Reward
                  Expanded(
                    child: _buildRewardBox(
                      title: 'Instant Reward',
                      amount: '${card['instant_reward_coins']}',
                      icon: Icons.diamond_rounded,
                      iconColor: AppColors.gemYellow,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  // Daily Check-in Bonus
                  Expanded(
                    child: _buildRewardBox(
                      title: 'Daily Check-in Bonus',
                      amount: '${card['daily_checkin_total_coins']}',
                      icon: Icons.card_giftcard_rounded,
                      iconColor: const Color(0xFFFF5252),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  // Extra Reward
                  Expanded(
                    child: Container(
                      height: 84,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181324),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Extra Reward', style: TextStyle(color: Colors.white60, fontSize: 9.5)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B1D3D)),
                                child: const Icon(Icons.lens_blur_rounded, color: Colors.amber, size: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B1D3D)),
                                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.neonPink, size: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B1D3D)),
                                child: const Icon(Icons.style_rounded, color: Colors.cyanAccent, size: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. GET SCHEDULE SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 32, height: 1, color: AppColors.gemYellow.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  const Text(
                    'Get schedule',
                    style: TextStyle(
                      color: AppColors.gemYellow,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 32, height: 1, color: AppColors.gemYellow.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 12),

              // Grid of Schedule Days (4 Columns)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: schedule.length,
                itemBuilder: (context, idx) {
                  final item = schedule[idx];
                  final int day = item['day'] ?? (idx + 1);
                  final dynamic coins = item['coins'] ?? 0;
                  final String? extra = item['extra']?.toString();
                  final List claimedDays = sub['claimed_days'] as List? ?? [];
                  final bool isClaimed = claimedDays.contains(day);

                  String dayLabel;
                  if (day == 1) {
                    dayLabel = '1st';
                  } else if (day == 2) {
                    dayLabel = '2nd';
                  } else if (day == 3) {
                    dayLabel = '3rd';
                  } else {
                    dayLabel = '${day}th';
                  }

                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isClaimed
                          ? const Color(0xFF10281E)
                          : (day == 1 ? const Color(0xFF2A1C3B) : const Color(0xFF151020)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isClaimed
                            ? AppColors.onlineGreen.withValues(alpha: 0.6)
                            : (day == 1 ? AppColors.neonPink.withValues(alpha: 0.5) : Colors.white12),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: isClaimed ? AppColors.onlineGreen : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              'x$coins',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (extra != null && extra.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.neonPink.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              extra,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.neonPink, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (isClaimed) ...[
                          const SizedBox(height: 2),
                          const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 14),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 4. BOTTOM FLOATING ACTION BAR (Buy or Claim)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0A1A).withValues(alpha: 0.95),
              border: const Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              top: false,
              child: isSubscribed
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasClaimedToday ? Colors.grey.shade800 : AppColors.onlineGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                      ),
                      onPressed: (_isActionInProgress || hasClaimedToday) ? null : () => _claimDailyBonus(card),
                      child: _isActionInProgress
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              hasClaimedToday ? 'Today\'s Bonus Claimed ✅' : 'Claim Today\'s Reward',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _isActionInProgress ? null : () => _purchaseCard(card),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: AppColors.neonPink.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isActionInProgress
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  '${card['formatted_price_bdt']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardBox({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF181324),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 9.5),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 3),
              Text(
                amount,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
