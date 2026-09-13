import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ActiveGiftAnimation {
  final String id;
  final String giftName;
  final String giftEmoji;
  final String? giftIconUrl;
  final String senderName;
  final int coins;
  final int combo;

  ActiveGiftAnimation({
    required this.id,
    required this.giftName,
    required this.giftEmoji,
    this.giftIconUrl,
    required this.senderName,
    required this.coins,
    this.combo = 1,
  });
}

class GiftAnimationOverlay extends StatefulWidget {
  final Widget? child;

  const GiftAnimationOverlay({super.key, this.child});

  static GiftAnimationOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<GiftAnimationOverlayState>();
  }

  @override
  State<GiftAnimationOverlay> createState() => GiftAnimationOverlayState();
}

class GiftAnimationOverlayState extends State<GiftAnimationOverlay> with TickerProviderStateMixin {
  final List<ActiveGiftAnimation> _activeGifts = [];
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  ActiveGiftAnimation? _currentGift;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_animController);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_activeGifts.isNotEmpty) {
          _activeGifts.removeAt(0);
        }
        if (_activeGifts.isNotEmpty) {
          _playNextGift();
        } else {
          setState(() => _currentGift = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void playGiftAnimation(ActiveGiftAnimation gift) {
    _activeGifts.add(gift);
    if (!_animController.isAnimating) {
      _playNextGift();
    }
  }

  void _playNextGift() {
    if (_activeGifts.isEmpty) return;
    setState(() {
      _currentGift = _activeGifts.first;
    });
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.child != null) widget.child!,
        if (_currentGift != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _opacityAnimation,
                    child: Center(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildGiftBanner(_currentGift!),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGiftBanner(ActiveGiftAnimation gift) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Luxury Particle Glow Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0), Color(0xFFFF007F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gift Icon or Emoji
              if (gift.giftIconUrl != null && gift.giftIconUrl!.isNotEmpty)
                CachedImageLoader(
                  imageUrl: gift.giftIconUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                )
              else
                Text(
                  gift.giftEmoji,
                  style: const TextStyle(fontSize: 52),
                ),
              const SizedBox(width: 14),

              // Sender and Gift Info
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${gift.senderName} sent',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gift.giftName,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${gift.coins} Coins',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (gift.combo > 1) ...[
                const SizedBox(width: 14),
                // Combo Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'x${gift.combo}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
