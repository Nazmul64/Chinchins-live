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
  bool _isLoading = true;
  bool _showMiniPlayer = true;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoading = true);
    try {
      final remoteRooms = await PartyRoomApiService.getPartyRooms(roomType: 'voice');
      if (mounted) {
        setState(() {
          _rooms = remoteRooms.isNotEmpty ? remoteRooms : _getShowcaseRooms();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rooms = _getShowcaseRooms();
          _isLoading = false;
        });
      }
    }
  }

  List<GroupPartyRoom> _getShowcaseRooms() {
    return [
      GroupPartyRoom(
        id: '101',
        roomId: 'P13210',
        title: 'Raja ek',
        hostId: '1',
        hostName: 'Raja ek',
        hostAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&fit=crop&q=80',
        hostLevel: 8,
        roomType: PartyRoomType.audioVoice,
        tag: 'ChitChat',
        audienceCount: 11,
        seats: [
          const RoomSeat(seatIndex: 0, userId: '1', userName: 'Raja', userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&fit=crop&q=80', isHost: true, isSpeaking: true),
          const RoomSeat(seatIndex: 1, userId: '2', userName: 'Alex', userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80', isSpeaking: true),
          const RoomSeat(seatIndex: 2, userId: '3', userName: 'Priya', userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 3, userId: '4', userName: 'Sam', userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 4, userId: '5', userName: 'Moni', userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80'),
        ],
        audienceAvatars: [
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80',
        ],
      ),
      GroupPartyRoom(
        id: '102',
        roomId: 'P25001',
        title: 'SONA 🌹 SONA 🌹',
        hostId: '2',
        hostName: 'SONA',
        hostAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&fit=crop&q=80',
        hostLevel: 7,
        roomType: PartyRoomType.audioVoice,
        tag: 'Singing',
        audienceCount: 13,
        seats: [
          const RoomSeat(seatIndex: 0, userId: '2', userName: 'SONA', userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80', isHost: true, isSpeaking: true),
          const RoomSeat(seatIndex: 1, userId: '6', userName: 'SK', userAvatar: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=100&fit=crop&q=80', isSpeaking: false),
          const RoomSeat(seatIndex: 2, userId: '7', userName: 'Rohan', userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 3, userId: '8', userName: 'Tisha', userAvatar: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 4, userId: '9', userName: 'Nirav', userAvatar: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100&fit=crop&q=80'),
        ],
        audienceAvatars: [
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100&fit=crop&q=80',
        ],
      ),
      GroupPartyRoom(
        id: '103',
        roomId: 'P62000',
        title: 'Har Har mohadev 🙏🙏',
        hostId: '3',
        hostName: 'Devotee',
        hostAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&fit=crop&q=80',
        hostLevel: 6,
        roomType: PartyRoomType.audioVoice,
        tag: 'Devotional',
        audienceCount: 9,
        seats: [
          const RoomSeat(seatIndex: 0, userId: '3', userName: 'Dev', userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80', isHost: true),
          const RoomSeat(seatIndex: 1, userId: '10', userName: 'Arjun', userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 2, userId: '11', userName: 'Shiva', userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 3, userId: '12', userName: 'Mina', userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 4, userId: '13', userName: 'Kunal', userAvatar: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80'),
        ],
        audienceAvatars: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80',
        ],
      ),
      GroupPartyRoom(
        id: '104',
        roomId: 'P23700',
        title: 'লিজা মনি',
        hostId: '4',
        hostName: 'লিজা মনি',
        hostAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&fit=crop&q=80',
        hostLevel: 4,
        roomType: PartyRoomType.audioVoice,
        tag: 'Friends',
        audienceCount: 11,
        seats: [
          const RoomSeat(seatIndex: 0, userId: '4', userName: 'Liza', userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80', isHost: true),
          const RoomSeat(seatIndex: 1, userId: '14', userName: 'Joy', userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 2, userId: '15', userName: 'Maya', userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 3, userId: '16', userName: 'Faruk', userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 4, userId: '17', userName: 'Popy', userAvatar: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80'),
        ],
        audienceAvatars: [
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&fit=crop&q=80',
        ],
      ),
      GroupPartyRoom(
        id: '105',
        roomId: 'P35400',
        title: 'রাতজাগা পাখি',
        hostId: '5',
        hostName: 'রাতজাগা পাখি',
        hostAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&fit=crop&q=80',
        coverUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&fit=crop&q=80',
        hostLevel: 5,
        roomType: PartyRoomType.audioVoice,
        tag: 'Midnight Chill',
        audienceCount: 11,
        seats: [
          const RoomSeat(seatIndex: 0, userId: '5', userName: 'Pakhi', userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80', isHost: true),
          const RoomSeat(seatIndex: 1, userId: '18', userName: 'Anik', userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 2, userId: '19', userName: 'Rima', userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 3, userId: '20', userName: 'Babu', userAvatar: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=100&fit=crop&q=80'),
          const RoomSeat(seatIndex: 4, userId: '21', userName: 'Simu', userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80'),
        ],
        audienceAvatars: [
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=100&fit=crop&q=80',
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&fit=crop&q=80',
        ],
      ),
    ];
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

  String _getHeatTag(int index) {
    switch (index) {
      case 0:
        return '1321K';
      case 1:
        return '2500K';
      case 2:
        return '62K';
      case 3:
        return '237K';
      case 4:
        return '354K';
      default:
        return '${(100 + index * 45)}K';
    }
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
                // 1. Highlight Moment Top Banner (Screenshot 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: _buildHighlightMomentBanner(),
                  ),
                ),

                // 2. Vertical Party Rooms List (Screenshot 2)
                if (_isLoading && _rooms.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.neonPink),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final room = _rooms[index];
                          final heatTag = _getHeatTag(index);
                          return _buildPartyRoomCard(room, heatTag, index);
                        },
                        childCount: _rooms.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Floating Voice Party Mini-Player (Bottom-Right matching Screenshot 2)
          if (_showMiniPlayer && _rooms.isNotEmpty)
            Positioned(
              right: 14,
              bottom: 18,
              child: _buildFloatingMiniPlayer(_rooms[1]),
            ),
        ],
      ),
    );
  }

  // Highlight Moment Couple Ceremony Banner (Screenshot 2)
  Widget _buildHighlightMomentBanner() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD5D5),
            Color(0xFFFFE8E8),
            Color(0xFFFFD1DC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9AA2).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background soft heart glows
          Positioned(
            left: 16,
            top: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                  ).createShader(bounds),
                  child: const Text(
                    'Highlight Moment',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      'Sweet Couple',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Ceremony💖✨',
                      style: TextStyle(
                        color: Color(0xFFBE123C),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Wedding Couple Avatars with Gold Crown Rings
          Positioned(
            right: 14,
            top: 10,
            bottom: 10,
            child: Row(
              children: [
                // Couple 1 Ring Avatar
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 2),
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFDFBA), Color(0xFFFFB347)],
                    ),
                  ),
                  child: ClipOval(
                    child: CachedImageLoader(
                      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&q=80',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Couple 2 Ring Avatar with Crown
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFDFBA), Color(0xFFFFB347)],
                        ),
                      ),
                      child: ClipOval(
                        child: CachedImageLoader(
                          imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop&q=80',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: -6,
                      right: 14,
                      child: Text('👑', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vertical Party Room Card Item (Screenshot 2)
  Widget _buildPartyRoomCard(GroupPartyRoom room, String heatTag, int index) {
    final flag = index % 2 == 0 ? '🇮🇳' : '🇧🇩';
    final hasSvip = index == 0;
    final level = room.hostLevel > 0 ? room.hostLevel : 8 - (index % 5);

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
            // 1. Left: Square Room Cover Image with Diamond Badge (Screenshot 2)
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

                // Top-Left Diamond Heat Score Badge (e.g. 💎 1321K)
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

            // 2. Middle Section: Title, Badges (SVIP, Flag, Lv), Overlapping Seat Avatars (Screenshot 2)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    room.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Badges Row: SVIP, Country Flag, Level Badge
                  Row(
                    children: [
                      if (hasSvip) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SVIP3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Country Flag
                      Text(flag, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),

                      // Level Badge (Pink/Purple with Heart)
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
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Overlapping Active Voice Seats Avatars Chain (Screenshot 2)
                  _buildOverlappingAvatars(room),
                ],
              ),
            ),

            // 3. Right: Audio Equalizer Visualizer & Listener Count (Screenshot 2)
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

  // Overlapping Avatars Row (Screenshot 2)
  Widget _buildOverlappingAvatars(GroupPartyRoom room) {
    final activeSeats = room.seats.where((s) => !s.isEmpty).toList();
    final avatars = activeSeats.isNotEmpty
        ? activeSeats.map((s) => s.userAvatar ?? room.hostAvatar).take(5).toList()
        : room.audienceAvatars.take(5).toList();

    if (avatars.isEmpty) {
      avatars.addAll([
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&fit=crop&q=80',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&fit=crop&q=80',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&fit=crop&q=80',
      ]);
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
