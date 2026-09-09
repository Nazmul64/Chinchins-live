import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/theme/app_colors.dart';
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
  List<PartyRoomTopicTag> _tags = PartyRoomConfig.defaultTags;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await PartyRoomApiService.getConfig();
    if (mounted) {
      setState(() {
        if (config.topicTags.isNotEmpty) {
          _tags = config.topicTags;
          if (!_tags.any((t) => t.name == _selectedTag || t.tag == _selectedTag)) {
            _selectedTag = _tags.first.name.isNotEmpty ? _tags.first.name : _tags.first.tag;
          }
        }
      });
    }
  }

  Future<void> _startPartyRoom() async {
    final title = _titleController.text.trim().isEmpty ? 'My Live Fun Hangout 🥳✨' : _titleController.text.trim();

    setState(() => _isCreating = true);

    final roomTypeStr = _selectedType == PartyRoomType.audioVoice ? 'voice' : 'video';

    final result = await PartyRoomApiService.createPartyRoom(
      roomTitle: title,
      roomType: roomTypeStr,
      topicTag: _selectedTag,
      maxSeats: 10,
      coinRatePerMinute: 100,
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (result['success'] == true && result['room'] is GroupPartyRoom) {
      final GroupPartyRoom createdRoom = result['room'] as GroupPartyRoom;

      if (_selectedType == PartyRoomType.audioVoice) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VoicePartyRoomScreen(room: createdRoom),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPartyRoomScreen(room: createdRoom),
          ),
        );
      }
    } else {
      // Fallback local room for offline or graceful recovery
      final localRoom = GroupPartyRoom(
        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
        roomId: 'PR${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        title: title,
        hostId: '1',
        hostName: 'You (Host)',
        hostAvatar: '',
        coverUrl: '',
        channelName: 'party_${_selectedType == PartyRoomType.audioVoice ? "voice" : "video"}_${DateTime.now().millisecondsSinceEpoch}',
        roomType: _selectedType,
        tag: _selectedTag,
        maxSeats: 10,
        occupiedSeats: 1,
        audienceCount: 1,
        seats: [
          const RoomSeat(
            seatIndex: 0,
            userId: '1',
            userName: 'You (Host)',
            isHost: true,
            isSpeaking: true,
            status: 'occupied',
            role: 'host',
          ),
          ...List.generate(9, (index) => RoomSeat(seatIndex: index + 1)),
        ],
      );

      if (_selectedType == PartyRoomType.audioVoice) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VoicePartyRoomScreen(room: localRoom),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPartyRoomScreen(room: localRoom),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161126),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
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

                // Header Title
                const Text(
                  'Host a Party Room 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                  children: _tags.map((topic) {
                    final isSelected = _selectedTag == topic.name || _selectedTag == topic.tag;
                    final displayLabel = topic.name.isNotEmpty ? topic.name : topic.tag;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedTag = displayLabel),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : AppColors.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : AppColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          displayLabel,
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
                    onPressed: _isCreating ? null : _startPartyRoom,
                    child: _isCreating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
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
