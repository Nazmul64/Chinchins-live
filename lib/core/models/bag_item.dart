class BagCategory {
  final String slug;
  final String name;
  final String nameBn;
  final String icon;
  final String iconUrl;
  final int count;

  const BagCategory({
    required this.slug,
    required this.name,
    required this.nameBn,
    required this.icon,
    this.iconUrl = '',
    this.count = 0,
  });

  factory BagCategory.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] ?? json['category'] ?? 'coupon').toString().toLowerCase();
    String fallbackIconUrl = '';
    switch (slug) {
      case 'coupon':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg';
        break;
      case 'avatar_frame':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/frame_royal_amethyst.svg';
        break;
      case 'chat_style':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/chat_bubble_neon_pink.svg';
        break;
      case 'profile_card':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/profile_card_aurora_galaxy.svg';
        break;
      case 'entrance_bubble':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold_crown.svg';
        break;
      case 'big_entrance':
        fallbackIconUrl = 'https://chinchins.live/uploads/my_bag/big_entrance_sports_car.svg';
        break;
    }

    return BagCategory(
      slug: slug,
      name: json['name']?.toString() ?? _defaultCategoryName(slug),
      nameBn: json['name_bn']?.toString() ?? _defaultCategoryNameBn(slug),
      icon: json['icon']?.toString() ?? slug,
      iconUrl: json['icon_url']?.toString() ?? json['image_url']?.toString() ?? fallbackIconUrl,
      count: json['count'] is int ? json['count'] : int.tryParse('${json['count']}') ?? 0,
    );
  }

  static String _defaultCategoryName(String slug) {
    switch (slug) {
      case 'coupon':
        return 'Coupon';
      case 'avatar_frame':
        return 'Avatar frame';
      case 'chat_style':
        return 'Chat style';
      case 'profile_card':
        return 'Profile card';
      case 'entrance_bubble':
        return 'Entrance bubble';
      case 'big_entrance':
        return 'Big entrance';
      default:
        return slug;
    }
  }

  static String _defaultCategoryNameBn(String slug) {
    switch (slug) {
      case 'coupon':
        return 'কুপন';
      case 'avatar_frame':
        return 'এভাটার ফ্রেম';
      case 'chat_style':
        return 'চ্যাট স্টাইল';
      case 'profile_card':
        return 'প্রোফাইল কার্ড';
      case 'entrance_bubble':
        return 'এন্ট্রান্স বাবল';
      case 'big_entrance':
        return 'বিগ এন্ট্রান্স';
      default:
        return slug;
    }
  }

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'name_bn': nameBn,
    'icon': icon,
    'icon_url': iconUrl,
    'count': count,
  };
}

class BagItem {
  final int id; // user_bag_item_id or id
  final int userBagItemId;
  final int bagItemId;
  final int userId;
  final int itemId;
  final String itemName;
  final String category;
  final String? categoryName;
  final String? imageUrl;
  final String? iconUrl;
  final String? animationUrl;
  final String status; // 'unused', 'used', 'expired'
  final bool isEquipped;
  final int quantity;
  final int daysValid;
  final String durationText;
  final String? badge;
  final bool isPermanent;
  final bool isGiftable;
  final int remainingSeconds;
  final String remainingHuman;
  final bool isExpired;
  final int priceCoins;
  final int couponCoins;
  final String? description;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const BagItem({
    required this.id,
    required this.userBagItemId,
    required this.bagItemId,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.category,
    this.categoryName,
    this.imageUrl,
    this.iconUrl,
    this.animationUrl,
    this.status = 'unused',
    this.isEquipped = false,
    this.quantity = 1,
    this.daysValid = 30,
    this.durationText = '',
    this.badge,
    this.isPermanent = false,
    this.isGiftable = true,
    this.remainingSeconds = 0,
    this.remainingHuman = '',
    this.isExpired = false,
    this.priceCoins = 0,
    this.couponCoins = 0,
    this.description,
    this.createdAt,
    this.expiresAt,
  });

