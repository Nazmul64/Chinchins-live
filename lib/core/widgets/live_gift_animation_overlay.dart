import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/live_gift_event.dart';
import '../theme/app_colors.dart';
import 'cached_image_loader.dart';

class LiveGiftAnimationOverlay extends StatefulWidget {
  final Stream<LiveGiftEvent>? giftStream;
  final LiveGiftEvent? currentGift;
  final VoidCallback? onAnimationComplete;

  const LiveGiftAnimationOverlay({
    super.key,
    this.giftStream,
    this.currentGift,
    this.onAnimationComplete,
  });

  @override
  State<LiveGiftAnimationOverlay> createState() => _LiveGiftAnimationOverlayState();
}

class _LiveGiftAnimationOverlayState extends State<LiveGiftAnimationOverlay>
    with TickerProviderStateMixin {
  final List<LiveGiftEvent> _queue = [];
  LiveGiftEvent? _activeGift;
  bool _isPlaying = false;
  StreamSubscription<LiveGiftEvent>? _streamSub;

  // Controllers for flight, particles, scale, banner
  late AnimationController _flightController;
  late AnimationController _bannerController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  late Animation<Offset> _bannerSlideAnimation;
  late Animation<double> _bannerScaleAnimation;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutBack,
    ));

    _bannerScaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack),
    );

    _flightController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishCurrentAnimation();
      }
    });

    if (widget.giftStream != null) {
      _streamSub = widget.giftStream!.listen((gift) {
        playGift(gift);
      });
    }

    if (widget.currentGift != null) {
      playGift(widget.currentGift!);
    }
  }

  @override
  void didUpdateWidget(covariant LiveGiftAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentGift != null && widget.currentGift != oldWidget.currentGift) {
      playGift(widget.currentGift!);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _flightController.dispose();
    _bannerController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// Add gift to queue and trigger animation
  void playGift(LiveGiftEvent gift) {
    if (!mounted) return;
    setState(() {
      _queue.add(gift);
    });
    if (!_isPlaying) {
      _processNextInQueue();
    }
  }

  void _processNextInQueue() {
    if (_queue.isEmpty || !mounted) {
      setState(() {
        _isPlaying = false;
        _activeGift = null;
      });
      widget.onAnimationComplete?.call();
      return;
    }

    final gift = _queue.removeAt(0);
    _generateParticles(gift);

    setState(() {
      _activeGift = gift;
      _isPlaying = true;
    });

    _bannerController.forward(from: 0.0);
    _flightController.forward(from: 0.0);
  }

  void _finishCurrentAnimation() {
    if (!mounted) return;
    _bannerController.reverse().then((_) {
      if (mounted) {
        _processNextInQueue();
      }
    });
  }

  void _generateParticles(LiveGiftEvent gift) {
    _particles.clear();
    final name = gift.giftName.toLowerCase();
    Color primaryColor = const Color(0xFFFFD700);

    if (name.contains('jet') || name.contains('plane')) {
      primaryColor = const Color(0xFF00E5FF);
    } else if (name.contains('car') || name.contains('supercar')) {
      primaryColor = const Color(0xFFFF3366);
    } else if (name.contains('rose') || name.contains('flower') || name.contains('love')) {
      primaryColor = const Color(0xFFFF1493);
    } else if (name.contains('dragon') || name.contains('fire')) {
      primaryColor = const Color(0xFFFF4500);
    } else if (name.contains('crown') || name.contains('palace') || name.contains('diamond')) {
      primaryColor = const Color(0xFFFFD700);
    }

    for (int i = 0; i < 45; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 12 + 4,
        speedX: (_random.nextDouble() - 0.5) * 0.015,
        speedY: _random.nextDouble() * 0.02 + 0.005,
        color: i % 2 == 0
            ? primaryColor
            : (i % 3 == 0 ? Colors.white : const Color(0xFFFFB300)),
        opacity: _random.nextDouble() * 0.8 + 0.2,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _activeGift == null) {
      return const SizedBox.shrink();
    }

    final gift = _activeGift!;
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Particle Canvas Overlay (Sparkles, Star Dust, Petals)
          AnimatedBuilder(
            animation: _flightController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _flightController.value,
                  giftType: gift.giftName,
                ),
              );
            },
          ),

          // 2. Main Fullscreen Animation Object / Vehicle / Palace FX
          _buildSpecialEffect(gift, size),

          // 3. Floating VIP Sender Banner Popup at Top
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _bannerSlideAnimation,
              child: ScaleTransition(
                scale: _bannerScaleAnimation,
                child: _buildSenderBanner(gift),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Top VIP Sender Banner with Glowing Border & Multiplier Combo
  Widget _buildSenderBanner(LiveGiftEvent gift) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xE62A0845),
              Color(0xE66441A5),
              Color(0xCCFF007F),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF007F).withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              ),
              child: ClipOval(
                child: gift.senderAvatar.isNotEmpty
                    ? CachedImageLoader(
                        imageUrl: gift.senderAvatar,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),

            // Sender Info & Gift Description
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          gift.senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'sent ${gift.giftName}',
                        style: const TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (gift.coinsSpent > 0) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.diamond_rounded, color: Color(0xFF67E8F9), size: 11),
                        Text(
                          '${gift.coinsSpent}',
                          style: const TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Gift Icon / Thumbnail
            if (gift.iconUrl.isNotEmpty)
              SizedBox(
                width: 36,
                height: 36,
                child: CachedImageLoader(
                  imageUrl: gift.iconUrl,
                  fit: BoxFit.contain,
                ),
              ),

            // Combo Count Tag
            if (gift.comboCount > 1) ...[
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D55), Color(0xFFFF9500)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2D55).withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'x${gift.comboCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Specialized Fullscreen Visual Effect tailored for gifts (Jet, Car, Castle, Dragon, Crown)
  Widget _buildSpecialEffect(LiveGiftEvent gift, Size screenSize) {
    final name = gift.giftName.toLowerCase();

    // 1. Private Jet Flying Across Screen
    if (name.contains('jet') || name.contains('plane') || name.contains('flight')) {
      return _buildPrivateJetEffect(gift, screenSize);
    }

    // 2. Supercar Speeding Across Screen
    if (name.contains('car') || name.contains('supercar') || name.contains('ferrari') || name.contains('lambo')) {
      return _buildSupercarEffect(gift, screenSize);
    }

    // 3. Romantic Castle / Palace
    if (name.contains('castle') || name.contains('palace') || name.contains('royal')) {
      return _buildCastleEffect(gift, screenSize);
    }

    // 4. Fire Dragon / Phoenix
    if (name.contains('dragon') || name.contains('fire') || name.contains('phoenix')) {
      return _buildDragonEffect(gift, screenSize);
    }

    // 5. Crown / Diamond / Trophy
    if (name.contains('crown') || name.contains('diamond') || name.contains('trophy')) {
      return _buildCrownEffect(gift, screenSize);
    }

    // Default Fullscreen Showcase with 3D Float, Scale, Glow & Light Burst
    return _buildDefaultGiftEffect(gift, screenSize);
  }

  /// Private Jet Flight Animation with Smoke & Afterburners
  Widget _buildPrivateJetEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;

        // Curved flight trajectory from bottom-left to top-right
        final startX = -size.width * 0.5;
        final endX = size.width * 1.2;
        final currentX = startX + (endX - startX) * t;

        final startY = size.height * 0.75;
        final endY = size.height * 0.15;
        final currentY = startY + (endY - startY) * math.sin(t * math.pi * 0.85);

        final scale = 0.6 + math.sin(t * math.pi) * 0.6;
        const angle = -0.32; // tilted upward

        return Stack(
          children: [
            Positioned(
              left: currentX,
              top: currentY,
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Jet Visual
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: gift.fileUrl.isNotEmpty
                            ? CachedImageLoader(
                                imageUrl: gift.fileUrl,
                                fit: BoxFit.contain,
                              )
                            : (gift.iconUrl.isNotEmpty
                                ? CachedImageLoader(
                                    imageUrl: gift.iconUrl,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(
                                    child: Text('✈️', style: TextStyle(fontSize: 140)),
                                  )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Supercar Burnout & Zoom Effect
  Widget _buildSupercarEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;
        // Ease in out acceleration across bottom third of screen
        final progress = Curves.easeInOutCubic.transform(t);
        final startX = -size.width * 0.8;
        final endX = size.width * 1.3;
        final currentX = startX + (endX - startX) * progress;
        final currentY = size.height * 0.55 + (math.sin(t * math.pi * 4) * 4); // vibration
        final scale = 0.85 + (math.sin(t * math.pi) * 0.35);

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                    blurRadius: 50,
                    spreadRadius: 12,
                  ),
                ],
              ),
              child: gift.fileUrl.isNotEmpty
                  ? CachedImageLoader(imageUrl: gift.fileUrl, fit: BoxFit.contain)
                  : (gift.iconUrl.isNotEmpty
                      ? CachedImageLoader(imageUrl: gift.iconUrl, fit: BoxFit.contain)
                      : const Center(child: Text('🏎️', style: TextStyle(fontSize: 130)))),
            ),
          ),
        );
      },
    );
  }

  /// Royal Palace / Castle Grand Display
  Widget _buildCastleEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;
        final scale = math.sin(t * math.pi) * 1.15;
        final opacity = (math.sin(t * math.pi) * 1.2).clamp(0.0, 1.0);

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF80AB).withValues(alpha: 0.6),
                      blurRadius: 60,
                      spreadRadius: 15,
                    ),
                  ],
                ),
                child: gift.fileUrl.isNotEmpty
                    ? CachedImageLoader(imageUrl: gift.fileUrl, fit: BoxFit.contain)
                    : (gift.iconUrl.isNotEmpty
                        ? CachedImageLoader(imageUrl: gift.iconUrl, fit: BoxFit.contain)
                        : const Center(child: Text('🏰', style: TextStyle(fontSize: 150)))),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Fire Dragon / Phoenix Effect
  Widget _buildDragonEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;
        final scale = 0.5 + math.sin(t * math.pi) * 0.7;
        final currentY = (size.height * 0.4) - (math.sin(t * math.pi * 2) * 30);

        return Center(
          child: Transform.translate(
            offset: Offset(0, currentY - (size.height * 0.4)),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.7),
                      blurRadius: 70,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: gift.fileUrl.isNotEmpty
                    ? CachedImageLoader(imageUrl: gift.fileUrl, fit: BoxFit.contain)
                    : (gift.iconUrl.isNotEmpty
                        ? CachedImageLoader(imageUrl: gift.iconUrl, fit: BoxFit.contain)
                        : const Center(child: Text('🐉', style: TextStyle(fontSize: 150)))),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shimmering Diamond Crown Effect
  Widget _buildCrownEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;
        final scale = math.sin(t * math.pi) * 1.2;
        final rotate = math.sin(t * math.pi * 2) * 0.08;

        return Center(
          child: Transform.rotate(
            angle: rotate,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                      blurRadius: 60,
                      spreadRadius: 15,
                    ),
                  ],
                ),
                child: gift.fileUrl.isNotEmpty
                    ? CachedImageLoader(imageUrl: gift.fileUrl, fit: BoxFit.contain)
                    : (gift.iconUrl.isNotEmpty
                        ? CachedImageLoader(imageUrl: gift.iconUrl, fit: BoxFit.contain)
                        : const Center(child: Text('👑', style: TextStyle(fontSize: 140)))),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Default High-End Gift Effect
  Widget _buildDefaultGiftEffect(LiveGiftEvent gift, Size size) {
    return AnimatedBuilder(
      animation: _flightController,
      builder: (context, child) {
        final t = _flightController.value;
        final scale = (math.sin(t * math.pi) * 1.15).clamp(0.0, 1.3);
        final opacity = (math.sin(t * math.pi) * 1.3).clamp(0.0, 1.0);

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPink.withValues(alpha: 0.6),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: gift.fileUrl.isNotEmpty
                    ? CachedImageLoader(imageUrl: gift.fileUrl, fit: BoxFit.contain)
                    : (gift.iconUrl.isNotEmpty
                        ? CachedImageLoader(imageUrl: gift.iconUrl, fit: BoxFit.contain)
                        : const Center(child: Text('🎁', style: TextStyle(fontSize: 120)))),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper Particle Class
class _Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  Color color;
  double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.color,
    required this.opacity,
  });
}

/// Custom Particle Painter for sparkles, fireworks, and falling rose petals
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final String giftType;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.giftType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final isRose = giftType.toLowerCase().contains('rose') || giftType.toLowerCase().contains('flower');

    for (final p in particles) {
      final curX = (p.x + (p.speedX * progress * 50)) % 1.0 * size.width;
      final curY = (p.y + (p.speedY * progress * 50)) % 1.0 * size.height;
      final currentOpacity = (p.opacity * math.sin(progress * math.pi)).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: currentOpacity);

      if (isRose) {
        // Draw petal oval
        canvas.save();
        canvas.translate(curX, curY);
        canvas.rotate(progress * math.pi * 2 + p.size);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.9),
          paint,
        );
        canvas.restore();
      } else {
        // Draw glowing star sparkle
        canvas.drawCircle(Offset(curX, curY), p.size * (0.5 + 0.5 * math.sin(progress * math.pi)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
