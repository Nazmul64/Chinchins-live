import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/mock_data.dart';
import 'voice_party_room_screen.dart';
import 'video_party_room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  PartyRoomType _selectedType = PartyRoomType.audioVoice;
  final TextEditingController _titleController = TextEditingController(text: 'My Live Fun Hangout 🥳✨');
  String _selectedTag = 'Singing 🎤';

  final List<String> _tags = [
    'Singing 🎤',
    'Dating 💕',
    'Party 💃',
    'ChitChat 💬',
    'Gaming 🎮',
    'Late Night 🌙',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _startPartyRoom() {
    final title = _titleController.text.trim().isEmpty ? 'Live Party Room' : _titleController.text.trim();

    if (_selectedType == PartyRoomType.audioVoice) {
      final newRoom = GroupPartyRoom(
        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        hostId: 'my_host_id',
        hostName: 'Guest_ddD7Su',
        hostAvatar: MockData.imgLivePreview,
        coverUrl: MockData.imgLivePreview,
        roomType: PartyRoomType.audioVoice,
        tag: _selectedTag,
        audienceCount: 1,
        seats: [
          const RoomSeat(
            seatIndex: 0,
            userId: 'my_host_id',
            userName: 'You (Host)',
            userAvatar: MockData.imgLivePreview,
            isHost: true,
            isSpeaking: true,
          ),
          const RoomSeat(seatIndex: 1),
          const RoomSeat(seatIndex: 2),
          const RoomSeat(seatIndex: 3),
          const RoomSeat(seatIndex: 4),
          const RoomSeat(seatIndex: 5),
          const RoomSeat(seatIndex: 6),
          const RoomSeat(seatIndex: 7),
        ],
        audienceAvatars: [],
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoicePartyRoomScreen(room: newRoom),
        ),
      );
    } else {
      final newRoom = GroupPartyRoom(
        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        hostId: 'my_host_id',
        hostName: 'Guest_ddD7Su',
        hostAvatar: MockData.imgLivePreview,
        coverUrl: MockData.imgLivePreview,
        roomType: PartyRoomType.videoParty,
        tag: _selectedTag,
        audienceCount: 1,
        seats: [
          const RoomSeat(
            seatIndex: 0,
            userId: 'my_host_id',
            userName: 'You (Host)',
            userAvatar: MockData.imgLivePreview,
            isHost: true,
            isSpeaking: true,
          ),
          const RoomSeat(seatIndex: 1),
          const RoomSeat(seatIndex: 2),
          const RoomSeat(seatIndex: 3),
        ],
        audienceAvatars: [],
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPartyRoomScreen(room: newRoom),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Host a Party Room 🎉',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create a multi-user audio voice or video chat room and invite 10 to 50+ members!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Mode Selector (Voice Party vs Video Multi-Guest)
              Row(
                children: [
                  Expanded(
                    child: _buildTypeCard(
                      type: PartyRoomType.audioVoice,
                      title: 'Voice Party 🎙️',
                      subtitle: '8-12 Seats Audio Stage',
                      icon: Icons.mic_rounded,
                      color: AppColors.neonPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeCard(
                      type: PartyRoomType.videoParty,
                      title: 'Video Party 📹',
                      subtitle: 'Multi-Guest Video Grid',
                      icon: Icons.videocam_rounded,
                      color: AppColors.neonPink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Room Title Input
              const Text(
                'Room Title',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter room title...',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Room Tags
              const Text(
                'Select Topic Tag',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  final isSelected = _selectedTag == tag;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTag = tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : AppColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Start Party Room Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 8,
                  ),
                  onPressed: _startPartyRoom,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Start Party Room Now',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required PartyRoomType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
