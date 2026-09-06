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

class _MyBagScreenState extends State<MyBagScreen> with SingleTickerProviderStateMixin {
  late String _selectedCategory;
  String _selectedStatus = 'unused'; // 'unused', 'used', 'expired'
  bool _isLoading = false;
  BagInventoryData _inventory = const BagInventoryData();
  int _myCoins = 0;

  final List<Map<String, dynamic>> _categories = [
    {
      'slug': 'coupon',
      'name': 'Coupon',
      'name_bn': 'কুপন',
      'icon': Icons.confirmation_number_rounded,
      'color': const Color(0xFFFFB300),
    },
    {
      'slug': 'avatar_frame',
      'name': 'Avatar frame',
      'name_bn': 'এভাটার ফ্রেম',
      'icon': Icons.circle_outlined,
      'color': const Color(0xFF00E5FF),
    },
    {
      'slug': 'chat_style',
      'name': 'Chat style',
      'name_bn': 'চ্যাট স্টাইল',
      'icon': Icons.chat_bubble_rounded,
      'color': const Color(0xFFFF4081),
    },
    {
      'slug': 'profile_card',
      'name': 'Profile card',
      'name_bn': 'প্রোফাইল কার্ড',
      'icon': Icons.badge_rounded,
      'color': const Color(0xFFAB47BC),
    },
    {
      'slug': 'entrance_bubble',
      'name': 'Entrance bubble',
      'name_bn': 'এন্ট্রান্স বাবল',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFFFD54F),
    },
    {
      'slug': 'big_entrance',
      'name': 'Big entrance',
      'name_bn': 'বিগ এন্ট্রান্স',
      'icon': Icons.directions_car_rounded,
      'color': const Color(0xFF2979FF),
    },
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
            'Use "${item.itemName}" to instantly receive ${item.couponCoins > 0 ? item.couponCoins : 500} Gems into your wallet?',
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

    // Call equip / use API
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