  factory BagItem.fromJson(Map<String, dynamic> json) {
    final rawItem = (json['item'] is Map<String, dynamic>) ? json['item'] as Map<String, dynamic> : null;

    final userBagId = json['user_bag_item_id'] ?? json['id'] ?? 0;
    final bagId = json['bag_item_id'] ?? json['item_id'] ?? rawItem?['id'] ?? 0;
    final name = json['name'] ?? json['item_name'] ?? rawItem?['name'] ?? 'Inventory Item';
    final cat = (json['category'] ?? rawItem?['category'] ?? 'coupon').toString().toLowerCase();
    final img = json['image_url'] ?? json['icon_url'] ?? rawItem?['image_url'] ?? rawItem?['icon_url'] ?? json['image'];
    final icon = json['icon_url'] ?? json['image_url'] ?? rawItem?['icon_url'] ?? rawItem?['image_url'];
    final anim = json['animation_url'] ?? rawItem?['animation_url'] ?? json['animation'];
    final coins = json['price_coins'] ?? rawItem?['price_coins'] ?? 0;
    final couponVal = json['coupon_coins'] ?? rawItem?['coupon_coins'] ?? json['reward_coins'] ?? 0;
    final badge = json['badge']?.toString() ?? rawItem?['badge']?.toString();
    final durText = json['duration_text']?.toString() ?? rawItem?['duration_text']?.toString() ?? '';

    return BagItem(
      id: userBagId is int ? userBagId : int.tryParse('$userBagId') ?? 0,
      userBagItemId: userBagId is int ? userBagId : int.tryParse('$userBagId') ?? 0,
      bagItemId: bagId is int ? bagId : int.tryParse('$bagId') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse('${json['user_id']}') ?? 0,
      itemId: bagId is int ? bagId : int.tryParse('$bagId') ?? 0,
      itemName: name.toString(),
      category: cat,
      categoryName: json['category_name']?.toString() ?? rawItem?['category_name']?.toString(),
      imageUrl: img?.toString(),
      iconUrl: icon?.toString(),
      animationUrl: anim?.toString(),
      status: (json['status']?.toString() ?? 'unused').toLowerCase(),
      isEquipped: json['is_equipped'] == true || json['is_equipped'] == 1,
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse('${json['quantity']}') ?? 1,
      daysValid: json['duration_days'] is int
          ? json['duration_days']
          : (json['days_valid'] is int ? json['days_valid'] : int.tryParse('${json['days_valid'] ?? json['duration_days']}') ?? 30),
      durationText: durText,
      badge: badge,
      isPermanent: json['is_permanent'] == true || json['is_permanent'] == 1 || rawItem?['is_permanent'] == true,
      isGiftable: json['is_giftable'] == null || json['is_giftable'] == true || json['is_giftable'] == 1,
      remainingSeconds: json['remaining_seconds'] is int ? json['remaining_seconds'] : int.tryParse('${json['remaining_seconds']}') ?? 0,
      remainingHuman: json['remaining_human']?.toString() ?? (durText.isNotEmpty ? durText : ''),
      isExpired: json['is_expired'] == true || json['is_expired'] == 1 || (json['status']?.toString().toLowerCase() == 'expired'),
      priceCoins: coins is int ? coins : int.tryParse('$coins') ?? 0,
      couponCoins: couponVal is int ? couponVal : int.tryParse('$couponVal') ?? 0,
      description: json['description']?.toString() ?? rawItem?['description']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_bag_item_id': userBagItemId,
    'bag_item_id': bagItemId,
    'user_id': userId,
    'item_id': itemId,
    'item_name': itemName,
    'category': category,
    'category_name': categoryName,
    'image_url': imageUrl,
    'icon_url': iconUrl,
    'animation_url': animationUrl,
    'status': status,
    'is_equipped': isEquipped,
    'quantity': quantity,
    'days_valid': daysValid,
    'duration_text': durationText,
    'badge': badge,
    'is_permanent': isPermanent,
    'is_giftable': isGiftable,
    'remaining_seconds': remainingSeconds,
    'remaining_human': remainingHuman,
    'is_expired': isExpired,
    'price_coins': priceCoins,
    'coupon_coins': couponCoins,
    'description': description,
    'created_at': createdAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };
}

class BagStoreItem {
  final int id;
  final String name;
  final String category;
  final String categoryName;
  final int priceCoins;
  final double priceBdt;
  final String formattedPrice;
  final int couponCoins;
  final String? imageUrl;
  final String? iconUrl;
  final String? animationUrl;
  final int daysValid;
  final String durationText;
  final String? badge;
  final bool isPermanent;
  final bool canGift;
  final bool isGiftable;
  final bool isActive;
  final String? description;

  const BagStoreItem({
    required this.id,
    required this.name,
    required this.category,
    this.categoryName = '',
    required this.priceCoins,
    this.priceBdt = 0.0,
    this.formattedPrice = '',
    this.couponCoins = 0,
    this.imageUrl,
    this.iconUrl,
    this.animationUrl,
    this.daysValid = 30,
    this.durationText = '',
    this.badge,
    this.isPermanent = false,
    this.canGift = true,
    this.isGiftable = true,
    this.isActive = true,
    this.description,
  });

