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

  // Showcase fallback items matching Screenshot 1 & 2
  static final List<GiftItem> _showcaseGifts = [
    GiftItem(
      id: 'showcase_1',
      name: 'Golden Dragon',
      coins: 18880,
      imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=200&auto=format&fit=crop&q=80',
      emoji: '🐉',
      category: 'Luxury',
      receivedCount: 2,
    ),
    GiftItem(
      id: 'showcase_2',
      name: 'Super Car',
      coins: 9990,
      imageUrl: 'https://images.unsplash.com/photo-1544829099-b9a0c07fad1a?w=200&auto=format&fit=crop&q=80',
      emoji: '🏎️',
      category: 'Luxury',
      receivedCount: 50,
    ),
    GiftItem(
      id: 'showcase_3',
      name: 'Jet Plane',
      coins: 6660,
      imageUrl: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=200&auto=format&fit=crop&q=80',
      emoji: '✈️',
      category: 'Luxury',
      receivedCount: 13,
    ),
    GiftItem(
      id: 'showcase_4',
      name: 'Fire Phoenix',
      coins: 5550,
      imageUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=200&auto=format&fit=crop&q=80',
      emoji: '🦅',
      category: 'Luxury',
      receivedCount: 20,
    ),
    GiftItem(
      id: 'showcase_5',
      name: 'Treasure Chest',
      coins: 5000,
      imageUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=200&auto=format&fit=crop&q=80',
      emoji: '📦',
      category: 'Special',
      receivedCount: 3,
    ),
    GiftItem(
      id: 'showcase_6',
      name: 'Magic Lamp',
      coins: 4440,
      imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&auto=format&fit=crop&q=80',
      emoji: '🪔',
      category: 'Special',
      receivedCount: 12,
    ),
    GiftItem(
      id: 'showcase_7',
      name: 'Royal Prince',
      coins: 3700,
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      emoji: '🤴',
      category: 'Popular',
      receivedCount: 1,
    ),
    GiftItem(
      id: 'showcase_8',
      name: 'Romantic Couple',
      coins: 3700,
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
      emoji: '💑',
      category: 'Popular',
      receivedCount: 7,
    ),
  ];

  @override
  void initState() {
    super.initState();
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
      _loadGifts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final actualGifts = _giftsData?.profilePreviewGifts ?? [];
    final displayGifts = actualGifts.isNotEmpty ? actualGifts : _showcaseGifts;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22173F), // Deep rich purple
            Color(0xFF16112C), // Dark midnight purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF9333EA).withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with "Gifts Received >" & Glowing Heart in Top-Right
          GestureDetector(
            onTap: _openFullGiftsReceivedScreen,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Gifts Received',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),

                // Glowing Shiny Heart matching Screenshot 1 & 2
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFF80AB),
                        Color(0xFFFF4081),
                        Color(0xFFC2185B),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 8-item Grid (2 rows x 4 columns) matching Screenshot 1 & 2
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayGifts.length > 8 ? 8 : displayGifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final gift = displayGifts[index];
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
        color: const Color(0xFF282046).withValues(alpha: 0.75), // Dark purple glass slot
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF67E8F9).withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gift Image / Art
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 6, right: 6, bottom: 2),
              child: gift.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedImageLoader(
                        imageUrl: gift.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        gift.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
            ),
          ),

          // Diamond Coin Badge (e.g. 💎 18.88K, 💎 9.99K) matching Screenshot 1
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF6366F1)], // Cyan to Indigo
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
                  color: Color(0xFFE0F2FE),
                ),
                const SizedBox(width: 2),
                Text(
                  gift.displayCoins,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Multiplier Count (e.g. ×2, ×50, ×13) matching Screenshot 1
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '×${gift.receivedCount > 0 ? gift.receivedCount : 1}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

