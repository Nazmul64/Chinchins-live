import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../services/beauty_filter_engine.dart';
import '../services/call_api_service.dart';
import '../services/pip_call_overlay.dart';
import '../widgets/camera_filter_tray.dart';
import '../widgets/in_call_profile_sheet.dart';
import '../widgets/in_call_gift_sheet.dart';
import '../widgets/gift_animation_overlay.dart';

class LiveHeart {
  final Key key;
  final double left;
  final Color color;

  LiveHeart({required this.key, required this.left, required this.color});
}

class LiveRoomScreen extends StatefulWidget {
  final ModelProfile host;
  final dynamic liveId;
  final String? title;
  final bool isHost;

  const LiveRoomScreen({
    super.key,
    required this.host,
    this.liveId,
    this.title,
    this.isHost = false,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin {
  final GlobalKey<GiftAnimationOverlayState> _giftAnimKey = GlobalKey<GiftAnimationOverlayState>();
  final List<Map<String, dynamic>> _liveComments = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LiveHeart> _hearts = [];
  final Random _rnd = Random();

  FilterPreset _currentFilter = BeautyFilterEngine.presets[1]; // Beauty Glow by default
  bool _isFollowing = false;
  int _viewerCount = 124;
  int _likeCount = 1580;
  bool _isGuestConnected = false;
  bool _isGuestConnecting = false;
  bool _isMicMuted = false;
  bool _isVideoOff = false;

  @override
  void initState() {
    super.initState();
    _viewerCount = 100 + _rnd.nextInt(250);
    _liveComments.addAll([
      {'user': 'Sara', 'text': 'Hello gorgeous! ❤️', 'color': Colors.pinkAccent},
      {'user': 'Alex', 'text': 'Welcome to live stream! 🔥', 'color': Colors.amberAccent},
      {'user': 'Rohan', 'text': 'You look stunning! ✨', 'color': Colors.cyanAccent},
    ]);
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final status = await CallApiService.getFollowStatus(widget.host.id);
      if (mounted) {
        setState(() {
          _isFollowing = status['is_following'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final prev = _isFollowing;
    setState(() => _isFollowing = !prev);
    try {
      if (!prev) {
        await CallApiService.followUser(widget.host.id, source: 'live');
      } else {
        await CallApiService.unfollowUser(widget.host.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = prev);
    }
  }

  void _addHeart() {
    final heart = LiveHeart(
      key: UniqueKey(),
      left: 20.0 + _rnd.nextDouble() * 60.0,
      color: [
        Colors.pinkAccent,
        Colors.redAccent,
        Colors.purpleAccent,
        Colors.amber,
        Colors.cyanAccent,
      ][_rnd.nextInt(5)],
    );

    setState(() {
      _likeCount++;
      _hearts.add(heart);
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.key == heart.key);
        });
      }
    });
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();

    setState(() {
      _liveComments.add({
        'user': 'You',
        'text': text,
        'color': AppColors.neonPink,
        'isMe': true,
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    if (widget.liveId != null) {
      CallApiService.sendLiveMessage(widget.liveId, text);
    }
  }

  void _toggleMultiGuestConnect() async {
    if (_isGuestConnected) {
      setState(() => _isGuestConnected = false);
    } else {
      setState(() => _isGuestConnecting = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() {
          _isGuestConnecting = false;
          _isGuestConnected = true;
          _liveComments.add({
            'user': 'System',
            'text': 'Connected to Video Live Guest Seat! 🎙️📹',
            'color': const Color(0xFF00E5FF),
          });
        });
      }
    }
  }

  void _minimizeToPiP() {
    PiPCallOverlay.showMiniWindow(
      context,
      remoteVideoView: RepaintBoundary(child: _buildLiveStreamView()),
      peerName: widget.host.name,
      callDurationText: 'LIVE',
      callSessionId: widget.liveId ?? 'live_${widget.host.id}',
      onTapRestore: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => widget),
        );
      },
      onEndCall: () {
        Navigator.of(context).pop();
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _minimizeToPiP();
        }
      },
      child: GiftAnimationOverlay(
        key: _giftAnimKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onDoubleTap: _addHeart,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Live Video Player / Broadcast View
                _buildLiveStreamView(),

                // 2. Gradient Overlays
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xBB000000),
                          Colors.transparent,
                          Color(0xDD000000),
                        ],
                        stops: [0.0, 0.4, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // 3. Multi-Guest Floating Video Box (When connected as Guest)
                if (_isGuestConnected)
                  Positioned(
                    right: 14,
                    top: 140,
                    child: Container(
                      width: 110,
                      height: 155,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1435),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedImageLoader(
                              imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.mic_rounded, color: AppColors.onlineGreen, size: 10),
                                    SizedBox(width: 2),
                                    Text('Guest', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _toggleMultiGuestConnect,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. Top Bar: Host Capsule, Viewer Count, Close / PiP
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Host Profile Capsule
                        GestureDetector(
                          onTap: () {
                            InCallProfileSheet.show(context, model: widget.host);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AvatarWithFrame(
                                  avatarUrl: widget.host.avatarUrl,
                                  frameUrl: widget.host.avatarFrameUrl,
                                  level: widget.host.currentLevel > 0 ? widget.host.currentLevel : widget.host.level,
                                  badgeColor: widget.host.badgeColor,
                                  glowColor: widget.host.glowColor,
                                  size: 32,
                                  showLevelBadge: false,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.host.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 11),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$_viewerCount',
                                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),

                                // Follow Host Button
                                GestureDetector(
                                  onTap: _toggleFollow,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: _isFollowing
                                          ? const LinearGradient(colors: [Color(0xFF455A64), Color(0xFF37474F)])
                                          : AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _isFollowing ? 'Joined' : '+ Follow',
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right: Minimize / PiP & Close Button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // PiP Minimize Button
                            IconButton(
                              icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                              onPressed: _minimizeToPiP,
                            ),
                            // Close Button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Floating Likes / Heart Burst Animations
                Positioned(
                  right: 20,
                  bottom: 140,
                  width: 80,
                  height: 220,
                  child: Stack(
                    children: _hearts.map((h) {
                      return Positioned(
                        bottom: 0,
                        right: h.left,
                        child: _FloatingHeartWidget(heart: h),
                      );
                    }).toList(),
                  ),
                ),

                // 6. Floating Live Comments Overlay
                Positioned(
                  left: 12,
                  bottom: 80,
                  right: 70,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _liveComments.length,
                      itemBuilder: (context, index) {
                        final c = _liveComments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12, width: 0.8),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${c['user']}: ',
                                      style: TextStyle(
                                        color: c['color'] as Color? ?? AppColors.neonPink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: c['text']?.toString() ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 7. Right Action Column: Multi-Guest Connect, Beauty Filters, Gift, Likes
                Positioned(
                  right: 14,
                  bottom: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Multi-Guest Connect Video Call Button (Requested in Voice: একাধিক মানুষ কানেক্ট হইতে পারতেছে)
                      _buildLiveActionButton(
                        icon: _isGuestConnected ? Icons.phone_disabled_rounded : Icons.video_call_rounded,
                        label: _isGuestConnected ? 'Disconnect' : 'Connect',
                        color: _isGuestConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                        isLoading: _isGuestConnecting,
                        onTap: _toggleMultiGuestConnect,
                      ),
                      const SizedBox(height: 12),

                      // Beauty Filter Button
                      _buildLiveActionButton(
                        icon: Icons.auto_fix_high_rounded,
                        label: 'Beauty',
                        color: AppColors.neonPink,
                        onTap: () {
                          CameraFilterTray.show(
                            context,
                            currentFilter: _currentFilter,
                            onFilterSelected: (preset) {
                              setState(() => _currentFilter = preset);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Gift Button
                      _buildLiveActionButton(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Gift',
                        color: const Color(0xFFFFD54F),
                        onTap: () {
                          InCallGiftSheet.show(
                            context,
                            receiverId: widget.host.id,
                            receiverName: widget.host.name,
                            callSessionId: widget.liveId,
                            onGiftSent: (anim) {
                              _giftAnimKey.currentState?.playGiftAnimation(anim);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Heart Like Tap Button
                      _buildLiveActionButton(
                        icon: Icons.favorite_rounded,
                        label: '$_likeCount',
                        color: const Color(0xFFFF007F),
                        onTap: _addHeart,
                      ),
                    ],
                  ),
                ),

                // 8. Bottom Live Comment Input Bar
                Positioned(
                  bottom: 16,
                  left: 14,
                  right: 14,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Say something nice...',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendComment,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStreamView() {
    return RepaintBoundary(
      child: BeautyFilterEngine.applyFilterToWidget(
        filter: _currentFilter,
        child: CachedImageLoader(
          imageUrl: widget.host.avatarUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLiveActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    ),
                  )
                : Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _FloatingHeartWidget extends StatefulWidget {
  final LiveHeart heart;
  const _FloatingHeartWidget({required this.heart});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _translateY = Tween<double>(begin: 0, end: -180).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)));
    _scale = Tween<double>(begin: 0.4, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Icon(Icons.favorite_rounded, color: widget.heart.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
