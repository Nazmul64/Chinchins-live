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

class _PartyRoomsScreenState extends State<PartyRoomsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Voice Party, 2: Video Party
  List<GroupPartyRoom> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    String? roomType;
    if (_selectedFilterIndex == 1) roomType = 'voice';
    if (_selectedFilterIndex == 2) roomType = 'video';

    final remoteRooms = await PartyRoomApiService.getPartyRooms(roomType: roomType);

    if (mounted) {
      setState(() {
        _rooms = remoteRooms;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Group Party Rooms 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // "+ Host Room" Action Pill Button
                  GestureDetector(
                    onTap: _showCreateRoomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Host Room',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs: All, Voice Party 🎙️, Video Party 📹
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterTab('All Rooms', 0),
                  const SizedBox(width: 8),
                  _buildFilterTab('Voice Party 🎙️', 1),
                  const SizedBox(width: 8),
                  _buildFilterTab('Video Party 📹', 2),
                ],
              ),
            ),

            // Party Rooms Feed (Pull to Refresh)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRooms,
                color: AppColors.neonPink,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.neonPink),
                      )
                    : _rooms.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonPurple.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.celebration_rounded,
                                        color: AppColors.neonPink,
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No live party rooms right now',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Be the first to create a live voice or video stage!',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.neonPink,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      onPressed: _showCreateRoomSheet,
                                      icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                                      label: const Text(
                                        'Start Party Room',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.82,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _rooms.length,
                            itemBuilder: (context, index) {
                              final room = _rooms[index];
                              final isVoice = room.roomType == PartyRoomType.audioVoice;

                              return GestureDetector(
                                onTap: () => _openRoom(room),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: AppColors.cardDark,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Cover Image
                                        if (room.coverUrl.isNotEmpty)
                                          CachedImageLoader(
                                            imageUrl: room.coverUrl,
                                            fit: BoxFit.cover,
                                          )
                                        else
                                          Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Color(0xFF2C194D), Color(0xFF130E26)],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                isVoice ? Icons.mic_rounded : Icons.videocam_rounded,
                                                color: Colors.white24,
                                                size: 48,
                                              ),
                                            ),
                                          ),

                                        // Gradient
                                        Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Color(0x88000000),
                                                Color(0xEE0F0E17),
                                              ],
                                              stops: [0.3, 0.6, 1.0],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),

                                        // Top Badges: Type (Voice/Video) & Audience Count
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          right: 8,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isVoice ? const Color(0xFF7C4DFF) : AppColors.neonPink,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isVoice ? Icons.mic_rounded : Icons.videocam_rounded,
                                                      color: Colors.white,
                                                      size: 11,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      isVoice ? 'Voice' : 'Video',
                                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.people_rounded, color: AppColors.gemYellow, size: 11),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${room.audienceCount}',
                                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Bottom Info: Title, Host Avatar, and Name
                                        Positioned(
                                          left: 8,
                                          right: 8,
                                          bottom: 8,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                room.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 10,
                                                    backgroundColor: const Color(0xFF381F4B),
                                                    child: ClipOval(
                                                      child: room.hostAvatar.isNotEmpty
                                                          ? CachedImageLoader(
                                                              imageUrl: room.hostAvatar,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : Text(
                                                              room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : 'H',
                                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      room.hostName,
                                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
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
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedFilterIndex != index) {
          setState(() => _selectedFilterIndex = index);
          _loadRooms();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonPink : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.cardBorder,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
