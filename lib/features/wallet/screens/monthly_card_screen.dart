import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
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
  int _remainingSeconds = 604740; // Default 7 days

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
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          }
        });
      }
    });
  }

  String _formatCountdown(int totalSecs) {
    if (totalSecs <= 0) return '00 : 00 : 00 : 00';
    final days = totalSecs ~/ 86400;
    final hours = (totalSecs % 86400) ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    return '${days.toString().padLeft(2, '0')} : ${hours.toString().padLeft(2, '0')} : ${mins.toString().padLeft(2, '0')} : ${secs.toString().padLeft(2, '0')}';
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
            'remaining_seconds': matchedSub['remaining_seconds'] ?? _remainingSeconds,
          };
          if (matchedSub['remaining_seconds'] != null) {
            _remainingSeconds = matchedSub['remaining_seconds'];
          }
        }
      }
    }

    final coinsVal = balanceData?['coins'] ?? balanceData?['user_coins'] ?? 0;

    setState(() {
      _cards = parsedCards;
      _userGems = coinsVal is int ? coinsVal : (int.tryParse(coinsVal.toString()) ?? 0);
      _isLoading = false;
    });
  }

  Future<void> _purchaseCard(Map<String, dynamic> card) async {
    if (_isActionInProgress) return;
    final int cardId = card['id'] ?? 1;
    final int priceCoins = card['price_coins'] ?? 0;
    final String cardName = card['name'] ?? 'VIP Privilege Card';
    final int instantCoins = card['instant_reward_coins'] ?? 0;

    // Show Confirmation Sheet / Dialog
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1429),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(color: AppColors.neonPink.withValues(alpha: 0.5), blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 14),
              Text(
                'Activate $cardName',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: ${card['formatted_price_bdt'] ?? 'BDT 300.00'} ($priceCoins Gems)\nInstant $instantCoins Gems will be credited immediately!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                    const SizedBox(width: 4),
                    Text('Your Current Balance: $_userGems Gems', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm & Buy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res['message'] ?? 'Card activated! Instant reward credited.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.onlineGreen,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadCardsAndSession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to activate VIP card.'),
          backgroundColor: const Color(0xFFB71C1C),
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
      final claimedCoins = res['data']?['claimed_coins'] ?? 300;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res['message'] ?? '+$claimedCoins Gems added to your wallet!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.onlineGreen,
          duration: const Duration(seconds: 4),
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
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neonPink, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.gemYellow, size: 24),
            SizedBox(width: 8),
            Text('VIP Privilege Rules', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Instant Reward:\nUpon purchasing any Weekly or Monthly VIP card, instant gems are credited to your main wallet immediately.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                '2. Daily Check-in Schedule:\nLog in every 24 hours to claim your scheduled daily bonus gems directly into your main balance.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 10),
              Text(
                '3. Outfits & Exclusive Perks:\nAvatar frames, SVIP crowns, entry effects, and lucky cards are unlocked automatically for the entire validity period.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
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
          'Monthly & Weekly Card',
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
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 14),
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
    final List perks = card['extra_rewards'] as List? ?? [];
    final String cardType = card['card_type'] ?? 'new_user';
    final int currentDay = sub['current_day'] ?? 1;

    // Theme Gradients & Accent Colors
    LinearGradient heroGradient;
    Color accentColor;
    if (cardType == 'super_monthly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF3B1768), Color(0xFF1F0D3D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF7C4DFF);
    } else if (cardType == 'luxury_monthly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF0D3268), Color(0xFF061838)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF2979FF);
    } else if (cardType == 'super_weekly') {
      heroGradient = const LinearGradient(
        colors: [Color(0xFF0E472E), Color(0xFF072417)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFF00E676);
    } else {
      // New User Weekly Card
      heroGradient = const LinearGradient(
        colors: [Color(0xFF5E1B3D), Color(0xFF2E0D1F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      accentColor = const Color(0xFFFF4081);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO CARD BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: heroGradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      card['name'] ?? 'VIP Privilege Card',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (card['badge_text'] != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        card['badge_text'],
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('Get ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${card['total_return_coins']}',
                                    style: const TextStyle(color: AppColors.gemYellow, fontSize: 14, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    ' by paying 💎 ${card['price_coins']}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Live Countdown Timer Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, color: AppColors.gemYellow, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      _formatCountdown(_remainingSeconds),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // VIP Graphic Icon
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 16),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.card_membership_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comparison Banner Tag
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
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

              // 2. REWARDS 3-BOX SUMMARY
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricBox(
                      title: 'Instant Reward',
                      value: '💎 ${card['instant_reward_coins']}',
                      highlightColor: AppColors.gemYellow,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: _buildSummaryMetricBox(
                      title: 'Daily Check-in',
                      value: '🎁 ${card['daily_checkin_total_coins']}',
                      highlightColor: const Color(0xFFFF5252),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: _buildSummaryMetricBox(
                      title: 'Extra Reward',
                      value: '${perks.isNotEmpty ? perks.length : 3} Perks',
                      highlightColor: const Color(0xFF67E8F9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. GET SCHEDULE SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 36, height: 1, color: AppColors.gemYellow.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  const Text(
                    '— Get schedule —',
                    style: TextStyle(
                      color: AppColors.gemYellow,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 36, height: 1, color: AppColors.gemYellow.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 12),

              // Responsive Schedule Grid (4 Columns)
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
                  final bool isToday = isSubscribed && (day == currentDay);

                  String dayLabel = item['day_label'] ?? (day == 1 ? '1st' : (day == 2 ? '2nd' : (day == 3 ? '3rd' : '${day}th')));

                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isClaimed
                          ? const Color(0xFF0E2B1E)
                          : (isToday
                              ? const Color(0xFF2B1D3D)
                              : (day == 1 ? const Color(0xFF231633) : const Color(0xFF140F20))),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isClaimed
                            ? AppColors.onlineGreen
                            : (isToday
                                ? accentColor
                                : (day == 1 ? accentColor.withValues(alpha: 0.5) : Colors.white12)),
                        width: isToday || isClaimed ? 1.5 : 1.0,
                      ),
                      boxShadow: isToday
                          ? [
                              BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: isClaimed ? AppColors.onlineGreen : Colors.white70,
                            fontSize: 10.5,
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
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (extra != null && extra.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              extra,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: accentColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (isClaimed) ...[
                          const SizedBox(height: 2),
                          const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 14),
                        ] else if (isToday && !hasClaimedToday) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.onlineGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Claim', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),

              // 4. EXTRA PERKS & OUTFITS SHOWCASE
              if (perks.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 36, height: 1, color: const Color(0xFF67E8F9).withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    const Text(
                      '— Extra Outfits & Perks —',
                      style: TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 36, height: 1, color: const Color(0xFF67E8F9).withValues(alpha: 0.6)),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: perks.length,
                  itemBuilder: (context, pIdx) {
                    final perk = perks[pIdx];
                    final String title = perk['title'] ?? 'Exclusive Perk';
                    final String tag = perk['tag'] ?? 'Privilege';
                    final String? imgUrl = perk['image_url'] ?? perk['image'];

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161124),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF281C3D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: (imgUrl != null && imgUrl.isNotEmpty)
                                ? CachedImageLoader(imageUrl: imgUrl, fit: BoxFit.contain)
                                : const Icon(Icons.workspace_premium_rounded, color: AppColors.gemYellow, size: 22),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        // 5. BOTTOM FLOATING ACTION CTA BUTTON
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
                              hasClaimedToday ? "Today's Bonus Claimed ✅" : "Claim Today's Bonus (Day $currentDay)",
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
                            BoxShadow(color: AppColors.neonPink.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isActionInProgress
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  '${card['formatted_price_bdt'] ?? 'BDT 300.00'} (${card['price_coins']} 💎)',
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

  Widget _buildSummaryMetricBox({
    required String title,
    required String value,
    required Color highlightColor,
  }) {
    return Container(
      height: 72,
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
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(color: highlightColor, fontSize: 12.5, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
