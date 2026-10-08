import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../models/daily_reward_model.dart';
import '../services/daily_rewards_api_service.dart';

class DailyCheckInDialog extends StatefulWidget {
  final DailyRewardStatus? initialStatus;

  const DailyCheckInDialog({
    super.key,
    this.initialStatus,
  });

  /// Static helper to launch the dialog easily anywhere in the app
  static Future<void> show(BuildContext context, {DailyRewardStatus? status}) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (context) => DailyCheckInDialog(initialStatus: status),
    );
  }

  @override
  State<DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<DailyCheckInDialog>
    with SingleTickerProviderStateMixin {
  DailyRewardStatus? _status;
  bool _isLoading = false;
  bool _isClaiming = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? DailyRewardsApiService.cachedStatus;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_status == null) {
      _fetchStatus();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    final fetched = await DailyRewardsApiService.getDailyRewardsStatus(forceRefresh: true);
    if (mounted) {
      setState(() {
        _status = fetched;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleClaim() async {
    if (_isClaiming || _status == null || !_status!.canClaim) return;

    setState(() => _isClaiming = true);
    final result = await DailyRewardsApiService.claimDailyReward();

    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (result['status'] == true) {
      // Instantly update wallet balance globally
      final totalBalance = result['total_balance'];
      if (totalBalance != null) {
        final parsed = totalBalance is int ? totalBalance : int.tryParse('$totalBalance');
        if (parsed != null) {
          WalletApiService.updateCachedCoins(parsed);
        }
      }
      WalletApiService.getWalletBalance(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Claimed successfully! +${result['coins_awarded'] ?? 50} coins added.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Re-fetch to update card states
      await _fetchStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Unable to claim reward right now.'),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default fallback 7 days configuration if API is loading or offline
    final defaultDays = List.generate(7, (index) {
      final dayNum = index + 1;
      final streak = _status?.currentStreak ?? 0;
      final isClaimed = dayNum <= streak;
      final isCurrent = dayNum == streak + 1;
      return DailyRewardDay(
        dayNumber: dayNum,
        rewardCoins: dayNum == 7 ? 100 : 50,
        iconImage: 'https://chinchins.live/uploads/claim/day_$dayNum.svg',
        isClaimed: isClaimed,
        isCurrent: isCurrent,
        isLocked: dayNum > streak + 1,
      );
    });

    final days = (_status?.days.isNotEmpty == true) ? _status!.days : defaultDays;
    final canClaim = _status?.canClaim ?? false;
    final tomorrowCoins = _status?.tomorrowCoins ?? 50;
    final nextDay = _status?.nextDayNumber ?? 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Dialog Card Container (Soft pastel lavender/blue matching reference)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2FD),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Banner with 3D Calendar & Info
                _buildHeaderBanner(tomorrowCoins),
                const SizedBox(height: 14),

                // 7-Day Rewards Grid
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
                else
                  _buildRewardsGrid(days),

                const SizedBox(height: 18),

                // Main Action Button ("Claim" vs "Claimed")
                _buildActionButton(canClaim, nextDay),
              ],
            ),
          ),

          // Top Close (X) Button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF4A4E69),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top purple decorative banner matching the reference UI
  Widget _buildHeaderBanner(int tomorrowCoins) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5352ED), Color(0xFF706FD3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5352ED).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D Calendar & Gift Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                '📅',
                style: TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tomorrow for $tomorrowCoins Reward !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('💎', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '7-day check-in streak can earn gems for one phone call!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 7-Day Rewards layout matching reference: Days 1-6 in rows, Day 7 as wide golden card
  Widget _buildRewardsGrid(List<DailyRewardDay> days) {
    final regularDays = days.take(6).toList();
    final day7 = days.length >= 7 ? days[6] : null;

    return Column(
      children: [
        // Days 1-6 Grid (3 columns x 2 rows)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.92,
          ),
          itemCount: regularDays.length,
          itemBuilder: (context, index) {
            return _buildDayCard(regularDays[index]);
          },
        ),

        // Day 7 Special Gold Reward Card
        if (day7 != null) ...[
          const SizedBox(height: 8),
          _buildDay7SpecialCard(day7),
        ],
      ],
    );
  }

  /// Regular Day Card (Day 1 - 6)
  Widget _buildDayCard(DailyRewardDay day) {
    final isClaimed = day.isClaimed;
    final isCurrent = day.isCurrent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isClaimed
            ? const Color(0xFFD8E2F0)
            : isCurrent
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFE4EDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF6C63FF)
              : isClaimed
                  ? const Color(0xFFCBD6E8)
                  : Colors.white.withValues(alpha: 0.7),
          width: isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isCurrent)
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Day Title
              Text(
                'Day ${day.dayNumber}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isClaimed
                      ? const Color(0xFF8E9AAF)
                      : isCurrent
                          ? const Color(0xFF333333)
                          : const Color(0xFF666666),
                ),
              ),

              // Reward Graphic
              Expanded(
                child: Center(
                  child: _buildRewardIcon(day.iconImage, day.dayNumber, isClaimed),
                ),
              ),

              // Reward Amount Badge (+50)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+${day.rewardCoins}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isClaimed
                          ? const Color(0xFF8E9AAF)
                          : const Color(0xFF4A4E69),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Text('🪙', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),

          // Checkmark Icon on Claimed cards
          if (isClaimed)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF8E9AAF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Day 7 Special Radiant Gold Card
  Widget _buildDay7SpecialCard(DailyRewardDay day) {
    final isClaimed = day.isClaimed;
    final isCurrent = day.isCurrent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isClaimed
            ? const LinearGradient(
                colors: [Color(0xFFE0D8B0), Color(0xFFD0C8A0)],
              )
            : const LinearGradient(
                colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? const Color(0xFFFF6F00) : const Color(0xFFFFE082),
          width: isCurrent ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: isClaimed ? 0.15 : 0.40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Day 7',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isClaimed ? const Color(0xFF7A6830) : const Color(0xFF5D4037),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BIG REWARD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Grand 7-Day Completion Gift',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isClaimed ? const Color(0xFF7A6830) : const Color(0xFF6D4C41),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Reward Badge
          Row(
            children: [
              Text(
                '+${day.rewardCoins}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isClaimed ? const Color(0xFF7A6830) : const Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(width: 4),
              const Text('🪙', style: TextStyle(fontSize: 16)),
              if (isClaimed) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF7A6830), size: 18),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Reward Icon helper (loads SVG/network image from backend, with emoji fallback)
  Widget _buildRewardIcon(String iconUrl, int dayNum, bool isClaimed) {
    if (iconUrl.isNotEmpty && iconUrl.startsWith('http')) {
      if (iconUrl.endsWith('.svg')) {
        return SvgPicture.network(
          iconUrl,
          width: 32,
          height: 32,
          placeholderBuilder: (_) => _fallbackEmoji(dayNum),
        );
      }
      return CachedImageLoader(
        imageUrl: iconUrl,
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      );
    }
    return _fallbackEmoji(dayNum);
  }

  Widget _fallbackEmoji(int dayNum) {
    String emoji = '🪙';
    if (dayNum == 3 || dayNum == 5) emoji = '🎁';
    if (dayNum == 6) emoji = '💎';
    if (dayNum == 7) emoji = '👑';
    return Text(
      emoji,
      style: const TextStyle(fontSize: 24),
    );
  }

  /// Bottom Main Action Button
  Widget _buildActionButton(bool canClaim, int nextDay) {
    if (!canClaim) {
      // Disabled "Claimed" pill button matching the reference UI
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFD0D7E4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Text(
            'Claimed',
            style: TextStyle(
              color: Color(0xFF8A95A6),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // Active Glowing Gradient Claim Button
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: _isClaiming ? null : _handleClaim,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4834D4), Color(0xFF3B28B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: _isClaiming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Claim Day $nextDay Reward',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
