import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import 'voice_party_room_screen.dart';
import 'video_party_room_screen.dart';
import 'create_room_screen.dart';

class PartyRoomsScreen extends StatefulWidget {
  const PartyRoomsScreen({super.key});

  @override
  State<PartyRoomsScreen> createState() => _PartyRoomsScreenState();
}

class _PartyRoomsScreenState extends State<PartyRoomsScreen> with SingleTickerProviderStateMixin {
  List<GroupPartyRoom> _rooms = [];
  bool _isLoading = false;
  bool _showMiniPlayer = true;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    _rooms = PartyRoomApiService.getCachedPartyRoomsSync();
    _isLoading = _rooms.isEmpty;

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _loadRooms();
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    if (_rooms.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final remoteRooms = await PartyRoomApiService.getPartyRooms(roomType: 'voice');
      if (mounted) {
        setState(() {
          _rooms = remoteRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openRoom(GroupPartyRoom room) {
    if (room.roomType == PartyRoomType.audioVoice) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoicePartyRoomScreen(room: room),
        ),
      ).then((_) => _loadRooms());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPartyRoomScreen(room: room),
        ),
      ).then((_) => _loadRooms());
    }
  }

  void _showCreateRoomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateRoomScreen(),
    ).then((_) => _loadRooms());
  }

  String _getHeatTag(int count) {
    if (count > 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadRooms,
            color: AppColors.neonPink,
            backgroundColor: AppColors.cardDark,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top Header with Create Room Action
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: _buildPartyHeaderBanner(),
                  ),
                ),

                // Vertical Party Rooms List or Empty State
                if (_isLoading && _rooms.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.neonPink),
                    ),
                  )
                else if (_rooms.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyRoomsView(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final room = _rooms[index];
                          final heatTag = _getHeatTag(room.audienceCount);
                          return _buildPartyRoomCard(room, heatTag, index);
                        },
                        childCount: _rooms.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Floating Voice Party Mini-Player
          if (_showMiniPlayer && _rooms.isNotEmpty)
            Positioned(
              right: 14,
              bottom: 18,
              child: _buildFloatingMiniPlayer(_rooms.first),
            ),
        ],
      ),
    );
  }

  Widget _buildPartyHeaderBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF381F4B),
            Color(0xFF22123B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFFD946EF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Group Voice Lounge',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hangout, chat & listen in live party rooms',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showCreateRoomSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2A6D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16),
                SizedBox(width: 2),
                Text(
                  'Create',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoomsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.speaker_group_rounded,
                  color: Color(0xFFD946EF),
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Party Rooms Active Right Now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your own voice party room, invite friends, and enjoy chatting together!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateRoomSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create Party Room',
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
    );
  }

  // Vertical Party Room Card Item
  Widget _buildPartyRoomCard(GroupPartyRoom room, String heatTag, int index) {
    final level = room.hostLevel > 0 ? room.hostLevel : 1;

    return GestureDetector(
      onTap: () => _openRoom(room),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B152B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Left: Square Room Cover Image with Diamond Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: CachedImageLoader(
                      imageUrl: room.coverUrl.isNotEmpty ? room.coverUrl : room.hostAvatar,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Top-Left Diamond Heat Score Badge
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 9)),
                        const SizedBox(width: 2),
                        Text(
                          heatTag,
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // 2. Middle Section: Title, Badges, Overlapping Seat Avatars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    room.title.isNotEmpty ? room.title : '${room.hostName}\'s Party',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Host Level Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                      const SizedBox(width: 6),
                      Text(
                        room.hostName,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Overlapping Active Voice Seats Avatars Chain
                  _buildOverlappingAvatars(room),
                ],
              ),
            ),

            // 3. Right: Audio Equalizer Visualizer & Listener Count
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedEqualizer(),
                const SizedBox(width: 4),
                Text(
                  '${room.audienceCount}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Overlapping Avatars Row
  Widget _buildOverlappingAvatars(GroupPartyRoom room) {
    final activeSeats = room.seats.where((s) => !s.isEmpty).toList();
    final avatars = activeSeats.isNotEmpty
        ? activeSeats.map((s) => s.userAvatar ?? room.hostAvatar).where((url) => url.isNotEmpty).take(5).toList()
        : room.audienceAvatars.where((url) => url.isNotEmpty).take(5).toList();

    if (avatars.isEmpty && room.hostAvatar.isNotEmpty) {
      avatars.add(room.hostAvatar);
    }

    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(avatars.length, (i) {
          return Transform.translate(
            offset: Offset(i * -5.0, 0),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1B152B), width: 1.5),
              ),
              child: ClipOval(
                child: CachedImageLoader(
                  imageUrl: avatars[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Audio Equalizer Wave Animation (Screenshot 2)
  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        final v = _equalizerController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 2.2,
              height: 6 + sin(v * pi * 2) * 4,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 1.8),
            Container(
              width: 2.2,
              height: 10 + cos(v * pi * 2) * 4,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 1.8),
            Container(
              width: 2.2,
              height: 7 + sin((v + 0.5) * pi * 2) * 4,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        );
      },
    );
  }

  // Floating Mini-Player at Bottom Right (Screenshot 2)
  Widget _buildFloatingMiniPlayer(GroupPartyRoom room) {
    return GestureDetector(
      onTap: () => _openRoom(room),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Host Face Image
              CachedImageLoader(
                imageUrl: room.hostAvatar.isNotEmpty
                    ? room.hostAvatar
                    : 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&q=80',
                fit: BoxFit.cover,
              ),

              // Bottom Equalizer Overlay
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildAnimatedEqualizer(),
                  ),
                ),
              ),

              // Top-Right Close Button
              Positioned(
                top: 3,
                right: 3,
                child: GestureDetector(
                  onTap: () => setState(() => _showMiniPlayer = false),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
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
    );
  }
}
