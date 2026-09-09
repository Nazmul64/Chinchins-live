import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/group_room.dart';
import '../../../core/models/live_gift_event.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/services/live_gift_reverb_service.dart';
import '../../../core/widgets/live_gift_animation_overlay.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../widgets/room_seat_widget.dart';
import '../widgets/invite_guests_modal.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../auth/services/auth_api_service.dart';
import '../../wallet/screens/wallet_screen.dart';

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
  final GlobalKey<State<LiveGiftAnimationOverlay>> _giftOverlayKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  late GroupPartyRoom _currentRoom;
  late List<RoomSeat> _seats;
  final List<PartyRoomMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isMyMicMuted = false;
  bool _amIOnSeat = false;
  int? _mySeatIndex;
  bool _isHost = false;
  String? _myUserId;
  String? _myUserName;
  String? _myUserAvatar;

  Timer? _pollingTimer;
  Timer? _billingTimer;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _seats = List.from(widget.room.seats);

    // Ensure 10 seats exist
    while (_seats.length < 10) {
      _seats.add(RoomSeat(seatIndex: _seats.length));
    }

    _initUserData();
    _joinRoomOnServer();
    _loadMessages();

    // 1. Subscribe to Live Gifts & Reverb
    LiveGiftReverbService().subscribeToLiveRoom(
      streamId: widget.room.id,
      onGiftReceived: (giftEvent) {
        if (mounted) {
          (_giftOverlayKey.currentState as dynamic)?.playGift(giftEvent);
          setState(() {
            _messages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'gift',
              message: '🎁 ${giftEvent.senderName} sent ${giftEvent.giftName}! (💎 ${giftEvent.coinsSpent})',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();
        }
      },
    );

    // 2. Poll room updates every 6 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshRoomState();
    });

    // 3. 50/50 Minute Billing Timer (Every 60 seconds)
    _billingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _runMinuteBilling();
    });
  }

  Future<void> _initUserData() async {
    final user = await AuthApiService.getSavedUser();
    if (user != null && mounted) {
      final uid = user['id']?.toString() ?? '';
      setState(() {
        _myUserId = uid;
        _myUserName = user['name']?.toString() ?? user['nickname']?.toString() ?? 'You';
        _myUserAvatar = user['avatar_url']?.toString() ?? user['avatar']?.toString() ?? '';
        _isHost = (_currentRoom.hostId == uid) || (_currentRoom.seats.isNotEmpty && _currentRoom.seats.first.userId == uid);

        // Check if user is currently seated
        final mySeat = _seats.indexWhere((s) => s.userId == uid);
        if (mySeat != -1) {
          _amIOnSeat = true;
          _mySeatIndex = mySeat;
        }
      });
    }
  }

  Future<void> _joinRoomOnServer() async {
    await PartyRoomApiService.joinRoom(widget.room.id);
  }

  Future<void> _loadMessages() async {
    final msgs = await PartyRoomApiService.getMessages(widget.room.id);
    if (mounted && msgs.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
      });
      _scrollChatToBottom();
    } else if (mounted && _messages.isEmpty) {
      // Default welcome message
      setState(() {
        _messages.add(PartyRoomMessage(
          id: 1,
          roomId: widget.room.id,
          type: 'system',
          message: widget.room.announcement ?? '📢 Welcome to ${widget.room.title}! Please be respectful to everyone.',
          createdAt: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _refreshRoomState() async {
    final updated = await PartyRoomApiService.getPartyRoomDetails(widget.room.id);
    if (updated != null && mounted) {
      setState(() {
        _currentRoom = updated;
        _seats = List.from(updated.seats);
        while (_seats.length < 10) {
          _seats.add(RoomSeat(seatIndex: _seats.length));
        }

        if (_myUserId != null) {
          final mySeat = _seats.indexWhere((s) => s.userId == _myUserId);
          if (mySeat != -1) {
            _amIOnSeat = true;
            _mySeatIndex = mySeat;
          } else if (!_isHost) {
            _amIOnSeat = false;
            _mySeatIndex = null;
          }
        }
      });
    }
  }

  Future<void> _runMinuteBilling() async {
    // Only bill if user is seated as a guest (host receives coins)
    if (_amIOnSeat && !_isHost) {
      final res = await PartyRoomApiService.deductInterval(widget.room.id, minutes: 1);
      if (res['insufficient_balance'] == true || res['evicted_from_seat'] == true) {
        if (mounted) {
          setState(() {
            if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
              _seats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
            }
            _amIOnSeat = false;
            _mySeatIndex = null;
            _messages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '⚠️ Your coin balance is low (100 coins/min). You have been moved to the audience.',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Low balance! Moved from stage to audience. Top up gems to speak again.'),
              backgroundColor: const Color(0xFFFF1744),
              action: SnackBarAction(
                label: 'Top Up',
                textColor: Colors.white,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WalletScreen()),
                ),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    LiveGiftReverbService().unsubscribeFromLiveRoom(widget.room.id);
    _pollingTimer?.cancel();
    _billingTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();

    if (_isHost) {
      PartyRoomApiService.endRoom(widget.room.id);
    } else {
      PartyRoomApiService.leaveRoom(widget.room.id);
    }

    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    final sentMsg = await PartyRoomApiService.sendMessage(widget.room.id, message: text);

    if (mounted) {
      setState(() {
        _messages.add(
          sentMsg ??
              PartyRoomMessage(
                id: DateTime.now().millisecondsSinceEpoch,
                roomId: widget.room.id,
                type: 'text',
                message: text,
                senderName: _myUserName ?? 'You',
                senderAvatar: _myUserAvatar,
                createdAt: DateTime.now(),
              ),
        );
      });
      _scrollChatToBottom();
    }
  }

  Future<void> _pickAndSendPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (file != null) {
        final sent = await PartyRoomApiService.sendMessage(
          widget.room.id,
          imageFile: File(file.path),
        );

        if (mounted && sent != null) {
          setState(() {
            _messages.add(sent);
          });
          _scrollChatToBottom();
        }
      }
    } catch (_) {}
  }

  void _handleSeatTap(int index) async {
    final seat = _seats[index];

    if (seat.isEmpty) {
      // Taking an open seat
      final res = await PartyRoomApiService.takeSeat(widget.room.id, seatIndex: index);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
              _seats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
            }
            _seats[index] = RoomSeat(
              seatIndex: index,
              userId: _myUserId ?? '1',
              userName: _myUserName ?? 'You',
              userAvatar: _myUserAvatar,
              isSpeaking: true,
              isMuted: _isMyMicMuted,
              status: 'occupied',
              role: index == 0 ? 'host' : 'guest',
            );
            _amIOnSeat = true;
            _mySeatIndex = index;
            _messages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '🎤 You took Seat ${index + 1}!',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Unable to take seat')),
          );
        }
      }
    } else {
      _showUserSeatOptions(seat);
    }
  }

  void _showUserSeatOptions(RoomSeat seat) {
    final isSelf = seat.userId == _myUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B152E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF2E1F4A),
              child: ClipOval(
                child: (seat.userAvatar != null && seat.userAvatar!.isNotEmpty)
                    ? CachedImageLoader(imageUrl: seat.userAvatar!, fit: BoxFit.cover)
                    : Text(
                        (seat.userName?.isNotEmpty == true) ? seat.userName![0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  seat.userName ?? 'Guest',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (seat.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 16),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Seat ${seat.seatIndex + 1} ${seat.isHost ? "• Host 👑" : "• Speaker 🎙️"}',
              style: const TextStyle(color: AppColors.gemYellow, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(Icons.card_giftcard_rounded, 'Send Gift', () {
                  Navigator.pop(context);
                  _openGiftPicker(seat.userId ?? widget.room.hostId);
                }),
                if (isSelf)
                  _buildActionChip(Icons.logout_rounded, 'Leave Seat', () async {
                    Navigator.pop(context);
                    await PartyRoomApiService.leaveSeat(widget.room.id);
                    if (mounted) {
                      setState(() {
                        _seats[seat.seatIndex] = RoomSeat(seatIndex: seat.seatIndex);
                        _amIOnSeat = false;
                        _mySeatIndex = null;
                        _messages.add(PartyRoomMessage(
                          id: DateTime.now().millisecondsSinceEpoch,
                          roomId: widget.room.id,
                          type: 'system',
                          message: '👋 You stepped down from Seat ${seat.seatIndex + 1}',
                          createdAt: DateTime.now(),
                        ));
                      });
                      _scrollChatToBottom();
                    }
                  })
                else if (_isHost)
                  _buildActionChip(Icons.person_remove_rounded, 'Kick Seat', () async {
                    Navigator.pop(context);
                    await PartyRoomApiService.kickSeat(widget.room.id, seatIndex: seat.seatIndex, userId: seat.userId);
                    if (mounted) {
                      setState(() {
                        _seats[seat.seatIndex] = RoomSeat(seatIndex: seat.seatIndex);
                        _messages.add(PartyRoomMessage(
                          id: DateTime.now().millisecondsSinceEpoch,
                          roomId: widget.room.id,
                          type: 'system',
                          message: '🚫 Host removed ${seat.userName} from Seat ${seat.seatIndex + 1}',
                          createdAt: DateTime.now(),
                        ));
                      });
                      _scrollChatToBottom();
                    }
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

  void _showInviteModal() {
    // Find first available empty seat
    final emptyIndex = _seats.indexWhere((s) => s.isEmpty);
    final targetSeat = emptyIndex != -1 ? emptyIndex : 1;

    InviteGuestsModal.show(
      context,
      roomId: widget.room.id,
      targetSeatIndex: targetSeat,
      onInvited: (invitee) {
        if (mounted) {
          setState(() {
            _messages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '🎉 Invited ${invitee.name} to Seat ${targetSeat + 1}!',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();
        }
      },
    );
  }

  void _openGiftPicker([dynamic receiverId]) {
    final targetId = receiverId ?? widget.room.hostId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerModal(
        streamId: widget.room.id,
        receiverId: targetId.toString(),
        onGiftSelected: (gift) async {
          final res = await PartyRoomApiService.sendGift(
            widget.room.id,
            giftId: gift.giftId > 0 ? gift.giftId : (int.tryParse(gift.id) ?? 1),
            receiverId: targetId,
            count: 1,
          );

          if (!mounted) return;
          if (res['insufficient_balance'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Insufficient gems balance! Please top up to send gifts.'),
                backgroundColor: const Color(0xFFFF1744),
                action: SnackBarAction(
                  label: 'Recharge',
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WalletScreen()),
                      );
                    }
                  },
                ),
              ),
            );
            return;
          }

          final localEvent = LiveGiftEvent(
            streamId: widget.room.id,
            senderId: int.tryParse(_myUserId ?? '0') ?? 0,
            senderName: _myUserName ?? 'You',
            senderAvatar: _myUserAvatar ?? '',
            giftId: gift.giftId > 0 ? gift.giftId : (int.tryParse(gift.id) ?? 1),
            giftName: gift.name,
            iconUrl: gift.imageUrl,
            fileUrl: gift.animationUrl ?? gift.imageUrl,
            coinsSpent: gift.coins,
            format: gift.animationType,
            displayType: 'fullscreen',
          );

          if (mounted) {
            (_giftOverlayKey.currentState as dynamic)?.playGift(localEvent);
            setState(() {
              _messages.add(PartyRoomMessage(
                id: DateTime.now().millisecondsSinceEpoch,
                roomId: widget.room.id,
                type: 'gift',
                message: '🎁 You sent ${gift.name} (💎 ${gift.coins}) to party room!',
                createdAt: DateTime.now(),
              ));
            });
            _scrollChatToBottom();
          }
        },
      ),
    );
  }

  void _toggleMic() async {
    final nextState = !_isMyMicMuted;
    setState(() {
      _isMyMicMuted = nextState;
      if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
        _seats[_mySeatIndex!] = _seats[_mySeatIndex!].copyWith(isMuted: nextState);
      }
    });
    await PartyRoomApiService.toggleMic(widget.room.id, isMuted: nextState);
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
                              backgroundColor: const Color(0xFF381F4B),
                              child: ClipOval(
                                child: _currentRoom.hostAvatar.isNotEmpty
                                    ? CachedImageLoader(
                                        imageUrl: _currentRoom.hostAvatar,
                                        fit: BoxFit.cover,
                                      )
                                    : Text(
                                        _currentRoom.hostName.isNotEmpty ? _currentRoom.hostName[0].toUpperCase() : 'H',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentRoom.hostName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_currentRoom.hostIsVerified) ...[
                                      const SizedBox(width: 3),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 12),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.people_rounded, color: AppColors.gemYellow, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_currentRoom.audienceCount} online',
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
                            itemCount: _currentRoom.audienceAvatars.length,
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
                                  imageUrl: _currentRoom.audienceAvatars[index],
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
                        onPressed: () {
                          if (_isHost) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1B152E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('End Party Room?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: const Text('Ending the room will disconnect all guests and audience members.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('End Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
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
                          _currentRoom.title,
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
                          _currentRoom.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 2. 10-Seat Stage Grid (2 rows x 5 seats)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1735).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        // Row 1 (Seats 1 - 5)
                        Row(
                          children: List.generate(
                            5,
                            (index) => Expanded(
                              child: RoomSeatWidget(
                                seat: _seats[index],
                                onTap: () => _handleSeatTap(index),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 2 (Seats 6 - 10)
                        Row(
                          children: List.generate(
                            5,
                            (index) => Expanded(
                              child: RoomSeatWidget(
                                seat: _seats[index + 5],
                                onTap: () => _handleSeatTap(index + 5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Live Chat Messages Stream
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isNotice = msg.type == 'system' || msg.message.startsWith('📢') || msg.message.startsWith('🎉') || msg.message.startsWith('⚠️');
                        final isGift = msg.type == 'gift' || msg.message.startsWith('🎁') || msg.message.startsWith('🌹');
                        final isImage = msg.type == 'image' || (msg.imageUrl != null && msg.imageUrl!.isNotEmpty);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isNotice
                                ? AppColors.neonPurple.withValues(alpha: 0.22)
                                : (isGift
                                    ? AppColors.warmOrange.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.45)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isGift
                                  ? AppColors.gemYellow.withValues(alpha: 0.3)
                                  : (isNotice ? AppColors.neonPurple.withValues(alpha: 0.3) : Colors.transparent),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sender name (if text/image)
                              if (!isNotice && !isGift && msg.senderName != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.senderName!,
                                      style: const TextStyle(
                                        color: AppColors.gemYellow,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lv.${msg.senderLevel}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                                    ),
                                  ],
                                ),
                              if (msg.message.isNotEmpty)
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    color: isGift ? AppColors.gemYellow : Colors.white,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              // Shared Photo / Image
                              if (isImage && msg.imageUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
                                      child: CachedImageLoader(
                                        imageUrl: msg.imageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 4. Bottom Party Room Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF130D21),
                    border: Border(
                      top: BorderSide(color: AppColors.cardBorder, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Photo Upload Button
                      GestureDetector(
                        onTap: _pickAndSendPhoto,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardDarkElevated,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(Icons.photo_camera_rounded, color: AppColors.neonPink, size: 18),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Chat Input Field
                      Expanded(
                        child: Container(
                          height: 38,
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
                              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 11),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 10),
                            ),
                            onSubmitted: (_) => _sendChatMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Send Chat Button
                      GestureDetector(
                        onTap: _sendChatMessage,
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
                      const SizedBox(width: 6),

                      // Mic Mute Toggle
                      GestureDetector(
                        onTap: _toggleMic,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMyMicMuted ? const Color(0xFFFF1744) : AppColors.cardDarkElevated,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Icon(
                            _isMyMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Host Add/Invite Guest Button
                      GestureDetector(
                        onTap: _showInviteModal,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.orangeGradient,
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Send Gift Button
                      GestureDetector(
                        onTap: () => _openGiftPicker(),
                        child: Container(
                          width: 38,
                          height: 38,
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
                            child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Real-Time Live Gift Animation & Sender VIP Banner Overlay
          LiveGiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }
}
