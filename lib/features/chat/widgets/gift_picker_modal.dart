import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';

class GiftPickerModal extends StatefulWidget {
  final ValueChanged<GiftItem> onGiftSelected;
  final dynamic receiverId;
  final String? receiverName;
  final String? receiverAvatarUrl;
  final String? streamId;

  const GiftPickerModal({
    super.key,
    required this.onGiftSelected,
    this.receiverId,
    this.receiverName,
    this.receiverAvatarUrl,
    this.streamId,
  });

  /// Static helper to display the Gift Tray Modal anywhere
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<GiftItem> onGiftSelected,
    dynamic receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
    String? streamId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => GiftPickerModal(
        onGiftSelected: onGiftSelected,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverAvatarUrl: receiverAvatarUrl,
        streamId: streamId,
      ),
    );
  }

  @override
  State<GiftPickerModal> createState() => _GiftPickerModalState();
}

class _GiftPickerModalState extends State<GiftPickerModal> {
  int _selectedGiftIndex = 0;
  String _selectedCategory = 'hot';
  List<Map<String, dynamic>> _categories = [];
  List<GiftItem> _allGifts = [];
  List<GiftItem> _filteredGifts = [];
  int _userCoins = 45000;
  String _formattedBalance = '45K';
  bool _isLoading = true;
  bool _isSending = false;
  int _selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    _categories = GiftsApiService.getPredefinedGiftCategories();
    _loadCatalogAndBalance();
  }

  Future<void> _loadCatalogAndBalance() async {
    // 1. Fetch user balance in real-time
    try {
      final balanceData = await WalletApiService.getWalletBalance();
      if (balanceData != null && mounted) {
        final coins = balanceData['coins'] ?? balanceData['total_coins'] ?? balanceData['balance'];
        if (coins != null) {
          final int parsedCoins = coins is int ? coins : int.tryParse('$coins') ?? 45000;
          setState(() {
            _userCoins = parsedCoins;
            _formattedBalance = GiftItem.formatCoinValue(parsedCoins);
          });
        }
      }
    } catch (_) {}

    // 2. Fetch full catalog from backend
    final fullData = await GiftsApiService.getGiftsCatalogFull(
      category: _selectedCategory,
    );

    if (mounted) {
      final list = fullData['gifts'] as List<GiftItem>? ?? [];
      final cats = fullData['categories_list'] as List<Map<String, dynamic>>? ?? [];

      setState(() {
        if (cats.isNotEmpty) {
          _categories = cats;
        }
        _allGifts = list;
        _filterGiftsByCategory(_selectedCategory);
        _isLoading = false;
      });
    }
  }

  void _filterGiftsByCategory(String cat) {
    if (cat == 'all') {
      _filteredGifts = List.from(_allGifts);
    } else {
      _filteredGifts = _allGifts
          .where((g) => g.category.toLowerCase() == cat.toLowerCase())
          .toList();
      if (_filteredGifts.isEmpty && _allGifts.isNotEmpty) {
        _filteredGifts = List.from(_allGifts);
      }
    }
    if (_selectedGiftIndex >= _filteredGifts.length) {
      _selectedGiftIndex = 0;
    }
  }

  void _onCategorySelected(String catKey) async {
    setState(() {
      _selectedCategory = catKey;
      _selectedGiftIndex = 0;
    });

    _filterGiftsByCategory(catKey);

    // Also fetch from API in background if needed
    final list = await GiftsApiService.getGiftsCatalog(category: catKey);
    if (mounted && list.isNotEmpty) {
      setState(() {
        _allGifts = list;
        _filterGiftsByCategory(catKey);
      });
    }
  }

  void _openRechargeSheet() {
    Navigator.pop(context); // Close gift tray
    RechargeGemsSheet.show(
      context,
      receiverId: widget.receiverId,
      receiverName: widget.receiverName,
      receiverAvatarUrl: widget.receiverAvatarUrl,
      onRechargeSuccess: () {
        _loadCatalogAndBalance();
      },
    );
  }

  Future<void> _handleSendGift() async {
    if (_filteredGifts.isEmpty || _selectedGiftIndex >= _filteredGifts.length) return;
    final gift = _filteredGifts[_selectedGiftIndex];
    final totalCost = gift.coins * _selectedQuantity;

    // Check balance
    if (_userCoins < totalCost) {
      // Insufficient balance -> Prompt Recharge Sheet
      _openRechargeSheet();
      return;
    }

    setState(() => _isSending = true);

    // Call RESTful Send Gift API
    if (widget.receiverId != null) {
      final giftId = gift.giftId > 0 ? gift.giftId : int.tryParse(gift.id) ?? 1;
      final res = await GiftsApiService.sendGift(
        receiverId: widget.receiverId,
        giftId: giftId,
        quantity: _selectedQuantity,
        context: widget.streamId != null ? 'live_stream' : 'chat',
        streamId: widget.streamId,
      );

      if (res['status'] == false && (res['code'] == 402 || res['shortage'] != null)) {
        if (!mounted) return;
        setState(() => _isSending = false);
        _openRechargeSheet();
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _userCoins -= totalCost;
      _formattedBalance = GiftItem.formatCoinValue(_userCoins);
      _isSending = false;
    });

    widget.onGiftSelected(gift);
    Navigator.pop(context); // Close tray

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sent ${gift.name} (x$_selectedQuantity) 🎁',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF43F5E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGift = (_filteredGifts.isNotEmpty && _selectedGiftIndex < _filteredGifts.length)
        ? _filteredGifts[_selectedGiftIndex]
        : null;
    final int totalCost = selectedGift != null ? (selectedGift.coins * _selectedQuantity) : 0;

    return Container(
      height: 480,
      decoration: const BoxDecoration(
        color: Color(0xFF131524),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 1. Header Row (User Coin Balance & Recharge Action)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _openRechargeSheet,
                    child: Row(
                      children: [
                        const Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          _formattedBalance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openRechargeSheet,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Recharge >',
                          style: TextStyle(
                            color: Color(0xFFF43F5E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 12 Categories Horizontal Scrolling Bar
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final catKey = cat['key']?.toString() ?? 'all';
                  final isSelected = catKey == _selectedCategory;
                  final count = cat['count'] != null ? ' (${cat['count']})' : '';
                  final emoji = cat['emoji']?.toString() ?? '🎁';
                  final label = cat['label']?.toString() ?? catKey.toUpperCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$emoji $label$count'),
                      selected: isSelected,
                      selectedColor: const Color(0xFFF43F5E),
                      backgroundColor: const Color(0xFF1E2139),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFF43F5E) : Colors.transparent,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) => _onCategorySelected(catKey),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // 3. 4-Column Gifts Grid View
            Expanded(
              child: _isLoading && _filteredGifts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF43F5E)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.76,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _filteredGifts.length,
                      itemBuilder: (context, index) {
                        final gift = _filteredGifts[index];
                        final isSelected = _selectedGiftIndex == index;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGiftIndex = index;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2A1B3D)
                                  : const Color(0xFF1E2139),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF43F5E)
                                    : Colors.white.withValues(alpha: 0.06),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                // Top Badge (e.g. HOT, MUST WIN, x500 WIN, SVIP)
                                if (gift.badge != null && gift.badge!.isNotEmpty)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
                                        ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(13),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        gift.badge!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Center Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Center(
                                          child: gift.imageUrl.isNotEmpty
                                              ? CachedImageLoader(
                                                  imageUrl: gift.imageUrl,
                                                  fit: BoxFit.contain,
                                                )
                                              : Text(
                                                  gift.emoji,
                                                  style: const TextStyle(fontSize: 32),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        gift.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 10),
                                          const SizedBox(width: 2),
                                          Text(
                                            gift.displayCoins,
                                            style: const TextStyle(
                                              color: Color(0xFFF59E0B),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 4. Quantity Multiplier Chips & Gradient Send Action
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  // Multiplier Chips: x1, x5, x10, x99, x520, x1314
                  Row(
                    children: [1, 5, 10, 99].map((q) {
                      final isQSelected = _selectedQuantity == q;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedQuantity = q;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: isQSelected ? const Color(0xFFF43F5E) : const Color(0xFF1E2139),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isQSelected ? Colors.transparent : Colors.white12,
                            ),
                          ),
                          child: Text(
                            'x$q',
                            style: TextStyle(
                              color: isQSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),

                  // Big Send Button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF43F5E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 4,
                        ),
                        onPressed: selectedGift == null || _isSending ? null : _handleSendGift,
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                selectedGift != null
                                    ? 'Send Gift ($totalCost 💎)'
                                    : 'Send Gift 🎁',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
