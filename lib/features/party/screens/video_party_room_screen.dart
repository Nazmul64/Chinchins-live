import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../../core/data/mock_data.dart';

class VideoPartyRoomScreen extends StatefulWidget {
  final GroupPartyRoom room;

  const VideoPartyRoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<VideoPartyRoomScreen> createState() => _VideoPartyRoomScreenState();
}

class _VideoPartyRoomScreenState extends State<VideoPartyRoomScreen> {
  late List<RoomSeat> _videoSeats;
  final List<String> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isMyMicMuted = false;
  bool _isMyCameraOff = false;
  String? _activeGiftShower;
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _videoSeats = List.from(widget.room.seats);
    _chatMessages.addAll([
      '📢 Welcome to ${widget.room.title}!',
      '🔥 Habiba: Hey everyone! Join our live multi-guest video chat!',
      '✨ Ruhi: Sending love to everyone watching ❤️',
    ]);

    _chatTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        final messages = [
          '🌹 Prince Alex sent 500 💎 to Host',
          '💬 User_88: Everyone looking so beautiful today!',
          '✨ King_BD: Hello Habiba and Ruhi!',
          '🎁 Guest_31 sent a Fire Dragon 🐉',
        ];
        setState(() {
          _chatMessages.add(messages[timer.tick % messages.length]);
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add('You: $text');
      _chatController.clear();
    });
    _scrollToBottom();
  }

  void _showAddVideoGuestDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Co-Host / Video Guest',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Invite online girls or friends to join multi-screen video',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...MockData.models.take(4).map((model) => ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(model.avatarUrl)),
                  title: Text(model.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Online • ${model.location}', style: const TextStyle(color: AppColors.onlineGreen, fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      final emptyIndex = _videoSeats.indexWhere((s) => s.isEmpty);
                      if (emptyIndex != -1) {
                        setState(() {
                          _videoSeats[emptyIndex] = RoomSeat(
                            seatIndex: emptyIndex,
                            userId: model.id,
                            userName: model.name,
                            userAvatar: model.avatarUrl,
                            isSpeaking: true,
                          );
                          _chatMessages.add('📹 ${model.name} joined video seat ${emptyIndex + 1}!');
                        });
                        _scrollToBottom();
                      }
                    },
                    child: const Text('Connect Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _openGiftModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerModal(
        onGiftSelected: (gift) {
          setState(() {
            _activeGiftShower = gift.emoji;
            _chatMessages.add('🎁 You showered ${gift.name} ${gift.emoji} in the video room!');
          });
          _scrollToBottom();

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _activeGiftShower = null;
              });
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Body
          SafeArea(
            child: Column(
              children: [
                // 1. Top Bar Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Host Info Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(widget.room.hostAvatar),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.room.hostName,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${widget.room.audienceCount} online',
                                  style: const TextStyle(color: AppColors.onlineGreen, fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Audience Avatars
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.room.audienceAvatars.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: ClipOval(
                                child: CachedImageLoader(
                                  imageUrl: widget.room.audienceAvatars[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Close Room Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 2. Multi-Guest 4-Grid Video Matrix (2x2 Grid)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: _videoSeats.length,
                      itemBuilder: (context, index) {
                        final seat = _videoSeats[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1830),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: seat.isHost
                                  ? AppColors.gemYellow
                                  : (seat.isSpeaking ? AppColors.neonPink : AppColors.cardBorder),
                              width: seat.isHost || seat.isSpeaking ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: seat.isEmpty
                                ? GestureDetector(
                                    onTap: _showAddVideoGuestDialog,
                                    child: Container(
                                      color: const Color(0xFF171324),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, color: AppColors.neonPink, size: 32),
                                          SizedBox(height: 6),
                                          Text(
                                            '+ Add Guest',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedImageLoader(
                                        imageUrl: seat.userAvatar!,
                                        fit: BoxFit.cover,
                                      ),
                                      Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.transparent, Color(0xBB000000)],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 6,
                                        left: 8,
                                        right: 8,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              seat.userName!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (seat.isHost)
                                              const Icon(Icons.military_tech_rounded, color: AppColors.gemYellow, size: 14)
                                            else
                                              const Icon(Icons.videocam_rounded, color: AppColors.onlineGreen, size: 14),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // 3. Live Chat Messages Stream
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        final isGift = msg.startsWith('🎁') || msg.startsWith('🌹');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isGift
                                ? AppColors.warmOrange.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isGift ? AppColors.gemYellow : Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 4. Bottom Controls Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF120E1F),
                    border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
                  ),
                  child: Row(
                    children: [
                      // Chat Input
                      Expanded(
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardDarkElevated,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Chat with group...',
                              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 10),
                            ),
                            onSubmitted: (_) => _sendChat(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send Button
                      GestureDetector(
                        onTap: _sendChat,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mic Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMyMicMuted = !_isMyMicMuted;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMyMicMuted ? const Color(0xFFFF1744) : AppColors.cardDarkElevated,
                          ),
                          child: Icon(
                            _isMyMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Camera Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMyCameraOff = !_isMyCameraOff;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMyCameraOff ? const Color(0xFFFF1744) : AppColors.cardDarkElevated,
                          ),
                          child: Icon(
                            _isMyCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Add Guest / Invite Button
                      GestureDetector(
                        onTap: _showAddVideoGuestDialog,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.orangeGradient,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Gift Button
                      GestureDetector(
                        onTap: _openGiftModal,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                            ),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Animated Gift Shower Overlay
          if (_activeGiftShower != null)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1.8),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: AppColors.gemYellow, width: 2),
                      ),
                      child: Text(
                        _activeGiftShower!,
                        style: const TextStyle(fontSize: 70),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
