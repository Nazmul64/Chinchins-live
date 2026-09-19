import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../../call/screens/live_room_screen.dart';
import '../../call/services/live_streaming_api_service.dart';

class LiveFeedView extends StatefulWidget {
  final List<ModelProfile> models;
  final VoidCallback onRefresh;

  const LiveFeedView({
    super.key,
    required this.models,
    required this.onRefresh,
  });

  @override
  State<LiveFeedView> createState() => _LiveFeedViewState();
}

class _LiveFeedViewState extends State<LiveFeedView>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _activeStreams = [];
  bool _isLoadingStreams = false;
  late AnimationController _equalizerController;

  // Fallback showcase streamers matching Screenshot 1
  static final List<Map<String, dynamic>> _showcaseStreamers = [
    {
      'id': 'showcase_live_1',
      'title': 'Chatting & Singing! 🎵',
      'viewer_count': 128,
      'cover_image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
      'host': {
        'id': '101',
        'name': 'cute pori',
        'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        'level': 6,
        'country': 'Bangladesh',
        'flag': '🇧🇩',
      },
    },
    {
      'id': 'showcase_live_2',
      'title': 'Late Night Talk 🌙',
      'viewer_count': 94,
      'cover_image': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=80',
      'host': {
        'id': '102',
        'name': 'Micca',
        'avatar_url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
        'level': 6,
        'country': 'Philippines',
        'flag': '🇵🇭',
      },
    },
    {
      'id': 'showcase_live_3',
      'title': 'Chill Vibes with Anne ✨',
      'viewer_count': 210,
      'cover_image': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=500&auto=format&fit=crop&q=80',
      'host': {
        'id': '103',
        'name': 'Anne',
        'avatar_url': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
        'level': 7,
        'country': 'Pakistan',
        'flag': '🇵🇰',
      },
    },
    {
      'id': 'showcase_live_4',
      'title': 'Dance & Music Party 💃',
      'viewer_count': 76,
      'cover_image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80',
      'host': {
        'id': '104',
        'name': 'Sona',
        'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
        'level': 8,
        'country': 'India',
        'flag': '🇮🇳',
      },
    },
    {
      'id': 'showcase_live_5',
      'title': 'Voice & Stories 📖',
      'viewer_count': 150,
      'cover_image': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=500&auto=format&fit=crop&q=80',
      'host': {
        'id': '105',
        'name': 'Zoya',
        'avatar_url': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=200&auto=format&fit=crop&q=80',
        'level': 5,
        'country': 'Global',
        'flag': '🌐',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _loadActiveStreams();
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveStreams() async {
    setState(() => _isLoadingStreams = true);
    try {
      final streams = await LiveStreamingApiService.getActiveLiveStreams();
      if (mounted) {
        setState(() {
          _activeStreams = streams;
          _isLoadingStreams = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStreams = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    widget.onRefresh();
    await _loadActiveStreams();
  }

  Future<void> _startHostBroadcast() async {
    final savedUser = await AuthApiService.getSavedUser();
    final String myId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString() ?? 'host_me';
    final String myName = savedUser?['name']?.toString() ?? savedUser?['display_name']?.toString() ?? 'My Broadcast';
    final String myAvatar = savedUser?['avatar']?.toString() ?? savedUser?['avatar_url']?.toString() ?? 'https://chinchins.live/uploads/app/logo.png';

    final hostModel = ModelProfile.fromJson({
      'id': myId,
      'account_id': savedUser?['account_id']?.toString() ?? myId,
      'name': myName,
      'avatar_url': myAvatar,
      'price_per_min': 100,
      'country': savedUser?['country'] ?? 'Global',
    });

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(
          host: hostModel,
          title: 'Welcome to my official live stream! 🌟',
          isHost: true,
        ),
      ),
    );

    if (mounted) {
      _loadActiveStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allStreams = _activeStreams.isNotEmpty ? _activeStreams : _showcaseStreamers;

    return Column(
      children: [
        // Sub-bar with grid layout switch (⊞) and Link / Filter button matching Screenshot 1
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              // Orange square grid switch button (Screenshot 1)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),

              // Link / Category pill (Screenshot 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2442),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text(
                  'Link',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Quick "Go Live" action badge
              GestureDetector(
                onTap: _startHostBroadcast,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A6D), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Go Live',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Live Broadcasters Grid with Hot Promotional Card matching Screenshot 1
        Expanded(
          child: RefreshIndicator(
            color: AppColors.neonPink,
            onRefresh: _handleRefresh,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: allStreams.length + 1, // +1 for the "🔥 Hot" card inserted into the grid
              itemBuilder: (context, index) {
                // Insert the "🔥 Hot" Category Card at index 2 (Screenshot 1)
                if (index == 2) {
                  return _buildHotPromoCard();
                }

                final streamIndex = index > 2 ? index - 1 : index;
                final stream = allStreams[streamIndex % allStreams.length];
                return _buildLiveStreamCard(context, stream, streamIndex);
              },
            ),
          ),
        ),
      ],
    );
  }

  // "🔥 Hot" Categories Card matching Screenshot 1 (Pretty, New, Sexy)
  Widget _buildHotPromoCard() {
    final categories = [
      {
        'title': 'Pretty',
        'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      },
      {
        'title': 'New',
        'image': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Sexy',
        'image': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&auto=format&fit=crop&q=80',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF281C44), Color(0xFF1E1533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: 🔥 Hot
          Row(
            children: const [
              Text('🔥', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text(
                'Hot',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3 Categories (Pretty, New, Sexy)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: categories.map((cat) {
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedImageLoader(
                          imageUrl: cat['image']!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cat['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamCard(BuildContext context, Map<String, dynamic> stream, int index) {
    final hostMap = stream['host'] is Map ? Map<String, dynamic>.from(stream['host'] as Map) : <String, dynamic>{};
    final hostModel = ModelProfile.fromJson({
      'id': (hostMap['id'] ?? stream['host_id'] ?? index).toString(),
      'account_id': (hostMap['account_id'] ?? hostMap['id'] ?? '').toString(),
      'name': hostMap['display_name'] ?? hostMap['name'] ?? 'cute pori',
      'avatar_url': hostMap['avatar_url'] ?? stream['cover_image_url'] ?? stream['cover_image'] ?? '',
      'gender': hostMap['gender'] ?? 'female',
      'location': hostMap['country'] ?? 'Bangladesh',
      'level': hostMap['level'] ?? 6,
      ...hostMap,
    });

    final title = stream['title']?.toString() ?? '${hostModel.name}\'s Live Room';
    final coverUrl = stream['cover_image'] ?? stream['cover_image_url'] ?? hostModel.avatarUrl;
    final flag = hostMap['flag'] ?? '🇵🇰';
    final level = hostMap['level'] ?? 6;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(
              host: hostModel,
              liveId: stream['id'] ?? stream['live_stream_id'],
              channelName: stream['channel_name'],
              title: title,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Photo
              CachedImageLoader(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x33000000),
                        Colors.transparent,
                        Color(0xDD0F0E17),
                      ],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Top Left Badge: ılı Live matching Screenshot 3
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD946EF).withValues(alpha: 0.85), // Magenta/purple pill
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLiveWaveEqualizer(),
                      const SizedBox(width: 4),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Info: Host Name & Status / Level Badge (Screenshot 3)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hostModel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Country Flag / Globe Pill
                        Text(flag, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        // Level Badge Pill (Screenshot 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💖', style: TextStyle(fontSize: 8)),
                              const SizedBox(width: 2),
                              Text(
                                'Lv$level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Audio Equalizer Wave Animation for Live Badge (Screenshot 3)
  Widget _buildLiveWaveEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        final v = _equalizerController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 2.0,
              height: 4.5 + sin(v * pi * 2) * 3.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 1.5),
            Container(
              width: 2.0,
              height: 7.5 + cos(v * pi * 2) * 3.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 1.5),
            Container(
              width: 2.0,
              height: 5.5 + sin((v + 0.5) * pi * 2) * 3.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        );
      },
    );
  }
}
