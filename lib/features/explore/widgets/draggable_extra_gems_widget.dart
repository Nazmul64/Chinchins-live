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
  String _imageUrl = '';
  String _title = 'Extra Gems';
  String _subtitle = 'Monthly Card';
  String _targetAction = 'OPEN_PREMIUM_VIP';

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    // Instant synchronous cache load (0.00ms!)
    final cached = VipCardsApiService.getCachedFloatingBanner();
    if (cached != null) {
      _isEnabled = cached['is_enabled'] != false;
      _title = cached['title']?.toString() ?? _title;
      _subtitle = cached['subtitle']?.toString() ?? _subtitle;
      _targetAction = cached['target_action']?.toString() ?? _targetAction;
      final cachedImg = cached['image_url']?.toString();
      if (cachedImg != null && cachedImg.trim().isNotEmpty) {
        _imageUrl = CachedImageLoader.normalize(cachedImg.trim());
      }
    }

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
      final title = bannerData['title']?.toString() ?? _title;
      final subtitle = bannerData['subtitle']?.toString() ?? _subtitle;
      final targetAction = bannerData['target_action']?.toString() ?? _targetAction;

      setState(() {
        _isEnabled = enabled;
        _title = title;
        _subtitle = subtitle;
        _targetAction = targetAction;
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
    if (_targetAction == 'OPEN_PREMIUM_VIP' || _targetAction == 'OPEN_MONTHLY_CARD' || _targetAction.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MonthlyCardScreen(),
        ),
      );
    }
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

                    // Real Dynamic Image from Admin Panel API (GET /api/floating-banner)
                    if (_imageUrl.isNotEmpty)
                      CachedImageLoader(
                        imageUrl: _imageUrl,
                        width: 86,
                        height: 86,
                        fit: BoxFit.contain,
                      )
                    else
                      // Sleek Fallback VIP Card Badge
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFE65100)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFF9C4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                            const SizedBox(height: 2),
                            Text(
                              _title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _subtitle,
                              style: const TextStyle(
                                color: Color(0xFFFFF9C4),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
