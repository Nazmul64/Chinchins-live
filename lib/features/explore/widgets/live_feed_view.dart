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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _activeStreams = [];
  bool _isLoadingStreams = false;
  late AnimationController _equalizerController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isLoadingStreams = _activeStreams.isEmpty;
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
    if (_activeStreams.isEmpty) {
      setState(() => _isLoadingStreams = true);
    }
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
        setState(() {
          _isLoadingStreams = false;
        });
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
    super.build(context);
    return Column(
      children: [
        // Sub-bar with grid layout switch and Go Live button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2442),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text(
                  'Live',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A6D), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text(
                        'Go Live',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Live Broadcasters Grid or Dynamic Empty State
        Expanded(
          child: RefreshIndicator(
            color: AppColors.neonPink,
            onRefresh: _handleRefresh,
            child: _isLoadingStreams && _activeStreams.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : _activeStreams.isEmpty
                    ? _buildEmptyStreamsView()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _activeStreams.length,
                        itemBuilder: (context, index) {
                          final stream = _activeStreams[index];
                          return _buildLiveStreamCard(context, stream, index);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStreamsView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF2A6D).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFF2A6D).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.live_tv_rounded,
                    color: Color(0xFFFF2A6D),
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Live Broadcasts Right Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Be the first to go live and broadcast to everyone on Chinchins Live!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startHostBroadcast,
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text(
                  'Start Live Stream',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A6D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 6,
                  shadowColor: const Color(0xFFFF2A6D).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStreamCard(BuildContext context, Map<String, dynamic> stream, int index) {
    final hostMap = stream['host'] is Map ? Map<String, dynamic>.from(stream['host'] as Map) : <String, dynamic>{};
    final hostModel = ModelProfile.fromJson({
      'id': (hostMap['id'] ?? stream['host_id'] ?? index).toString(),
      'account_id': (hostMap['account_id'] ?? hostMap['id'] ?? '').toString(),
      'name': hostMap['display_name'] ?? hostMap['name'] ?? stream['title'] ?? 'Live Host',
      'avatar_url': hostMap['avatar_url'] ?? stream['cover_image_url'] ?? stream['cover_image'] ?? '',
      'gender': hostMap['gender'] ?? 'female',
      'location': hostMap['country'] ?? 'Global',
      'level': hostMap['level'] ?? 1,
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
