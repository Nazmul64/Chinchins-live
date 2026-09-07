import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/screens/monthly_card_screen.dart';
import '../../wallet/services/vip_cards_api_service.dart';

class DraggableExtraGemsWidget extends StatefulWidget {
  final Offset initialPosition;

  const DraggableExtraGemsWidget({
    super.key,
    this.initialPosition = const Offset(12, 430),
  });

  @override
  State<DraggableExtraGemsWidget> createState() => _DraggableExtraGemsWidgetState();
}

class _DraggableExtraGemsWidgetState extends State<DraggableExtraGemsWidget>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  late AnimationController _shimmerController;
  late Animation<double> _glowAnimation;
  bool _isDismissed = false;
  bool _isEnabled = true;
  String _imageUrl = 'https://chinchins.live/assets/images/vip/floating_extra_gems.png';

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _loadBannerConfig();
  }

  Future<void> _loadBannerConfig() async {
    try {
      final bannerData = await VipCardsApiService.getFloatingBanner();
      if (!mounted) return;

      final enabled = bannerData['is_enabled'] != false;
      final rawImg = bannerData['image_url'] ?? bannerData['image'] ?? bannerData['custom_image'];

      setState(() {
        _isEnabled = enabled;
        if (rawImg != null && rawImg.toString().trim().isNotEmpty) {
          _imageUrl = CachedImageLoader.normalize(rawImg.toString().trim());
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MonthlyCardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || !_isEnabled) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    const widgetWidth = 92.0;
    const widgetHeight = 92.0;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newX = (_position.dx + details.delta.dx).clamp(
              4.0,
              screenSize.width - widgetWidth - 4.0,
            );
            final newY = (_position.dy + details.delta.dy).clamp(
              50.0,
              screenSize.height - widgetHeight - 80.0,
            );
            _position = Offset(newX, newY);
          });
        },
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _glowAnimation.value,
              child: SizedBox(
                width: widgetWidth,
                height: widgetHeight,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Golden Glow Aura
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.50),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Real Dynamic Image from Backend / Database (Admin Panel uploaded)
                    CachedImageLoader(
                      imageUrl: _imageUrl,
                      width: 86,
                      height: 86,
                      fit: BoxFit.contain,
                    ),



                    // Dismiss (X) Close button on top-left
                    Positioned(
                      top: 0,
                      left: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isDismissed = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
