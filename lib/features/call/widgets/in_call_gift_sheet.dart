import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
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
  final Function(ActiveGiftAnimation gift)? onGiftSent;

  const InCallGiftSheet({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.callSessionId,
    this.onGiftSent,
  });

  static void show(
    BuildContext context, {
    required dynamic receiverId,
    required String receiverName,
    dynamic callSessionId,
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
    _gifts = GiftsApiService.getFallbackGifts();
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
    } else if (_selectedGift == null && _gifts.isNotEmpty) {
      setState(() {
        _selectedGift = _gifts.first;
      });
    }
  }

  Future<void> _sendSelectedGift() async {
    if (_selectedGift == null || _isSending) return;

    final totalRequired = _selectedGift!.coins * _selectedQuantity;
    if (_userCoins < totalRequired) {
      // Prompt recharge
      RechargeGemsSheet.show(context);
      return;
    }

    setState(() => _isSending = true);

    try {
      final res = await GiftsApiService.sendGift(
        receiverId: widget.receiverId,
        giftId: _selectedGift!.giftId,
        quantity: _selectedQuantity,
        context: 'call',
      );

      if (res['status'] == true && mounted) {
        setState(() {
          _userCoins = (_userCoins - totalRequired).clamp(0, 999999999);
        });

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
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Unable to send gift.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending gift: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF140F22).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: User Balance & Recharge Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Balance: $_userCoins',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => RechargeGemsSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 12, color: Colors.white),
                          Text(' Recharge', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Gift Grid
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.82,
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
                      color: isSelected ? AppColors.neonPink.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.neonPink : Colors.white12,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (gift.iconUrl.isNotEmpty)
                          CachedImageLoader(
                            imageUrl: gift.iconUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                          )
                        else
                          Text(gift.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(
                          gift.name,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '${gift.coins}',
                              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9.5, fontWeight: FontWeight.bold),
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

          // Bottom Action: Quantity multiplier & Send Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Multiplier Chips
              Row(
                children: [1, 10, 66, 99].map((qty) {
                  final isSelected = _selectedQuantity == qty;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedQuantity = qty),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.neonPink : Colors.white12,
                        borderRadius: BorderRadius.circular(12),
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

              // Send Button
              GestureDetector(
                onTap: _isSending ? null : _sendSelectedGift,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Gift',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
