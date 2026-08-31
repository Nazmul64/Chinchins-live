import '../widgets/cached_image_loader.dart';

class GiftItem {
  final String id;
  final int giftId;
  final String name;
  final String category;
  final String emoji;
  final String imageUrl;
  final String? animationUrl;
  final String animationType;
  final String? soundUrl;
  final int coins;
  final String formattedCoins;
  final String bgGradient;
  final int receivedCount;
  final String countLabel;
  final int totalCoins;
  final String formattedTotal;
  final String? badge;
  final bool isBroadcast;
  final int sortOrder;

  const GiftItem({
    required this.id,
    this.giftId = 0,
    required this.name,
    this.category = 'popular',
    this.emoji = '🎁',
    this.imageUrl = '',
    this.animationUrl,
    this.animationType = 'image',
    this.soundUrl,
    required this.coins,
    this.formattedCoins = '',
    this.bgGradient = 'purple',
    this.receivedCount = 0,
    this.countLabel = '',
    this.totalCoins = 0,
    this.formattedTotal = '',
    this.badge,
    this.isBroadcast = false,
    this.sortOrder = 0,
  });

  /// Helper to format raw integer coins into K/M strings (e.g. 17700 -> 17.70K, 10000 -> 10K, 500 -> 500)
  static String formatCoinValue(int coinAmount) {
    if (coinAmount >= 1000000) {
      final val = coinAmount / 1000000.0;
      return val == val.roundToDouble()
          ? '${val.toInt()}M'
          : '${val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}M';
    } else if (coinAmount >= 1000) {
      final val = coinAmount / 1000.0;
      return val == val.roundToDouble()
          ? '${val.toInt()}K'
          : '${val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}K';
    }
    return coinAmount.toString();
  }

  /// Get effective display coin tag (e.g. "17.70K")
  String get displayCoins {
    if (formattedCoins.isNotEmpty) return formattedCoins;
    return formatCoinValue(coins);
  }

  /// Get effective multiplier text (e.g. "x2", "x32")
  String get displayCount {
    if (countLabel.isNotEmpty) return countLabel;
    if (receivedCount > 0) return 'x$receivedCount';
    return 'x1';
  }

  /// Factory constructor to parse gift JSON from REST API
  factory GiftItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['gift_id'] ?? json['id'] ?? 0;
    final int parsedGiftId = rawId is int ? rawId : (int.tryParse('$rawId') ?? 0);
    final String strId = parsedGiftId > 0 ? parsedGiftId.toString() : (json['id']?.toString() ?? '0');

    final int coinsVal = json['coins'] is int ? json['coins'] : (int.tryParse('${json['coins']}') ?? 0);
    final int qty = json['quantity'] is int
        ? json['quantity']
        : (json['received_count'] is int ? json['received_count'] : (int.tryParse('${json['quantity'] ?? json['received_count']}') ?? 0));
    final int totalCoinsVal = json['total_coins'] is int
        ? json['total_coins']
        : (int.tryParse('${json['total_coins']}') ?? (coinsVal * (qty > 0 ? qty : 1)));

    final String rawImage = json['image_url'] ?? json['image'] ?? json['photo'] ?? '';
    final String normalizedImg = CachedImageLoader.normalize(rawImage);

    final String? rawAnim = json['animation_url']?.toString() ?? json['animation_full_url']?.toString() ?? json['animation']?.toString();
    final String? normalizedAnim = (rawAnim != null && rawAnim.isNotEmpty) ? CachedImageLoader.normalize(rawAnim) : null;

    final String nameStr = json['name']?.toString() ?? 'Gift';
    final String countLbl = json['count_label']?.toString() ?? (qty > 0 ? 'x$qty' : 'x1');
    final String fmtCoins = json['formatted_coins']?.toString() ??
        json['display_coins']?.toString() ??
        formatCoinValue(coinsVal);
    final String fmtTotal = json['formatted_total']?.toString() ?? formatCoinValue(totalCoinsVal);

    // Map common gifts to emojis if needed as fallback
    String giftEmoji = json['emoji']?.toString() ?? '🎁';
    if (giftEmoji == '🎁') {
      final lowerName = nameStr.toLowerCase();
      if (lowerName.contains('rose') || lowerName.contains('flower')) {
        giftEmoji = '🌹';
      } else if (lowerName.contains('couple') || lowerName.contains('romance') || lowerName.contains('love')) {
        giftEmoji = '💖';
      } else if (lowerName.contains('car') || lowerName.contains('supercar')) {
        giftEmoji = '🏎️';
      } else if (lowerName.contains('castle') || lowerName.contains('palace')) {
        giftEmoji = '🏰';
      } else if (lowerName.contains('dragon')) {
        giftEmoji = '🐉';
      } else if (lowerName.contains('ship') || lowerName.contains('space')) {
        giftEmoji = '🚀';
      } else if (lowerName.contains('cake')) {
        giftEmoji = '🎂';
      } else if (lowerName.contains('chest') || lowerName.contains('treasure')) {
        giftEmoji = '💎';
      } else if (lowerName.contains('crown')) {
        giftEmoji = '👑';
      } else if (lowerName.contains('lamp') || lowerName.contains('genie')) {
        giftEmoji = '🪔';
      }
    }

