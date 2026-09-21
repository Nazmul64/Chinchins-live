import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/services/app_cache_service.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import 'gift_animation_overlay.dart';

class InCallGiftSheet extends StatefulWidget {
  final dynamic receiverId;
  final String receiverName;
  final dynamic callSessionId;
  final dynamic streamId;
  final String contextType; // 'call' or 'live'
  final Function(ActiveGiftAnimation gift)? onGiftSent;

  const InCallGiftSheet({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.callSessionId,
    this.streamId,
    this.contextType = 'call',
    this.onGiftSent,
  });

  static void show(
    BuildContext context, {
    required dynamic receiverId,
    required String receiverName,
    dynamic callSessionId,
    dynamic streamId,
    String contextType = 'call',
    Function(ActiveGiftAnimation gift)? onGiftSent,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => InCallGiftSheet(
        receiverId: receiverId,
        receiverName: receiverName,
        callSessionId: callSessionId,
        streamId: streamId,
        contextType: contextType,
        onGiftSent: onGiftSent,
      ),
    );
  }

  @override
  State<InCallGiftSheet> createState() => _InCallGiftSheetState();
}

class _InCallGiftSheetState extends State<InCallGiftSheet> {
  List<GiftItem> _gifts = [];
  int _userCoins = 0;
  GiftItem? _selectedGift;
  int _selectedQuantity = 1;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _userCoins = WalletApiService.getCachedCoins();

    // ⚡ Zero-Loading: Instant catalog from in-memory RAM cache
    if (AppCacheService.cachedGifts.isNotEmpty) {
      _gifts = List.from(AppCacheService.cachedGifts);
      _selectedGift = _gifts.first;
    } else {
      _gifts = GiftsApiService.getFallbackGifts();
      if (_gifts.isNotEmpty) {
        _selectedGift = _gifts.first;
      }
    }

    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final catalog = await GiftsApiService.getGiftsCatalog();
    if (catalog.isNotEmpty && mounted) {
      setState(() {
        _gifts = catalog;
        if (_selectedGift == null && _gifts.isNotEmpty) {
          _selectedGift = _gifts.first;
        }
      });
    }
  }

  Future<void> _sendSelectedGift() async {
    if (_selectedGift == null) return;

    final totalRequired = _selectedGift!.coins * _selectedQuantity;
    if (_userCoins < totalRequired) {
      RechargeGemsSheet.show(context);
      return;
    }

    final previousCoins = _userCoins;

    // ⚡ 1. Optimistic UI: Deduct coins instantly & trigger animation immediately
    setState(() {
      _userCoins = (_userCoins - totalRequired).clamp(0, 999999999);
    });
    WalletApiService.updateCachedCoins(_userCoins);

    final anim = ActiveGiftAnimation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      giftName: _selectedGift!.name,
      giftEmoji: _selectedGift!.emoji,
      giftIconUrl: _selectedGift!.iconUrl,
      senderName: 'You',
      coins: totalRequired,
      combo: _selectedQuantity,
    );

    widget.onGiftSent?.call(anim);
    Navigator.pop(context); // 0-latency instant modal dismissal

    // ⚡ 2. Asynchronously dispatch gift API call in background worker
    GiftsApiService.sendGift(
      receiverId: widget.receiverId,
      giftId: _selectedGift!.giftId,
      quantity: _selectedQuantity,
      context: widget.contextType,
      streamId: widget.streamId?.toString() ?? (widget.contextType == 'live' ? widget.callSessionId?.toString() : null),
      callSessionId: widget.callSessionId,
    ).then((res) {
      if (res['status'] == false && (res['code'] == 422 || res['code'] == 'INSUFFICIENT_BALANCE' || (res['message']?.toString().toLowerCase().contains('recharge') ?? false))) {
        // Revert coins if server rejects
        WalletApiService.updateCachedCoins(previousCoins);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 440,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E17).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.3), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Top Header: Send Gift Title & Coins Balance Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32), // Placeholder for balance
              const Text(
                'Send Gift',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              // Gold Coin Balance Pill
              GestureDetector(
                onTap: () => RechargeGemsSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4), width: 0.8),
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
                      const SizedBox(width: 3),
                      const Icon(Icons.add_circle_rounded, color: Color(0xFFFF1744), size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3x3 Luxury Gift Grid (Rose, Love, Fire, Panda, Diamond, Castle, Rocket, Car, Yacht)
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.15,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = _selectedGift?.id == gift.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedGift = gift);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF281120) : const Color(0xFF1A1726),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF1744) : Colors.white.withValues(alpha: 0.06),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF1744).withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (gift.iconUrl.isNotEmpty)
                          CachedImageLoader(
                            imageUrl: gift.iconUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          )
                        else
                          Text(gift.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(
                          gift.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
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
                            const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '${gift.coins}',
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action: Multiplier Chips & Wide Crimson/Red Send Button
          Row(
            children: [
              // Quantity chips (x1, x10, x99)
              Row(
                children: [1, 10, 99].map((qty) {
                  final isSelected = _selectedQuantity == qty;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedQuantity = qty),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF1744) : const Color(0xFF1E1B2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF1744) : Colors.white12,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'x$qty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 8),

              // Big Red Send Button
              Expanded(
                child: GestureDetector(
                  onTap: _isSending ? null : _sendSelectedGift,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFFF007F)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Send${_selectedGift != null ? " (${_selectedGift!.coins * _selectedQuantity} 💎)" : ""}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
