import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/models/model_profile.dart';

/// 📸 HostOnCallPhotoCarousel: Automatic Photo Slideshow when Host is in a 1-on-1 Call
/// Automatically cycles through host's avatar, cover photo, and gallery photos every 3 seconds.
/// Overlays a pulsating "I'll back soon..." badge and lets viewers chat and send gifts freely.
class HostOnCallPhotoCarousel extends StatefulWidget {
  final ModelProfile host;
  final List<String> dynamicPhotos;
  final String? customText;

  const HostOnCallPhotoCarousel({
    super.key,
    required this.host,
    this.dynamicPhotos = const [],
    this.customText,
  });

  @override
  State<HostOnCallPhotoCarousel> createState() => _HostOnCallPhotoCarouselState();
}

class _HostOnCallPhotoCarouselState extends State<HostOnCallPhotoCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late List<String> _photoList;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initPhotos();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAutoSlide();
  }

  void _initPhotos() {
    final list = <String>[];
    if (widget.host.avatarUrl.isNotEmpty) {
      list.add(widget.host.avatarUrl);
    }
    if (widget.host.coverPhotoUrl != null && widget.host.coverPhotoUrl!.isNotEmpty) {
      if (!list.contains(widget.host.coverPhotoUrl)) {
        list.add(widget.host.coverPhotoUrl!);
      }
    }
    for (final url in widget.host.galleryUrls) {
      if (url.isNotEmpty && !list.contains(url)) {
        list.add(url);
      }
    }
    for (final url in widget.dynamicPhotos) {
      if (url.isNotEmpty && !list.contains(url)) {
        list.add(url);
      }
    }
    if (list.isEmpty) {
      list.add('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600');
    }
    _photoList = list;
  }

  @override
  void didUpdateWidget(covariant HostOnCallPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dynamicPhotos != widget.dynamicPhotos ||
        oldWidget.host != widget.host) {
      _initPhotos();
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (_photoList.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _photoList.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % _photoList.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = _photoList.isNotEmpty
        ? _photoList[_currentIndex.clamp(0, _photoList.length - 1)]
        : widget.host.avatarUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ambient Blurred Background Layer (Fast Crossfade/Update)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          child: Container(
            key: ValueKey<String>(currentPhoto),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(currentPhoto),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // 2. High-Grade Frosted Glass & Dark Vignette
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.75),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 3. Center Crisp Photo Slideshow Frame with Dynamic Zoom Effect
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: -5,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _photoList.length,
                      onPageChanged: (i) {
                        setState(() => _currentIndex = i);
                      },
                      itemBuilder: (context, index) {
                        return CachedImageLoader(
                          imageUrl: _photoList[index],
                          fit: BoxFit.cover,
                        );
                      },
                    ),

                    // Subtle Bottom Gradient in card
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Color(0xDD000000)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Dot Indicators inside card
                    if (_photoList.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_photoList.length, (idx) {
                            final isActive = idx == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isActive ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4. Pulsing "I'll back soon..." Status Pill Badge
        Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFFFF1744)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.customText ?? "I'll back soon...",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 5. Explanatory Live Card Information Overlay (Bottom-Center above chat)
        Positioned(
          bottom: 120,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1435).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Host is attending a private 1-on-1 call',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Stream resumes automatically when call ends. Chat & Gifts active! 💬🎁',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
