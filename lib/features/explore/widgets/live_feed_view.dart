import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
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

class _LiveFeedViewState extends State<LiveFeedView> {
  List<Map<String, dynamic>> _activeStreams = [];
  bool _isLoadingStreams = false;

  @override
  void initState() {
    super.initState();
    _loadActiveStreams();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "Go Live" Broadcaster Banner / Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Live Broadcast',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Go live, get gifts & connect multi-guests!',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final defaultModel = widget.models.isNotEmpty
                        ? widget.models.first
                        : ModelProfile.fromJson(const {
                            'id': 'me',
                            'account_id': 'me',
                            'name': 'My Broadcast',
                            'avatar_url': 'https://chinchins.live/uploads/app/logo.png',
                            'price_per_min': 100,
                          });

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveRoomScreen(
                          host: defaultModel,
                          title: 'Welcome to my official live stream! 🌟',
                          isHost: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPink.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Go Live',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Live Broadcasters Grid
        Expanded(
          child: RefreshIndicator(
            color: AppColors.neonPink,
            onRefresh: _handleRefresh,
            child: _isLoadingStreams && _activeStreams.isEmpty && widget.models.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : _activeStreams.isNotEmpty
                    ? GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      return _buildActiveStreamCard(context, stream, index);
                    },
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: widget.models.length,
                    itemBuilder: (context, index) {
                      final model = widget.models[index];
                      return _buildModelLiveCard(context, model, index);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveStreamCard(BuildContext context, Map<String, dynamic> stream, int index) {
    final hostMap = stream['host'] is Map ? Map<String, dynamic>.from(stream['host'] as Map) : <String, dynamic>{};
    final hostModel = ModelProfile.fromJson({
      'id': (hostMap['id'] ?? stream['host_id'] ?? index).toString(),
      'account_id': (hostMap['account_id'] ?? hostMap['id'] ?? '').toString(),
      'name': hostMap['display_name'] ?? hostMap['name'] ?? 'Live Host',
      'avatar_url': hostMap['avatar_url'] ?? stream['cover_image_url'] ?? stream['cover_image'] ?? '',
      'gender': hostMap['gender'] ?? 'female',
      'location': hostMap['country'] ?? 'Bangladesh',
      'display_level': 5,
      ...hostMap,
    });

    final viewerCount = stream['viewer_count'] ?? (100 + (index * 37) % 300);
    final title = stream['title']?.toString() ?? '${hostModel.name}\'s Live Room';
    final coverUrl = stream['cover_image_url'] ?? stream['cover_image'] ?? hostModel.avatarUrl;

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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedImageLoader(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent, Colors.black87],
                      stops: [0.0, 0.4, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF007F), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '$viewerCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hostModel.name,
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
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

  Widget _buildModelLiveCard(BuildContext context, ModelProfile model, int index) {
    final viewerCount = 80 + (index * 47) % 400;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(
              host: model,
              title: '${model.name}\'s Live Room',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedImageLoader(
                imageUrl: model.avatarUrl,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0.0, 0.4, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF007F), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '$viewerCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  model.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (model.countryFlag.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(model.countryFlag, style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lv.${model.currentLevel > 0 ? model.currentLevel : model.level}',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
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
}
