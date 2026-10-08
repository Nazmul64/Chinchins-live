class DailyRewardDay {
  final int dayNumber;
  final int rewardCoins;
  final String iconImage;
  final bool isClaimed;
  final bool isCurrent;
  final bool isLocked;

  const DailyRewardDay({
    required this.dayNumber,
    required this.rewardCoins,
    required this.iconImage,
    required this.isClaimed,
    required this.isCurrent,
    required this.isLocked,
  });

  factory DailyRewardDay.fromJson(Map<String, dynamic> json) {
    return DailyRewardDay(
      dayNumber: json['day_number'] is int
          ? json['day_number']
          : int.tryParse(json['day_number']?.toString() ?? '1') ?? 1,
      rewardCoins: json['reward_coins'] is int
          ? json['reward_coins']
          : (json['coins'] is int
              ? json['coins']
              : int.tryParse(json['reward_coins']?.toString() ?? json['coins']?.toString() ?? '50') ?? 50),
      iconImage: json['icon_image']?.toString() ?? json['image_url']?.toString() ?? json['icon']?.toString() ?? '',
      isClaimed: json['is_claimed'] == true,
      isCurrent: json['is_current'] == true,
      isLocked: json['is_locked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_number': dayNumber,
      'reward_coins': rewardCoins,
      'icon_image': iconImage,
      'is_claimed': isClaimed,
      'is_current': isCurrent,
      'is_locked': isLocked,
    };
  }
}

class DailyRewardStatus {
  final bool status;
  final bool shouldOpenPopup;
  final bool canClaim;
  final int currentStreak;
  final int nextDayNumber;
  final DateTime? nextClaimAt;
  final int tomorrowCoins;
  final String tomorrowText;
  final int userCurrentCoins;
  final List<DailyRewardDay> days;

  const DailyRewardStatus({
    required this.status,
    required this.shouldOpenPopup,
    required this.canClaim,
    required this.currentStreak,
    required this.nextDayNumber,
    this.nextClaimAt,
    this.tomorrowCoins = 50,
    this.tomorrowText = 'Tomorrow for 50 Reward!',
    this.userCurrentCoins = 0,
    required this.days,
  });

  factory DailyRewardStatus.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] is List ? json['days'] as List : [];
    final parsedDays = rawDays.map((d) => DailyRewardDay.fromJson(Map<String, dynamic>.from(d as Map))).toList();

    DateTime? nextClaim;
    if (json['next_claim_at'] != null) {
      nextClaim = DateTime.tryParse(json['next_claim_at'].toString());
    } else if (json['next_available_at'] != null) {
      nextClaim = DateTime.tryParse(json['next_available_at'].toString());
    }

    final tomorrow = json['tomorrow_reward'] is Map ? json['tomorrow_reward'] : {};
    final tCoins = tomorrow['coins'] is int
        ? tomorrow['coins']
        : int.tryParse(tomorrow['coins']?.toString() ?? '50') ?? 50;
    final tText = tomorrow['text']?.toString() ?? 'Tomorrow for $tCoins Reward!';

    return DailyRewardStatus(
      status: json['status'] == true,
      shouldOpenPopup: json['should_open_popup'] == true,
      canClaim: json['can_claim'] == true,
      currentStreak: json['current_streak'] is int
          ? json['current_streak']
          : int.tryParse(json['current_streak']?.toString() ?? '0') ?? 0,
      nextDayNumber: json['next_day_number'] is int
          ? json['next_day_number']
          : int.tryParse(json['next_day_number']?.toString() ?? '1') ?? 1,
      nextClaimAt: nextClaim,
      tomorrowCoins: tCoins,
      tomorrowText: tText,
      userCurrentCoins: json['user_current_coins'] is int
          ? json['user_current_coins']
          : int.tryParse(json['user_current_coins']?.toString() ?? '0') ?? 0,
      days: parsedDays,
    );
  }
}
