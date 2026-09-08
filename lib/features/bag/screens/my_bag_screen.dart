import 'package:flutter/material.dart';
import '../../../core/models/bag_item.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../services/bag_api_service.dart';

class MyBagScreen extends StatefulWidget {
  final String initialCategory;

  const MyBagScreen({
    super.key,
    this.initialCategory = 'coupon',
  });

  @override
  State<MyBagScreen> createState() => _MyBagScreenState();
}

class _MyBagScreenState extends State<MyBagScreen> {
  late String _selectedCategory;
  String _selectedStatus = 'unused'; // 'unused', 'used', 'expired'
  bool _isLoading = false;
  BagInventoryData _inventory = const BagInventoryData();
  int _myCoins = 0;

  final List<BagCategory> _defaultCategories = const [
    BagCategory(
      slug: 'coupon',
      name: 'Coupon',
      nameBn: 'কুপন',
      icon: 'coupon',
      iconUrl: 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg',
    ),
    BagCategory(
      slug: 'avatar_frame',
      name: 'Avatar frame',
      nameBn: 'এভাটার ফ্রেম',
      icon: 'avatar_frame',
      iconUrl: 'https://chinchins.live/uploads/my_bag/frame_royal_amethyst.svg',
    ),
    BagCategory(
      slug: 'chat_style',
      name: 'Chat style',
      nameBn: 'চ্যাট স্টাইল',
      icon: 'chat_style',
      iconUrl: 'https://chinchins.live/uploads/my_bag/chat_bubble_neon_pink.svg',
    ),
    BagCategory(
      slug: 'profile_card',
      name: 'Profile card',
      nameBn: 'প্রোফাইল কার্ড',
      icon: 'profile_card',
      iconUrl: 'https://chinchins.live/uploads/my_bag/profile_card_aurora_galaxy.svg',
    ),
    BagCategory(
      slug: 'entrance_bubble',
      name: 'Entrance bubble',
      nameBn: 'এন্ট্রান্স বাবল',
      icon: 'entrance_bubble',
      iconUrl: 'https://chinchins.live/uploads/my_bag/entrance_bubble_gold_crown.svg',
    ),
    BagCategory(
      slug: 'big_entrance',
      name: 'Big entrance',
      nameBn: 'বিগ এন্ট্রান্স',
      icon: 'big_entrance',
      iconUrl: 'https://chinchins.live/uploads/my_bag/big_entrance_sports_car.svg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadWalletBalance();
    _loadInventory();
  }

  Future<void> _loadWalletBalance() async {
    final balance = await WalletApiService.getWalletBalance();
    if (balance != null && mounted) {
      setState(() {
        _myCoins = balance['coins'] is int ? balance['coins'] : (int.tryParse('${balance['coins']}') ?? _myCoins);
      });
    }
  }

  Future<void> _loadInventory({bool forceRefresh = false}) async {
    if (_inventory.items.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await BagApiService.getBagInventory(
        category: _selectedCategory,
        status: _selectedStatus,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _inventory = data;
          if (data.userCoins != null) {
            _myCoins = data.userCoins!;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategorySelected(String slug) {
    if (_selectedCategory != slug) {
      setState(() {
        _selectedCategory = slug;
      });
      _loadInventory();
    }
  }

  void _onStatusSelected(String status) {
    if (_selectedStatus != status) {
      setState(() {
        _selectedStatus = status;
      });
      _loadInventory();
    }
  }

  Future<void> _handleUseOrEquip(BagItem item) async {
    if (item.status == 'expired' || item.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item has expired.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (item.category == 'coupon') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1633),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.stars_rounded, color: Color(0xFFFFD54F)),
              SizedBox(width: 8),
              Text('Redeem Coupon', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Use "${item.itemName}" to instantly receive extra gems bonus into your wallet?',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A3FFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Redeem Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final res = await BagApiService.useOrEquipItem(item.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Item updated successfully!'),
          backgroundColor: const Color(0xFF8A3FFC),
        ),
      );
      _loadWalletBalance();
      _loadInventory(forceRefresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to update item.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleUnequip(String category, {int? userBagItemId}) async {
    final res = await BagApiService.unequipItem(category, userBagItemId: userBagItemId);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Item unequipped.'), backgroundColor: Colors.orange),
      );
      _loadInventory(forceRefresh: true);
    }
  }

  void _openGiftDialog({
    int? userBagItemId,
    int? bagItemId,
    required String itemName,
    String? imageUrl,
    String? badge,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => GiftBagItemDialog(
        userBagItemId: userBagItemId,
        bagItemId: bagItemId,
        itemName: itemName,
        imageUrl: imageUrl,
        badge: badge,
        onGiftSuccess: () {
          _loadWalletBalance();
          _loadInventory(forceRefresh: true);
        },
      ),
    );
  }

  void _openStoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF130F24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _BagStoreModal(
            initialCategory: _selectedCategory,
            myCoins: _myCoins,
            scrollController: scrollController,
            onPurchaseSuccess: () {
              _loadWalletBalance();
              _loadInventory(forceRefresh: true);
            },
            onGiftTap: (item) {
              _openGiftDialog(
                bagItemId: item.id,
                itemName: item.name,
                imageUrl: item.imageUrl,
                badge: item.badge,
              );
            },
          );
        },
      ),
    );
  }

  List<BagCategory> get _categoriesList {
    if (_inventory.categories.isNotEmpty) {
      return _inventory.categories;
    }
    return _defaultCategories;
  }

  String _getCategoryIconUrl(String slug) {
    for (final cat in _categoriesList) {
      if (cat.slug == slug && cat.iconUrl.isNotEmpty) {
        return cat.iconUrl;
      }
    }
    for (final cat in _defaultCategories) {
      if (cat.slug == slug) {
        return cat.iconUrl;
      }
    }
    return 'https://chinchins.live/uploads/my_bag/coupon_sale_yellow.svg';
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _inventory.items.where((item) {
      final matchCat = _selectedCategory == 'all' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchStatus = _selectedStatus == 'all' ||
          (_selectedStatus == 'unused' && item.status == 'unused' && !item.isExpired) ||
          (_selectedStatus == 'used' && (item.status == 'used' || item.isEquipped)) ||
          (_selectedStatus == 'expired' && (item.status == 'expired' || item.isExpired));
      return matchCat && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar & Dynamic Spotlight Stage
            _buildHeader(),

            // 2. 6 Horizontal Category Tabs with Clean SVGs
            _buildCategoryTabs(),
            const SizedBox(height: 12),

            // 3. 3-Segment Status Switcher (Unused, Used, Expired)
            _buildStatusSwitcher(),
            const SizedBox(height: 14),

            // 4. Main Inventory Content Body
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF8A3FFC),
                backgroundColor: const Color(0xFF1E1633),
                onRefresh: () => _loadInventory(forceRefresh: true),
                child: _isLoading && filteredItems.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8A3FFC)),
                      )
                    : filteredItems.isEmpty
                        ? _buildEmptyState()
                        : _buildItemsGrid(filteredItems),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top App Bar with Purple Ambient Stage & Dynamic 3D Hero Graphic
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF381266),
            Color(0xFF240C46),
            Color(0xFF130A28),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // AppBar Row: Back Button, "My Bag", "..." Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'My Bag',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
                  color: const Color(0xFF22163D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'store') {
                      _openStoreSheet();
                    } else if (val == 'refresh') {
                      _loadInventory(forceRefresh: true);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'store',
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag_rounded, color: Color(0xFF9D4EDD), size: 18),
                          SizedBox(width: 10),
                          Text('Bag Store', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 10),
                          Text('Refresh Inventory', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Glowing Stage Spotlight with Dynamic Hero Graphic
          Container(
            height: 126,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient Radial Glow
                Container(
                  width: 180,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9D4EDD).withValues(alpha: 0.5),
                        blurRadius: 55,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),

                // Dynamic Category Hero Visual
                _buildHeroCategoryGraphic(),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Dynamic 3D / SVG Hero Visual for Current Category
  Widget _buildHeroCategoryGraphic() {
    final heroUrl = _getCategoryIconUrl(_selectedCategory);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          height: 80,
          child: Center(
            child: CachedImageLoader(
              imageUrl: heroUrl,
              width: 120,
              height: 76,
              fit: BoxFit.contain,
              placeholder: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFFFD54F), size: 48),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. 6 Horizontal Category Tabs with dynamic icons and live counts
  Widget _buildCategoryTabs() {
    final cats = _categoriesList;

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0B1E),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: cats.length,
        itemBuilder: (context, index) {
          final cat = cats[index];
          final isSelected = _selectedCategory == cat.slug;
          final count = _inventory.counts[cat.slug] ?? cat.count;

          return GestureDetector(
            onTap: () => _onCategorySelected(cat.slug),
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Category Icon Container
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF2A1B4E) : const Color(0xFF19122C),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF9D4EDD) : Colors.white12,
                            width: isSelected ? 1.8 : 0.8,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: cat.iconUrl.isNotEmpty
                              ? CachedImageLoader(
                                  imageUrl: cat.iconUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  placeholder: Icon(
                                    _getCategoryFallbackIcon(cat.slug),
                                    color: isSelected ? Colors.white : Colors.white60,
                                    size: 20,
                                  ),
                                )
                              : Icon(
                                  _getCategoryFallbackIcon(cat.slug),
                                  color: isSelected ? Colors.white : Colors.white60,
                                  size: 20,
                                ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2A6D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Category Name
                  Text(
                    cat.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Bottom Active Indicator Line
                  const SizedBox(height: 3),
                  Container(
                    width: 18,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF9D4EDD) : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryFallbackIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'coupon':
        return Icons.confirmation_number_rounded;
      case 'avatar_frame':
        return Icons.circle_outlined;
      case 'chat_style':
        return Icons.chat_bubble_rounded;
      case 'profile_card':
        return Icons.badge_rounded;
      case 'entrance_bubble':
        return Icons.shield_rounded;
      case 'big_entrance':
        return Icons.directions_car_rounded;
      default:
        return Icons.backpack_rounded;
    }
  }

  /// 3. 3-Segment Filter Switcher: Unused | Used | Expired
  Widget _buildStatusSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1735),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _buildStatusTab('Unused', 'unused'),
          _buildStatusTab('Used', 'used'),
          _buildStatusTab('Expired', 'expired'),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onStatusSelected(status),
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE2D4F8) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF3B1569) : Colors.white60,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 4. Empty State with Visit Store button
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'You have no items yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A3FFC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Visit Bag Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _openStoreSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. Inventory Items 2-Column Grid with Gifting & Equip Support
  Widget _buildItemsGrid(List<BagItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isEquipped = item.isEquipped || item.status == 'used';
        final isExpired = item.isExpired || item.status == 'expired';

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A132F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isEquipped ? const Color(0xFF9D4EDD) : Colors.white10,
              width: isEquipped ? 1.5 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Badges Row (Quantity, Badge, Equipped / Expired Status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.badge != null && item.badge!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF5252), Color(0xFFFF7A00)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (item.quantity > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('x${item.quantity}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    )
                  else
                    const SizedBox.shrink(),

                  if (isEquipped)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D4EDD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Equipped', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  else if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Expired', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Item Dynamic Image / Clean SVG
              Expanded(
                child: Center(
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedImageLoader(
                          imageUrl: item.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          _getCategoryFallbackIcon(item.category),
                          color: const Color(0xFFFFD54F),
                          size: 48,
                        ),
                ),
              ),
              const SizedBox(height: 6),

              // Item Name
              Text(
                item.itemName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),

              // Remaining Validity Human Text
              Text(
                item.isPermanent
                    ? 'Permanent'
                    : (item.remainingHuman.isNotEmpty ? item.remainingHuman : (item.durationText.isNotEmpty ? item.durationText : '${item.daysValid} days left')),
                style: TextStyle(
                  color: isExpired ? Colors.redAccent : Colors.white54,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),

              // Action Buttons Row (Use/Equip + Gift Button)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpired
                              ? Colors.white12
                              : isEquipped
                                  ? const Color(0xFF34175E)
                                  : (item.category == 'coupon' ? const Color(0xFFFF9800) : const Color(0xFF8A3FFC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: isExpired
                            ? null
                            : () {
                                if (isEquipped && item.category != 'coupon') {
                                  _handleUnequip(item.category, userBagItemId: item.userBagItemId);
                                } else {
                                  _handleUseOrEquip(item);
                                }
                              },
                        child: Text(
                          isExpired
                              ? 'Expired'
                              : item.category == 'coupon'
                                  ? (item.status == 'used' ? 'Redeemed' : 'Redeem')
                                  : (isEquipped ? 'Unequip' : 'Equip'),
                          style: TextStyle(
                            color: isExpired ? Colors.white30 : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isExpired && item.isGiftable) ...[
                    const SizedBox(width: 6),
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1B4E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD54F), size: 15),
                        padding: EdgeInsets.zero,
                        tooltip: 'Gift to user',
                        onPressed: () => _openGiftDialog(
                          userBagItemId: item.userBagItemId > 0 ? item.userBagItemId : item.id,
                          itemName: item.itemName,
                          imageUrl: item.imageUrl,
                          badge: item.badge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 🛍️ Bag Store Modal for purchasing & gifting items
class _BagStoreModal extends StatefulWidget {
  final String initialCategory;
  final int myCoins;
  final ScrollController scrollController;
  final VoidCallback onPurchaseSuccess;
  final Function(BagStoreItem item) onGiftTap;

  const _BagStoreModal({
    required this.initialCategory,
    required this.myCoins,
    required this.scrollController,
    required this.onPurchaseSuccess,
    required this.onGiftTap,
  });

  @override
  State<_BagStoreModal> createState() => _BagStoreModalState();
}

class _BagStoreModalState extends State<_BagStoreModal> {
  late String _storeCategory;
  List<BagStoreItem> _catalog = [];
  bool _isLoading = true;
  int _coins = 0;

  final List<Map<String, String>> _categories = const [
    {'slug': 'all', 'name': 'All'},
    {'slug': 'coupon', 'name': 'Coupon'},
    {'slug': 'avatar_frame', 'name': 'Avatar frame'},
    {'slug': 'chat_style', 'name': 'Chat style'},
    {'slug': 'profile_card', 'name': 'Profile card'},
    {'slug': 'entrance_bubble', 'name': 'Entrance bubble'},
    {'slug': 'big_entrance', 'name': 'Big entrance'},
  ];

  @override
  void initState() {
    super.initState();
    _storeCategory = widget.initialCategory;
    _coins = widget.myCoins;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    final items = await BagApiService.getStoreCatalog(category: _storeCategory);
    if (mounted) {
      setState(() {
        _catalog = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchase(BagStoreItem item) async {
    if (item.priceCoins > 0 && _coins < item.priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Gems (${item.priceCoins} required, you have $_coins). Please recharge.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1633),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          'Buy "${item.name}" for ${item.formattedPrice} (${item.isPermanent ? 'Permanent' : item.durationText})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8A3FFC)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await BagApiService.purchaseItem(item.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Purchased successfully! Added to your bag.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        if (res['new_balance'] != null) {
          _coins = res['new_balance'] is int ? res['new_balance'] : int.tryParse('${res['new_balance']}') ?? _coins;
        } else {
          _coins = (_coins - item.priceCoins).clamp(0, 99999999);
        }
      });
      widget.onPurchaseSuccess();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to purchase.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row with Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    '🛍️ Bag Store',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF23163E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_coins Gems',
                      style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final c = _categories[idx];
                final isSelected = _storeCategory == c['slug'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      c['name']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF8A3FFC),
                    backgroundColor: const Color(0xFF1E1736),
                    side: BorderSide(color: isSelected ? const Color(0xFF9D4EDD) : Colors.white10),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _storeCategory = c['slug']!);
                        _loadCatalog();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Catalog Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A3FFC)))
                : _catalog.isEmpty
                    ? const Center(
                        child: Text('No store items available in this category.', style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        controller: widget.scrollController,
                        itemCount: _catalog.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final item = _catalog[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1736),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                // Badge & Duration Top Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (item.badge != null && item.badge!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFFFF5252), Color(0xFFFF7A00)]),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.badge!,
                                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    Text(
                                      item.isPermanent ? 'Permanent' : item.durationText,
                                      style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // SVG Graphic
                                Expanded(
                                  child: Center(
                                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                        ? CachedImageLoader(
                                            imageUrl: item.imageUrl!,
                                            width: 68,
                                            height: 68,
                                            fit: BoxFit.contain,
                                          )
                                        : const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 44),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Name
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),

                                // Buy & Gift Actions
                                Row(
                                  children: [
                                    // Buy Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 28,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF8A3FFC),
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          onPressed: () => _purchase(item),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (item.priceCoins > 0) ...[
                                                const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 11),
                                                const SizedBox(width: 3),
                                              ],
                                              Text(
                                                item.priceCoins == 0 ? 'Free' : '${item.priceCoins}',
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (item.canGift) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        height: 28,
                                        width: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E1A47),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 0.8),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD54F), size: 14),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Gift to user',
                                          onPressed: () {
                                            Navigator.pop(context);
                                            widget.onGiftTap(item);
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// 🎁 Gift Bag Item Dialog with 8-Digit Account ID Search
class GiftBagItemDialog extends StatefulWidget {
  final int? userBagItemId;
  final int? bagItemId;
  final String itemName;
  final String? imageUrl;
  final String? badge;
  final VoidCallback onGiftSuccess;

  const GiftBagItemDialog({
    super.key,
    this.userBagItemId,
    this.bagItemId,
    required this.itemName,
    this.imageUrl,
    this.badge,
    required this.onGiftSuccess,
  });

  @override
  State<GiftBagItemDialog> createState() => _GiftBagItemDialogState();
}

class _GiftBagItemDialogState extends State<GiftBagItemDialog> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUser(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundUser = null;
    });

    final user = await BagApiService.searchUserByAccountId(clean);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (user != null) {
        _foundUser = user;
      } else {
        _errorMessage = 'No user found with Account ID or name "$clean".';
      }
    });
  }

  Future<void> _sendGift() async {
    if (_foundUser == null) return;
    setState(() => _isSending = true);

    final receiverAccountId = _foundUser!['account_id']?.toString() ?? _foundUser!['id']?.toString() ?? '';
    final receiverId = _foundUser!['id'] is int ? _foundUser!['id'] as int : int.tryParse('${_foundUser!['id']}');

    final res = await BagApiService.giftItem(
      receiverAccountId: receiverAccountId,
      bagItemId: widget.bagItemId,
      userBagItemId: widget.userBagItemId,
      receiverId: receiverId,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (res['success'] == true) {
      widget.onGiftSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Successfully gifted ${widget.itemName}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to send gift. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1430),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      title: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD54F), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gift "${widget.itemName}"',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Preview Pill
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    CachedImageLoader(imageUrl: widget.imageUrl!, width: 36, height: 36, fit: BoxFit.contain)
                  else
                    const Icon(Icons.backpack_rounded, color: Color(0xFFFFD54F), size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const Text('Direct transfer to recipient\'s My Bag', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search by Account ID TextField
            const Text(
              'Recipient 8-digit Account ID',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter Account ID (e.g. 602281635)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                filled: true,
                fillColor: const Color(0xFF241A40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF9D4EDD)),
                  onPressed: () => _searchUser(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 1.5),
                ),
              ),
              onSubmitted: _searchUser,
            ),
            const SizedBox(height: 12),

            // Search State Body
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(color: Color(0xFF8A3FFC), strokeWidth: 2.5),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              )
            else if (_foundUser != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF261947),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF9D4EDD), width: 1),
                ),
                child: Row(
                  children: [
                    fastAvatar(_foundUser!['avatar_url'] ?? _foundUser!['avatar'], size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _foundUser!['display_name'] ?? _foundUser!['name'] ?? 'User',
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_foundUser!['country_flag'] != null && _foundUser!['country_flag'].toString().isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(_foundUser!['country_flag'].toString(), style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${_foundUser!['account_id'] ?? _foundUser!['id']} • ${_foundUser!['level'] ?? 'Lv1'}',
                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 20),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8A3FFC),
            disabledBackgroundColor: Colors.white12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: (_foundUser != null && !_isSending) ? _sendGift : null,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Send Gift 🎁', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
