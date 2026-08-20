import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../widgets/room_seat_widget.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../../core/data/mock_data.dart';

class VoicePartyRoomScreen extends StatefulWidget {
  final GroupPartyRoom room;

  const VoicePartyRoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<VoicePartyRoomScreen> createState() => _VoicePartyRoomScreenState();
}

class _VoicePartyRoomScreenState extends State<VoicePartyRoomScreen> {
  late List<RoomSeat> _seats;
  final List<String> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isMyMicMuted = false;
  bool _amIOnSeat = false;
  int? _mySeatIndex;
  String? _activeGiftShower;
  Timer? _simulatedChatTimer;

  @override
  void initState() {
    super.initState();
    _seats = List.from(widget.room.seats);
    _chatMessages.addAll([
      '📢 Welcome to ${widget.room.title}! Please be respectful.',
      '✨ Habiba: Hey everyone! Welcome to our voice party ❤️',
      '🎵 Mahi: Anyone want to request a song?',
    ]);

    // Simulate active room chat and audience joining
    _simulatedChatTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        final sampleMessages = [
          '🌹 Prince Alex sent 200 💎 to ${widget.room.hostName}',
          '💬 Guest_78: Hello everyone, nice room!',
          '👑 King_99 joined the room',
          '🔥 Tinni: Voice is so clear!',
          '✨ Moyna: Love the music vibe here 🎶',
        ];
        final randomMsg = sampleMessages[timer.tick % sampleMessages.length];
        setState(() {
          _chatMessages.add(randomMsg);
        });
        _scrollChatToBottom();
      }
    });
  }

  @override
  void dispose() {
    _simulatedChatTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add('You: $text');
      _chatController.clear();
    });
    _scrollChatToBottom();
  }

  void _handleSeatTap(int index) {
    final seat = _seats[index];

    if (seat.isEmpty) {
      if (!_amIOnSeat) {
        // Take empty seat
        setState(() {
          _seats[index] = RoomSeat(
            seatIndex: index,
            userId: 'my_user_id',
            userName: 'You',
            userAvatar: MockData.imgLivePreview,
            isSpeaking: false,
            isMuted: _isMyMicMuted,
          );
          _amIOnSeat = true;
          _mySeatIndex = index;
          _chatMessages.add('🎤 You took Seat ${index + 1}!');
        });
        _scrollChatToBottom();
      } else {
        // Move to new empty seat
        setState(() {
          if (_mySeatIndex != null) {
            _seats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
          }
          _seats[index] = RoomSeat(
            seatIndex: index,
            userId: 'my_user_id',
            userName: 'You',
            userAvatar: MockData.imgLivePreview,
            isSpeaking: false,
            isMuted: _isMyMicMuted,
          );
          _mySeatIndex = index;
        });
      }
    } else {
      // Show user action profile / controls
      _showUserSeatOptions(seat);
    }
  }

  void _showUserSeatOptions(RoomSeat seat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(seat.userAvatar!),
            ),
            const SizedBox(height: 10),
            Text(
              seat.userName!,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Seat ${seat.seatIndex + 1} ${seat.isHost ? "• Host" : "• Speaker"}',
              style: const TextStyle(color: AppColors.gemYellow, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(Icons.card_giftcard_rounded, 'Send Gift', () {
                  Navigator.pop(context);
                  _openGiftPicker();
                }),
                _buildActionChip(Icons.chat_rounded, 'Private Chat', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening chat with ${seat.userName}')),
                  );
                }),
                if (seat.userId == 'my_user_id')
                  _buildActionChip(Icons.logout_rounded, 'Leave Seat', () {
                    Navigator.pop(context);
                    setState(() {
                      _seats[seat.seatIndex] = RoomSeat(seatIndex: seat.seatIndex);
                      _amIOnSeat = false;
                      _mySeatIndex = null;
                      _chatMessages.add('👋 You left the seat.');
                    });
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAddGuestDialog() {
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
              'Invite Friends / Guests to Stage',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select any online user to invite them to a speaker seat',
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
                      // Place invited guest on first available empty seat
                      final emptyIndex = _seats.indexWhere((s) => s.isEmpty);
                      if (emptyIndex != -1) {
                        setState(() {
                          _seats[emptyIndex] = RoomSeat(
                            seatIndex: emptyIndex,
                            userId: model.id,
                            userName: model.name,
                            userAvatar: model.avatarUrl,
                            isSpeaking: true,
                          );
                          _chatMessages.add('🎉 Host invited ${model.name} to Seat ${emptyIndex + 1}!');
                        });
                        _scrollChatToBottom();
                      }
                    },
                    child: const Text('Add to Stage', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _openGiftPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerModal(
        onGiftSelected: (gift) {
          setState(() {
            _activeGiftShower = gift.emoji;
            _chatMessages.add('🎁 You sent ${gift.name} ${gift.emoji} to the party room!');
          });
          _scrollChatToBottom();

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
      backgroundColor: const Color(0xFF140F24),
      body: Stack(
        children: [
          // Background Gradient Wallpaper
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF261238), Color(0xFF130D21), Color(0xFF0D0A17)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Gift Shower Overlay
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

          // Main Screen Body
          SafeArea(
            child: Column(
              children: [
                // 1. Room Top Bar Header (Host info, Audience avatars count, Close/Leave)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Host Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(widget.room.hostAvatar),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.room.hostName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded, color: AppColors.neonPink, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${widget.room.audienceCount} in room',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Audience Avatars Strip
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.room.audienceAvatars.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 32,
                              height: 32,
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

                      // Close / Leave Room Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Room Title Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded, color: AppColors.gemYellow, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.room.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.room.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. 8-Seat Stage Grid (2 rows x 4 seats)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1735).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        // Row 1 (Seats 1 - 4)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                            4,
                            (index) => RoomSeatWidget(
                              seat: _seats[index],
                              onTap: () => _handleSeatTap(index),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Row 2 (Seats 5 - 8)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                            4,
                            (index) => RoomSeatWidget(
                              seat: _seats[index + 4],
                              onTap: () => _handleSeatTap(index + 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Live Chat Messages Stream
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        final isNotice = msg.startsWith('📢') || msg.startsWith('👑') || msg.startsWith('🎉');
                        final isGift = msg.startsWith('🎁') || msg.startsWith('🌹');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isNotice
                                ? AppColors.neonPurple.withValues(alpha: 0.2)
                                : (isGift
                                    ? AppColors.warmOrange.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isGift
                                  ? AppColors.gemYellow.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isGift ? AppColors.gemYellow : Colors.white,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 4. Bottom Party Room Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF130D21),
                    border: Border(
                      top: BorderSide(color: AppColors.cardBorder, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Chat Input Field
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardDarkElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Say something in room...',
                              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 8),
                            ),
                            onSubmitted: (_) => _sendChatMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send Chat Button
                      GestureDetector(
                        onTap: _sendChatMessage,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mic Mute Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMyMicMuted = !_isMyMicMuted;
                            if (_mySeatIndex != null) {
                              _seats[_mySeatIndex!] = _seats[_mySeatIndex!].copyWith(isMuted: _isMyMicMuted);
                            }
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMyMicMuted ? const Color(0xFFFF1744) : AppColors.cardDarkElevated,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Icon(
                            _isMyMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Host Add/Invite Guest Button
                      GestureDetector(
                        onTap: _showAddGuestDialog,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.orangeGradient,
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send Gift Button
                      GestureDetector(
                        onTap: _openGiftPicker,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gemYellow.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
