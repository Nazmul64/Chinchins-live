import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/data/mock_data.dart';
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
  late List<GroupPartyRoom> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = List.from(MockData.partyRooms);
  }

  void _openRoom(GroupPartyRoom room) {
    if (room.roomType == PartyRoomType.audioVoice) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoicePartyRoomScreen(room: room),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPartyRoomScreen(room: room),
        ),
      );
    }
  }

  void _showCreateRoomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateRoomScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _selectedFilterIndex == 0
        ? _rooms
        : (_selectedFilterIndex == 1
            ? _rooms.where((r) => r.roomType == PartyRoomType.audioVoice).toList()
            : _rooms.where((r) => r.roomType == PartyRoomType.videoParty).toList());

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

            // Party Rooms 2-Column Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = filteredRooms[index];
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
                            CachedImageLoader(
                              imageUrl: room.coverUrl,
                              fit: BoxFit.cover,
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
                                        backgroundImage: NetworkImage(room.hostAvatar),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
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
