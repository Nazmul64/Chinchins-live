class BagCategory {
  final String slug;
  final String name;
  final String nameBn;
  final String icon;
  final int count;

  const BagCategory({
    required this.slug,
    required this.name,
    required this.nameBn,
    required this.icon,
    this.count = 0,
  });

  factory BagCategory.fromJson(Map<String, dynamic> json) {
    return BagCategory(
      slug: json['slug']?.toString() ?? 'all',
      name: json['name']?.toString() ?? '',
      nameBn: json['name_bn']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      count: json['count'] is int ? json['count'] : int.tryParse('${json['count']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'name_bn': nameBn,
    'icon': icon,
    'count': count,
  };
}

class BagItem {
  final int id;
  final int userId;
  final int itemId;
  final String itemName;
  final String category;
  final String? categoryName;
  final String? imageUrl;
  final String? animationUrl;
  final String status; // 'unused', 'used', 'expired'
  final bool isEquipped;
  final int quantity;
  final int daysValid;
  final bool isPermanent;
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
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.category,
    this.categoryName,
    this.imageUrl,
    this.animationUrl,
    this.status = 'unused',
    this.isEquipped = false,
    this.quantity = 1,
    this.daysValid = 30,
    this.isPermanent = false,
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

    final name = json['item_name'] ?? rawItem?['name'] ?? json['name'] ?? 'Inventory Item';
    final cat = json['category'] ?? rawItem?['category'] ?? 'avatar_frame';
    final img = json['image_url'] ?? rawItem?['image_url'] ?? json['image'];
    final anim = json['animation_url'] ?? rawItem?['animation_url'] ?? json['animation'];
    final coins = json['price_coins'] ?? rawItem?['price_coins'] ?? 0;
    final couponVal = json['coupon_coins'] ?? rawItem?['coupon_coins'] ?? json['reward_coins'] ?? 0;

    return BagItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse('${json['user_id']}') ?? 0,
      itemId: json['item_id'] is int ? json['item_id'] : int.tryParse('${json['item_id']}') ?? (rawItem?['id'] ?? 0),
      itemName: name.toString(),
      category: cat.toString().toLowerCase(),
      categoryName: json['category_name']?.toString() ?? rawItem?['category_name']?.toString(),
      imageUrl: img?.toString(),
      animationUrl: anim?.toString(),
      status: (json['status']?.toString() ?? 'unused').toLowerCase(),
      isEquipped: json['is_equipped'] == true || json['is_equipped'] == 1,
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse('${json['quantity']}') ?? 1,
      daysValid: json['days_valid'] is int ? json['days_valid'] : int.tryParse('${json['days_valid']}') ?? (rawItem?['days_valid'] ?? 30),
      isPermanent: json['is_permanent'] == true || json['is_permanent'] == 1 || rawItem?['is_permanent'] == true,
      remainingSeconds: json['remaining_seconds'] is int ? json['remaining_seconds'] : int.tryParse('${json['remaining_seconds']}') ?? 0,
      remainingHuman: json['remaining_human']?.toString() ?? '',
      isExpired: json['is_expired'] == true || json['is_expired'] == 1,
      priceCoins: coins is int ? coins : int.tryParse('$coins') ?? 0,
      couponCoins: couponVal is int ? couponVal : int.tryParse('$couponVal') ?? 0,
      description: json['description']?.toString() ?? rawItem?['description']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'item_id': itemId,
    'item_name': itemName,
    'category': category,
    'category_name': categoryName,
    'image_url': imageUrl,
    'animation_url': animationUrl,
    'status': status,
    'is_equipped': isEquipped,
    'quantity': quantity,
    'days_valid': daysValid,
    'is_permanent': isPermanent,
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
  final int couponCoins;
  final String? imageUrl;
  final String? animationUrl;
  final int daysValid;
  final bool isPermanent;
  final bool canGift;
  final bool isActive;
  final String? description;

  const BagStoreItem({
    required this.id,
    required this.name,
    required this.category,
    this.categoryName = '',
    required this.priceCoins,
    this.couponCoins = 0,
    this.imageUrl,
    this.animationUrl,
    this.daysValid = 30,
    this.isPermanent = false,
    this.canGift = true,
    this.isActive = true,
    this.description,
  });

  factory BagStoreItem.fromJson(Map<String, dynamic> json) {
    return BagStoreItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? 'Store Item',
      category: (json['category']?.toString() ?? 'avatar_frame').toLowerCase(),
      categoryName: json['category_name']?.toString() ?? '',
      priceCoins: json['price_coins'] is int ? json['price_coins'] : int.tryParse('${json['price_coins']}') ?? 0,
      couponCoins: json['coupon_coins'] is int ? json['coupon_coins'] : int.tryParse('${json['coupon_coins']}') ?? 0,
      imageUrl: json['image_url']?.toString(),
      animationUrl: json['animation_url']?.toString(),
      daysValid: json['days_valid'] is int ? json['days_valid'] : int.tryParse('${json['days_valid']}') ?? 30,
      isPermanent: json['is_permanent'] == true || json['is_permanent'] == 1,
      canGift: json['can_gift'] == null || json['can_gift'] == true || json['can_gift'] == 1,
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
    'coupon_coins': couponCoins,
    'image_url': imageUrl,
    'animation_url': animationUrl,
    'days_valid': daysValid,
    'is_permanent': isPermanent,
    'can_gift': canGift,
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

  const BagInventoryData({
    this.activeCategory = 'all',
    this.activeStatus = 'all',
    this.categories = const [],
    this.equipped = const {},
    this.counts = const {},
    this.items = const [],
  });

  factory BagInventoryData.fromJson(Map<String, dynamic> json) {
    final categoriesList = (json['categories'] is List)
        ? (json['categories'] as List)
            .whereType<Map<String, dynamic>>()
            .map((c) => BagCategory.fromJson(c))
            .toList()
        : <BagCategory>[];

    final itemsList = (json['items'] is List)
        ? (json['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map((i) => BagItem.fromJson(i))
            .toList()
        : (json['data'] is List)
            ? (json['data'] as List)
                .whereType<Map<String, dynamic>>()
                .map((i) => BagItem.fromJson(i))
                .toList()
            : <BagItem>[];

    final countsMap = <String, int>{};
    if (json['counts'] is Map) {
      json['counts'].forEach((k, v) {
        countsMap[k.toString()] = v is int ? v : int.tryParse('$v') ?? 0;
      });
    }

    final equippedMap = (json['equipped'] is Map<String, dynamic>)
        ? json['equipped'] as Map<String, dynamic>
        : <String, dynamic>{};

    return BagInventoryData(
      activeCategory: json['active_category']?.toString() ?? 'all',
      activeStatus: json['active_status']?.toString() ?? 'all',
      categories: categoriesList,
      equipped: equippedMap,
      counts: countsMap,
      items: itemsList,
    );
  }
}
