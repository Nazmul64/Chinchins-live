import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image_loader.dart';

class TopGiftAlertBannerData {
  final String id;
  final String senderName;
  final String senderAvatar;
  final String receiverName;
  final String giftIcon;
  final String count;

  const TopGiftAlertBannerData({
    this.id = '',
    required this.senderName,
    required this.senderAvatar,
    required this.receiverName,
    required this.giftIcon,
    required this.count,
  });
}

/// 🎁 TopGiftAlertBanner: Floating Golden Crown Ribbon Gift/Win Banner (matching screenshot)
class TopGiftAlertBanner extends StatelessWidget {
  final String senderName;
  final String senderAvatar;
  final String receiverName;
  final String giftIcon;
  final String count;
  final VoidCallback? onGoPressed;

  const TopGiftAlertBanner({
    super.key,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverName,
    required this.giftIcon,
    required this.count,
    this.onGoPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE5A00D), // Rich Gold
            Color(0xFFC98404),
            Color(0xFF8E5A02), // Deep Amber Gold
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Sender Avatar with Gold Border
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: senderAvatar.isNotEmpty
                  ? CachedImageLoader(
                      imageUrl: senderAvatar,
                      fit: BoxFit.cover,
                    )
                  : const Center(
                      child: Text('👑', style: TextStyle(fontSize: 12)),
                    ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Eyes Emoji & Winning/Gift text
          const Text('👀 ', style: TextStyle(fontSize: 10)),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: senderName.length > 8 ? '${senderName.substring(0, 8)}...' : senderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
                  const TextSpan(
                    text: ' Won ',
                    style: TextStyle(
                      color: Color(0xFFFFF9C4),
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                  TextSpan(
                    text: '$count ',
                    style: const TextStyle(
                      color: Color(0xFFFFEB3B),
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                  const TextSpan(
                    text: '💎 by sending ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Gift Icon
          if (giftIcon.isNotEmpty)
            CachedImageLoader(
              imageUrl: giftIcon,
              width: 20,
              height: 20,
            )
          else
            const Text('🎁', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),

          // 4. "GO >" Capsule Button matching screenshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white70, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GO',
                  style: TextStyle(
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF3E2723), size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// State Manager for the Floating Gift Banner on Live Screen with Auto 4-Second Slide Transition
class TopGiftBannerOverlay extends StatefulWidget {
  const TopGiftBannerOverlay({super.key});

  @override
  State<TopGiftBannerOverlay> createState() => TopGiftBannerOverlayState();
}

class TopGiftBannerOverlayState extends State<TopGiftBannerOverlay>
    with SingleTickerProviderStateMixin {
  TopGiftAlertBannerData? _currentBanner;
  Timer? _dismissTimer;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Show banner when gift socket event is received
  void showGiftBanner(TopGiftAlertBannerData data) {
    _dismissTimer?.cancel();
    setState(() {
      _currentBanner = data;
    });

    _animController.forward(from: 0.0);

    // Auto dismiss after 4 seconds
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentBanner = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentBanner == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 55),
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: TopGiftAlertBanner(
                senderName: _currentBanner!.senderName,
                senderAvatar: _currentBanner!.senderAvatar,
                receiverName: _currentBanner!.receiverName,
                giftIcon: _currentBanner!.giftIcon,
                count: _currentBanner!.count,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
