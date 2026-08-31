import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../screens/gifts_received_screen.dart';

class GiftsReceivedCard extends StatefulWidget {
  final String userId;
  final ModelProfile? model;

  const GiftsReceivedCard({
    super.key,
    required this.userId,
    this.model,
  });

  @override
  State<GiftsReceivedCard> createState() => _GiftsReceivedCardState();
}

class _GiftsReceivedCardState extends State<GiftsReceivedCard> {
  UserGiftsData? _giftsData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 1. Instant Cache retrieval with zero delay
    _giftsData = GiftsApiService.getCachedReceivedGifts(widget.userId);
    if (_giftsData == null) {
      _isLoading = true;
    }
    _loadGifts();
  }

  @override
  void didUpdateWidget(covariant GiftsReceivedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _giftsData = GiftsApiService.getCachedReceivedGifts(widget.userId);
      _loadGifts();
    }
  }

  Future<void> _loadGifts() async {
    final data = await GiftsApiService.getReceivedGifts(widget.userId);
    if (mounted) {
      setState(() {
        _giftsData = data;
        _isLoading = false;
      });
    }
  }

  void _openFullGiftsReceivedScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GiftsReceivedScreen(
          userId: widget.userId,
          userName: widget.model?.name ?? 'Host',
          userAvatar: widget.model?.avatarUrl,
        ),
      ),
    ).then((_) {
      // Reload on pop in case new gifts were sent
      _loadGifts();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get 8 items for the profile preview
    final previewGifts = _giftsData?.profilePreviewGifts ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1831), // Deep purple glassmorphic background matching Screenshot 1
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with "Gifts Received >" & Glowing Heart Icon
          GestureDetector(
            onTap: _openFullGiftsReceivedScreen,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gifts Received',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),

                // Translucent glowing heart badge in top right (Screenshot 1)
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D75).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D75).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF4081),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 8-item Grid (2 rows x 4 columns)
          if (_isLoading && previewGifts.isEmpty)
            _buildLoadingGrid()
          else if (previewGifts.isEmpty)
            _buildEmptyState()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: previewGifts.length > 8 ? 8 : previewGifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final gift = previewGifts[index];
                return GestureDetector(
                  onTap: _openFullGiftsReceivedScreen,
                  child: _buildGiftSlot(gift),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGiftSlot(GiftItem gift) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF28203E).withValues(alpha: 0.8), // Dark purple glass slot
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gift Image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4, bottom: 2),
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

          // Diamond Coin Badge (e.g. 💎 17.70K, 💎 17K, 💎 9.99K)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], // Purple to Indigo
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  size: 8.5,
                  color: Color(0xFF67E8F9), // Cyan diamond icon
                ),
                const SizedBox(width: 2),
                Text(
                  gift.displayCoins,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Multiplier Count (e.g. x2, x1, x4, x32, x12)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              gift.displayCount,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF28203E).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: _openFullGiftsReceivedScreen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              size: 32,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 6),
            Text(
              'No gifts received yet. Tap to view gift gallery!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
