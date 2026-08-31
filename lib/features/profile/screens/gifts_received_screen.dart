import 'package:flutter/material.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../../core/widgets/cached_image_loader.dart';

class GiftsReceivedScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const GiftsReceivedScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<GiftsReceivedScreen> createState() => _GiftsReceivedScreenState();
}

class _GiftsReceivedScreenState extends State<GiftsReceivedScreen> {
  UserGiftsData? _giftsData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 1. Instant cache load
    _giftsData = GiftsApiService.getCachedReceivedGifts(widget.userId);
    if (_giftsData == null) {
      _isLoading = true;
    }
    _loadGifts();
  }

  Future<void> _loadGifts({bool forceRefresh = false}) async {
    final data = await GiftsApiService.getReceivedGifts(
      widget.userId,
      forceRefresh: forceRefresh,
    );

    if (mounted) {
      setState(() {
        _giftsData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts = _giftsData?.giftsReceived ?? _giftsData?.profilePreviewGifts ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2), // Warm ivory / cream background matching Screenshot 2
      body: Stack(
        children: [
          // 1. Top Warm Glowing Amber Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFA000), // Rich amber gold
                    Color(0xFFFFB300), // Glowing yellow gold
                    Color(0xFFFFD54F), // Light golden top
                    Color(0xFFFFF8E1), // Cream fade
                    Color(0xFFF9F7F2), // Base background
                  ],
                  stops: [0.0, 0.4, 0.7, 0.9, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Main Scrollable Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Gifts Received',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance back button
                    ],
                  ),
                ),

                // 3D Glowing Gift Box Artwork with Floating Hearts
                SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft radial glow aura
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      // Gift Box Icon & Hearts Stack
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, color: Color(0xFFFF3366), size: 14),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.favorite, color: Color(0xFFFF1744), size: 18),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_giftsData != null && _giftsData!.summary.totalItemsCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_giftsData!.summary.totalItemsCount} Total Received • ${_giftsData!.summary.formattedCoins} 💎',
                                style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 4-Column Grid of All Received Gifts
                Expanded(
                  child: _isLoading && gifts.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadGifts(forceRefresh: true),
                          color: Colors.amber,
                          child: gifts.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 80),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.card_giftcard, size: 60, color: Color(0xFFCCC5B9)),
                                          SizedBox(height: 12),
                                          Text(
                                            'No gifts received yet',
                                            style: TextStyle(
                                              color: Color(0xFF8D8D8D),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Send the first gift to light up this profile!',
                                            style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  itemCount: gifts.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.76,
                                  ),
                                  itemBuilder: (context, index) {
                                    final gift = gifts[index];
                                    return _buildReceivedGiftTile(gift);
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedGiftTile(GiftItem gift) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7280).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5E7EB).withValues(alpha: 0.8),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gift Image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 6, right: 6, bottom: 4),
              child: gift.imageUrl.isNotEmpty
                  ? CachedImageLoader(
                      imageUrl: gift.imageUrl,
                      fit: BoxFit.contain,
                    )
                  : Center(
                      child: Text(
                        gift.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
            ),
          ),

          // Diamond Coin Badge (e.g. 💎 17.70K, 💎 10K, 💎 9.99K)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], // Sleek Purple-Indigo
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, size: 9, color: Color(0xFF67E8F9)), // Cyan Diamond
                const SizedBox(width: 2),
                Text(
                  gift.displayCoins,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // Multiplier Count (e.g. x1, x10, x2, x6, x3, x18, x43)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              gift.displayCount,
              style: const TextStyle(
                color: Color(0xFF4B5563), // Slate gray text matching screenshot
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
