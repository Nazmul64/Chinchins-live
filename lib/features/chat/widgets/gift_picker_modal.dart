import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';

class GiftPickerModal extends StatefulWidget {
  final ValueChanged<GiftItem> onGiftSelected;
  final dynamic receiverId;
  final String? streamId;

  const GiftPickerModal({
    super.key,
    required this.onGiftSelected,
    this.receiverId,
    this.streamId,
  });

  @override
  State<GiftPickerModal> createState() => _GiftPickerModalState();
}

class _GiftPickerModalState extends State<GiftPickerModal> {
  int _selectedGiftIndex = 0;
  String _selectedCategory = 'all';
  List<GiftItem> _gifts = [];
  int _userCoins = 50000;
  bool _isLoading = false;
  int _selectedQuantity = 1;

  final List<String> _categories = [
    'all',
    'popular',
    'luxury',
    'desi',
    'birds',
    'romantic',
    'effects',
    'vip',
    'emojis',
    'stickers',
  ];

  @override
  void initState() {
    super.initState();
    // 1. Load instant cache
    final cached = GiftsApiService.cachedCatalog;
    if (cached != null && cached.isNotEmpty) {
      _gifts = cached;
    } else {
      _isLoading = true;
    }

    if (GiftsApiService.cachedUserCoins != null) {
      _userCoins = GiftsApiService.cachedUserCoins!;
    }

    _loadCatalogAndBalance();
  }

  Future<void> _loadCatalogAndBalance() async {
    // Load real wallet balance
    try {
      final balanceData = await WalletApiService.getWalletBalance();
      if (mounted && balanceData != null) {
        final coins = balanceData['coins'] ?? balanceData['total_coins'] ?? balanceData['balance'];
        if (coins != null) {
          final int parsedCoins = coins is int ? coins : int.tryParse('$coins') ?? _userCoins;
          setState(() {
            _userCoins = parsedCoins;
          });
        }
      }
    } catch (_) {}

    // Load gifts catalog from API
    final catalog = await GiftsApiService.getGiftsCatalog(
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _gifts = catalog;
        _isLoading = false;
        if (_selectedGiftIndex >= _gifts.length) {
          _selectedGiftIndex = 0;
        }
      });
    }
  }

  void _onCategoryChanged(String cat) async {
    setState(() {
      _selectedCategory = cat;
      _selectedGiftIndex = 0;
    });

    final catalog = await GiftsApiService.getGiftsCatalog(category: cat);
    if (mounted) {
      setState(() {
        _gifts = catalog;
      });
    }
  }

  String _getCategoryLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'all':
        return '✨ ALL';
      case 'popular':
        return '🔥 POPULAR';
      case 'luxury':
        return '🏎️ LUXURY';
      case 'desi':
        return '🛺 DESI';
      case 'birds':
        return '🕊️ BIRDS';
      case 'romantic':
        return '💖 ROMANTIC';
      case 'effects':
        return '🚀 3D EFFECTS';
      case 'vip':
        return '👑 VIP';
      case 'emojis':
        return '😍 EMOJIS';
      case 'stickers':
        return '🎉 STICKERS';
      default:
        return cat.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGift = (_gifts.isNotEmpty && _selectedGiftIndex < _gifts.length)
        ? _gifts[_selectedGiftIndex]
        : null;

    final int totalCost = selectedGift != null ? (selectedGift.coins * _selectedQuantity) : 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B172E), // Deep glassmorphic surface
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Balance & Category Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'Gift Store',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('🎁', style: TextStyle(fontSize: 16)),
                ],
              ),
              // User Balance Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1C44), Color(0xFF1E132D)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_userCoins',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Categories Filter Row
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => _onCategoryChanged(cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF28203E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryLabel(cat),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Gifts Grid (2 rows x 4 items)
          SizedBox(
            height: 220,
            child: _isLoading && _gifts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.76,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _gifts.length,
                    itemBuilder: (context, index) {
                      final gift = _gifts[index];
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
                                ? const Color(0xFFFF2D75).withValues(alpha: 0.18)
                                : const Color(0xFF28203E).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF2D75)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Gift Image or Emoji
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                                  child: gift.imageUrl.isNotEmpty
                                      ? CachedImageLoader(
                                          imageUrl: gift.imageUrl,
                                          fit: BoxFit.contain,
                                        )
                                      : Center(
                                          child: Text(
                                            gift.emoji,
                                            style: const TextStyle(fontSize: 26),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Coin Price Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.diamond_rounded, color: Color(0xFF67E8F9), size: 8.5),
                                    const SizedBox(width: 2),
                                    Text(
                                      gift.displayCoins,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Multipliers & Send Action Row
          Row(
            children: [
              // Quantity Selector Dropdown / Pills
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isQSelected ? const Color(0xFFFF2D75) : const Color(0xFF28203E),
                        borderRadius: BorderRadius.circular(10),
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

              // Send Action Button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D75),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                      elevation: 4,
                    ),
                    onPressed: selectedGift == null
                        ? null
                        : () async {
                            // If receiverId is supplied, send to API in background
                            if (widget.receiverId != null) {
                              GiftsApiService.sendGift(
                                receiverId: widget.receiverId,
                                giftId: selectedGift.giftId > 0 ? selectedGift.giftId : int.tryParse(selectedGift.id) ?? 1,
                                quantity: _selectedQuantity,
                                streamId: widget.streamId,
                              );
                            }

                            widget.onGiftSelected(selectedGift);
                            Navigator.pop(context);
                          },
                    child: Text(
                      selectedGift != null
                          ? 'Send ${selectedGift.name} ($totalCost 💎)'
                          : 'Send Gift',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
        ],
      ),
    );
  }
}