  Future<void> _handleUnequip(String category) async {
    final res = await BagApiService.unequipItem(category);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Item unequipped.'), backgroundColor: Colors.orange),
      );
      _loadInventory(forceRefresh: true);
    }
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
        initialChildSize: 0.85,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter items based on current category & status
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
            // Top App Bar & Stage Banner
            _buildHeader(),

            // 6 Horizontal Category Tabs
            _buildCategoryTabs(),
            const SizedBox(height: 12),

            // 3-Segment Status Switcher (Unused, Used, Expired)
            _buildStatusSwitcher(),
            const SizedBox(height: 16),

            // Main Inventory Content Body
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

  /// 1. Top App Bar with Purple Ambient Stage & 3D Center Ticket / Item
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

          // Glowing Stage Spotlight with 3D Category Hero Graphic (Matching Screenshot 1)
          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient Radial Spotlight Glow
                Container(
                  width: 180,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9D4EDD).withValues(alpha: 0.45),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),

                // Dynamic 3D Hero Graphic according to selected category
                _buildHeroCategoryGraphic(),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// 3D Glowing Ticket / Category Representation in Hero Spotlight
  Widget _buildHeroCategoryGraphic() {
    switch (_selectedCategory) {
      case 'coupon':
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotated Back Ticket Shadow
            Transform.rotate(
              angle: -0.10,
              child: Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFD49A00),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Front Gold Ticket with perforated dots and "SALE"
            Container(
              width: 124,
              height: 62,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Left side semi-circle punch
                  Positioned(
                    left: -8,
                    top: 22,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF240C46),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Right side semi-circle punch
                  Positioned(
                    right: -8,
                    top: 22,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF240C46),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Centered SALE text with vertical perforated dots
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            4,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 1.5),
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B6400),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SALE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFFB27B00),
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'avatar_frame':
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFF00E5FF),
                Color(0xFF7C4DFF),
                Color(0xFFFF2A6D),
                Color(0xFF00E5FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF170F2C),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 38),
          ),
        );

      case 'chat_style':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF332014), Color(0xFF211409)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_rounded, color: Color(0xFFFFD54F), size: 20),
              SizedBox(width: 8),
              Text(
                'Hi, Welcome! ✨',
                style: TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        );

      case 'profile_card':
        return Container(
          width: 120,
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94057).withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Colors.white24),
                  SizedBox(width: 6),
                  Text('VIP Card', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 4),
              Text('Chinchins Star', style: TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        );

      case 'entrance_bubble':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF64B5F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withValues(alpha: 0.5),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFFFFD54F), size: 22),
              SizedBox(width: 8),
              Text('Entered Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );

      case 'big_entrance':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1038),
            border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2979FF).withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF448AFF), size: 48),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// 2. 6 Horizontal Category Tabs (Coupon, Avatar frame, Chat style, Profile card, Entrance bubble, Big entrance)
  Widget _buildCategoryTabs() {
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
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['slug'];
          final count = _inventory.counts[cat['slug']] ?? 0;

          return GestureDetector(
            onTap: () => _onCategorySelected(cat['slug']),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF2A1B4E) : const Color(0xFF19122C),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF9D4EDD) : Colors.white10,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            cat['icon'] as IconData,
                            color: isSelected ? Colors.white : Colors.white60,
                            size: 22,
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
                    cat['name'] as String,
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

  /// 3. 3-Segment Filter Switcher: Unused | Used | Expired (Matching Screenshot 1)
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

  /// 4. Empty State matching Screenshot 1 exactly
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
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

  /// 5. Inventory Items 2-Column Grid
  Widget _buildItemsGrid(List<BagItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.76,
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
              // Top Right Equipped Pill or Quantity Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.quantity > 1)
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

              // Item Preview Image
              Expanded(
                child: Center(
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedImageLoader(
                          imageUrl: item.imageUrl!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          _getCategoryIcon(item.category),
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
                  fontSize: 12.5,
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
                    : (item.remainingHuman.isNotEmpty ? item.remainingHuman : '${item.daysValid} days left'),
                style: TextStyle(
                  color: isExpired ? Colors.redAccent : Colors.white54,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),

              // Action Button
              SizedBox(
                width: double.infinity,
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
                            _handleUnequip(item.category);
                          } else {
                            _handleUseOrEquip(item);
                          }
                        },
                  child: Text(
                    isExpired
                        ? 'Expired'
                        : item.category == 'coupon'
                            ? (item.status == 'used' ? 'Redeemed' : 'Use Now')
                            : (isEquipped ? 'Unequip' : 'Equip'),
                    style: TextStyle(
                      color: isExpired ? Colors.white30 : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
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
}

/// 🛍️ Bag Store Modal for purchasing items with Gems
class _BagStoreModal extends StatefulWidget {
  final String initialCategory;
  final int myCoins;
  final ScrollController scrollController;
  final VoidCallback onPurchaseSuccess;

  const _BagStoreModal({
    required this.initialCategory,
    required this.myCoins,
    required this.scrollController,
    required this.onPurchaseSuccess,
  });

  @override
  State<_BagStoreModal> createState() => _BagStoreModalState();
}

class _BagStoreModalState extends State<_BagStoreModal> {
  late String _storeCategory;
  List<BagStoreItem> _catalog = [];
  bool _isLoading = true;
  int _coins = 0;

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
    if (_coins < item.priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Gems to purchase this item. Please recharge.'),
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
          'Buy "${item.name}" for ${item.priceCoins} Gems (${item.isPermanent ? 'Permanent' : '${item.daysValid} Days'})?',
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
          _coins -= item.priceCoins;
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
              const Text(
                '🛍️ Bag Store',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 12),

          // Catalog List
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
                          childAspectRatio: 0.74,
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
                                Expanded(
                                  child: Center(
                                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                        ? CachedImageLoader(imageUrl: item.imageUrl!, width: 64, height: 64, fit: BoxFit.contain)
                                        : const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 48),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.isPermanent ? 'Permanent' : '${item.daysValid} Days',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
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
                                        const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.priceCoins}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
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
