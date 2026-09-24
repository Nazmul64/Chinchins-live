import 'dart:async';
import 'package:flutter/material.dart';

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

/// 🎁 TopGiftAlertBanner: Floating Cyan-Green Gradient Gift Alert Banner (TikTok/Bigo style)
class TopGiftAlertBanner extends StatelessWidget {
  final String senderName;
  final String senderAvatar;
  final String receiverName;
  final String giftIcon;
  final String count;

  const TopGiftAlertBanner({
    super.key,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverName,
    required this.giftIcon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)], // Cyan-to-Green Gradient
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender Avatar
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white24,
            backgroundImage: senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
            child: senderAvatar.isEmpty
                ? const Icon(Icons.person, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 6),

          // Sender Name
          Flexible(
            child: Text(
              senderName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // "send to"
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "send to",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Receiver Name
          Flexible(
            child: Text(
              receiverName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),

          // Gift Icon
          if (giftIcon.isNotEmpty)
            Image.network(
              giftIcon,
              width: 22,
              height: 22,
              errorBuilder: (context, error, stackTrace) => const Text('🎁', style: TextStyle(fontSize: 14)),
            )
          else
            const Text('🎁', style: TextStyle(fontSize: 14)),

          // Multiplier Count
          Text(
            " x$count",
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
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