  factory BagStoreItem.fromJson(Map<String, dynamic> json) {
    final coins = json['price_coins'] is int ? json['price_coins'] as int : int.tryParse('${json['price_coins']}') ?? 0;
    final bdt = json['price_bdt'] is num ? (json['price_bdt'] as num).toDouble() : double.tryParse('${json['price_bdt']}') ?? 0.0;
    final formatted = json['formatted_price']?.toString() ?? (coins == 0 ? 'Free' : '$coins Gems');
    final durDays = json['duration_days'] is int
        ? json['duration_days'] as int
        : (json['days_valid'] is int ? json['days_valid'] as int : int.tryParse('${json['duration_days'] ?? json['days_valid']}') ?? 30);
    final durText = json['duration_text']?.toString() ?? '$durDays Days';

    return BagStoreItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? 'Store Item',
      category: (json['category']?.toString() ?? 'coupon').toLowerCase(),
      categoryName: json['category_name']?.toString() ?? '',
      priceCoins: coins,
      priceBdt: bdt,
      formattedPrice: formatted,
      couponCoins: json['coupon_coins'] is int ? json['coupon_coins'] : int.tryParse('${json['coupon_coins']}') ?? 0,
      imageUrl: json['image_url']?.toString() ?? json['icon_url']?.toString(),
      iconUrl: json['icon_url']?.toString() ?? json['image_url']?.toString(),
      animationUrl: json['animation_url']?.toString(),
      daysValid: durDays,
      durationText: durText,
      badge: json['badge']?.toString(),
      isPermanent: json['is_permanent'] == true || json['is_permanent'] == 1,
      canGift: json['can_gift'] == null || json['can_gift'] == true || json['can_gift'] == 1 || json['is_giftable'] == true,
      isGiftable: json['is_giftable'] == null || json['is_giftable'] == true || json['is_giftable'] == 1 || json['can_gift'] == true,
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'category_name': categoryName,
    'price_coins': priceCoins,
    'price_bdt': priceBdt,
    'formatted_price': formattedPrice,
    'coupon_coins': couponCoins,
    'image_url': imageUrl,
    'icon_url': iconUrl,
    'animation_url': animationUrl,
    'days_valid': daysValid,
    'duration_text': durationText,
    'badge': badge,
    'is_permanent': isPermanent,
    'can_gift': canGift,
    'is_giftable': isGiftable,
    'is_active': isActive,
    'description': description,
  };
}

class BagInventoryData {
  final String activeCategory;
  final String activeStatus;
  final List<BagCategory> categories;
  final Map<String, dynamic> equipped;
  final Map<String, int> counts;
  final List<BagItem> items;
  final int totalCount;
  final int? userCoins;

  const BagInventoryData({
    this.activeCategory = 'all',
    this.activeStatus = 'all',
    this.categories = const [],
    this.equipped = const {},
    this.counts = const {},
    this.items = const [],
    this.totalCount = 0,
    this.userCoins,
  });

  factory BagInventoryData.fromJson(Map<String, dynamic> json) {
    final root = (json['data'] is Map<String, dynamic>) ? json['data'] as Map<String, dynamic> : json;

    final categoriesList = (root['categories'] is List)
        ? (root['categories'] as List)
            .whereType<Map<String, dynamic>>()
            .map((c) => BagCategory.fromJson(c))
            .toList()
        : <BagCategory>[];

    final itemsList = (root['items'] is List)
        ? (root['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map((i) => BagItem.fromJson(i))
            .toList()
        : (root['data'] is List)
            ? (root['data'] as List)
                .whereType<Map<String, dynamic>>()
                .map((i) => BagItem.fromJson(i))
                .toList()
            : <BagItem>[];

    final countsMap = <String, int>{};
    if (root['counts'] is Map) {
      root['counts'].forEach((k, v) {
        countsMap[k.toString()] = v is int ? v : int.tryParse('$v') ?? 0;
      });
    }

    // Also calculate counts from categoriesList if categories have counts
    for (final c in categoriesList) {
      if (c.count > 0) {
        countsMap[c.slug] = c.count;
      }
    }

    final equippedMap = (root['equipped'] is Map<String, dynamic>)
        ? root['equipped'] as Map<String, dynamic>
        : <String, dynamic>{};

    final userObj = root['user'] is Map ? root['user'] as Map : null;
    final userCoins = userObj != null ? (userObj['coins'] is int ? userObj['coins'] as int : int.tryParse('${userObj['coins']}')) : null;

    return BagInventoryData(
      activeCategory: (root['active_tab'] ?? root['active_category'] ?? 'all').toString(),
      activeStatus: (root['active_status'] ?? 'all').toString(),
      categories: categoriesList,
      equipped: equippedMap,
      counts: countsMap,
      items: itemsList,
      totalCount: root['total_count'] is int ? root['total_count'] : int.tryParse('${root['total_count']}') ?? itemsList.length,
      userCoins: userCoins,
    );
  }
}