    return GiftItem(
      id: strId,
      giftId: parsedGiftId,
      name: nameStr,
      category: json['category']?.toString() ?? 'popular',
      emoji: giftEmoji,
      imageUrl: normalizedImg,
      animationUrl: normalizedAnim,
      animationType: json['animation_type']?.toString() ?? 'image',
      soundUrl: json['sound_url']?.toString(),
      coins: coinsVal,
      formattedCoins: fmtCoins,
      bgGradient: json['bg_gradient']?.toString() ?? 'purple',
      receivedCount: qty,
      countLabel: countLbl,
      totalCoins: totalCoinsVal,
      formattedTotal: fmtTotal,
      badge: json['badge']?.toString(),
      isBroadcast: json['is_broadcast'] == true || json['is_broadcast'] == 1 || json['is_broadcast'] == '1',
      sortOrder: json['sort_order'] is int ? json['sort_order'] : (int.tryParse('${json['sort_order']}') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': giftId > 0 ? giftId : int.tryParse(id) ?? 0,
      'gift_id': giftId > 0 ? giftId : int.tryParse(id) ?? 0,
      'name': name,
      'category': category,
      'emoji': emoji,
      'image_url': imageUrl,
      'animation_url': animationUrl,
      'animation_type': animationType,
      'sound_url': soundUrl,
      'coins': coins,
      'formatted_coins': formattedCoins,
      'received_count': receivedCount,
      'quantity': receivedCount,
      'count_label': countLabel,
      'total_coins': totalCoins,
      'formatted_total': formattedTotal,
      'badge': badge,
      'is_broadcast': isBroadcast,
      'sort_order': sortOrder,
    };
  }
}

/// ReceivedGiftItem alias for profile & gifts received full page
typedef ReceivedGiftItem = GiftItem;

/// Complete data model for User's Received Gifts API response
class UserGiftsData {
  final Map<String, dynamic>? user;
  final CharmLevelInfo charmLevel;
  final TopFanInfo topFan;
  final GiftsSummary summary;
  final List<GiftItem> profilePreviewGifts;
  final List<GiftItem> giftsReceived;

  const UserGiftsData({
    this.user,
    required this.charmLevel,
    required this.topFan,
    required this.summary,
    required this.profilePreviewGifts,
    required this.giftsReceived,
  });

  factory UserGiftsData.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    final Map<String, dynamic> charmJson = data['charm_level'] is Map
        ? Map<String, dynamic>.from(data['charm_level'] as Map)
        : <String, dynamic>{};

    final Map<String, dynamic> topFanJson = data['top_fan'] is Map
        ? Map<String, dynamic>.from(data['top_fan'] as Map)
        : <String, dynamic>{};

    final Map<String, dynamic> summaryJson = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};

    List<GiftItem> previewList = [];
    if (data['profile_preview_gifts'] is List) {
      previewList = (data['profile_preview_gifts'] as List)
          .whereType<Map>()
          .map((item) => GiftItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<GiftItem> fullList = [];
    if (data['gifts_received'] is List) {
      fullList = (data['gifts_received'] as List)
          .whereType<Map>()
          .map((item) => GiftItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    // If preview list was empty but full list exists, take first 8
    if (previewList.isEmpty && fullList.isNotEmpty) {
      previewList = fullList.take(8).toList();
    }

    return UserGiftsData(
      user: data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null,
      charmLevel: CharmLevelInfo.fromJson(charmJson),
      topFan: TopFanInfo.fromJson(topFanJson),
      summary: GiftsSummary.fromJson(summaryJson),
      profilePreviewGifts: previewList,
      giftsReceived: fullList,
    );
  }
}

class CharmLevelInfo {
  final int level;
  final String levelTag;
  final int progress;

  const CharmLevelInfo({
    this.level = 6,
    this.levelTag = 'Lv6',
    this.progress = 75,
  });

  factory CharmLevelInfo.fromJson(Map<String, dynamic> json) {
    final rawLvl = json['level'] ?? 6;
    final int parsedLvl = rawLvl is int ? rawLvl : (int.tryParse('$rawLvl') ?? 6);
    return CharmLevelInfo(
      level: parsedLvl,
      levelTag: json['level_tag']?.toString() ?? 'Lv$parsedLvl',
      progress: json['progress'] is int ? json['progress'] : (int.tryParse('${json['progress']}') ?? 75),
    );
  }
}

class TopFanInfo {
  final int id;
  final String accountId;
  final String name;
  final String avatarUrl;
  final int fanCoins;
  final String formatted;

  const TopFanInfo({
    this.id = 45,
    this.accountId = '1000293841',
    this.name = 'Sajid',
    this.avatarUrl = '',
    this.fanCoins = 54200,
    this.formatted = '54.20K',
  });

  factory TopFanInfo.fromJson(Map<String, dynamic> json) {
    return TopFanInfo(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id']}') ?? 0),
      accountId: json['account_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sajid',
      avatarUrl: CachedImageLoader.normalize(json['avatar_url']?.toString()),
      fanCoins: json['fan_coins'] is int ? json['fan_coins'] : (int.tryParse('${json['fan_coins']}') ?? 0),
      formatted: json['formatted']?.toString() ?? '54.20K',
    );
  }
}

class GiftsSummary {
  final int totalUniqueGifts;
  final int totalItemsCount;
  final int totalCoins;
  final String formattedCoins;

  const GiftsSummary({
    this.totalUniqueGifts = 0,
    this.totalItemsCount = 0,
    this.totalCoins = 0,
    this.formattedCoins = '0',
  });

  factory GiftsSummary.fromJson(Map<String, dynamic> json) {
    return GiftsSummary(
      totalUniqueGifts: json['total_unique_gifts'] is int ? json['total_unique_gifts'] : 0,
      totalItemsCount: json['total_items_count'] is int ? json['total_items_count'] : 0,
      totalCoins: json['total_coins'] is int ? json['total_coins'] : 0,
      formattedCoins: json['formatted_coins']?.toString() ?? '0',
    );
  }
}
