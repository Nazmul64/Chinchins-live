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
import '../widgets/invite_guests_modal.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../auth/services/auth_api_service.dart';
import '../../wallet/screens/wallet_screen.dart';

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
  final GlobalKey<State<LiveGiftAnimationOverlay>> _giftOverlayKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  late GroupPartyRoom _currentRoom;
  late List<RoomSeat> _videoSeats;
  final List<PartyRoomMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isMyMicMuted = false;
  bool _isMyCameraOff = false;
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
    _videoSeats = List.from(widget.room.seats);

    while (_videoSeats.length < 6) {
      _videoSeats.add(RoomSeat(seatIndex: _videoSeats.length));
    }

    _initUserData();
    _joinRoom();
    _loadMessages();

    // 1. Subscribe to Live Gift Channel
    LiveGiftReverbService().subscribeToLiveRoom(
      streamId: widget.room.id,
      onGiftReceived: (giftEvent) {
        if (mounted) {
          (_giftOverlayKey.currentState as dynamic)?.playGift(giftEvent);
          setState(() {
            _chatMessages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'gift',
              message: '🎁 ${giftEvent.senderName} sent ${giftEvent.giftName}! (💎 ${giftEvent.coinsSpent})',
              createdAt: DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
      },
    );

    // 2. Poll room state every 6 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshRoom();
    });

    // 3. 50/50 Revenue Billing Timer
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

        final mySeat = _videoSeats.indexWhere((s) => s.userId == uid);
        if (mySeat != -1) {
          _amIOnSeat = true;
          _mySeatIndex = mySeat;
        }
      });
    }
  }

  Future<void> _joinRoom() async {
    await PartyRoomApiService.joinRoom(widget.room.id);
  }

  Future<void> _loadMessages() async {
    final msgs = await PartyRoomApiService.getMessages(widget.room.id);
    if (mounted && msgs.isNotEmpty) {
      setState(() {
        _chatMessages.clear();
        _chatMessages.addAll(msgs);
      });
      _scrollToBottom();
    } else if (mounted && _chatMessages.isEmpty) {
      setState(() {
        _chatMessages.add(PartyRoomMessage(
          id: 1,
          roomId: widget.room.id,
          type: 'system',
          message: widget.room.announcement ?? '📢 Welcome to ${widget.room.title}! Live video party is on!',
          createdAt: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _refreshRoom() async {
    final updated = await PartyRoomApiService.getPartyRoomDetails(widget.room.id);
    if (updated != null && mounted) {
      setState(() {
        _currentRoom = updated;
        _videoSeats = List.from(updated.seats);
        while (_videoSeats.length < 6) {
          _videoSeats.add(RoomSeat(seatIndex: _videoSeats.length));
        }

        if (_myUserId != null) {
          final mySeat = _videoSeats.indexWhere((s) => s.userId == _myUserId);
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
    if (_amIOnSeat && !_isHost) {
      final res = await PartyRoomApiService.deductInterval(widget.room.id, minutes: 1);
      if (res['insufficient_balance'] == true || res['evicted_from_seat'] == true) {
        if (mounted) {
          setState(() {
            if (_mySeatIndex != null && _mySeatIndex! < _videoSeats.length) {
              _videoSeats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
            }
            _amIOnSeat = false;
            _mySeatIndex = null;
            _chatMessages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '⚠️ Your coin balance is low (100 coins/min). You have been moved to audience.',
              createdAt: DateTime.now(),
            ));
          });
          _scrollToBottom();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Low balance! Moved to audience. Please top up gems.'),
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

  void _scrollToBottom() {
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

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    final sent = await PartyRoomApiService.sendMessage(widget.room.id, message: text);

    if (mounted) {
      setState(() {
        _chatMessages.add(
          sent ??
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
      _scrollToBottom();
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
            _chatMessages.add(sent);
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  void _handleSeatTap(int index) async {
    final seat = _videoSeats[index];

    if (seat.isEmpty) {
      final res = await PartyRoomApiService.takeSeat(widget.room.id, seatIndex: index);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            if (_mySeatIndex != null && _mySeatIndex! < _videoSeats.length) {
              _videoSeats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
            }
            _videoSeats[index] = RoomSeat(
              seatIndex: index,
              userId: _myUserId ?? '1',
              userName: _myUserName ?? 'You',
              userAvatar: _myUserAvatar,
              isSpeaking: true,
              isMuted: _isMyMicMuted,
              isVideoMuted: _isMyCameraOff,
              status: 'occupied',
              role: index == 0 ? 'host' : 'guest',
            );
            _amIOnSeat = true;
            _mySeatIndex = index;
            _chatMessages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '📹 You joined video seat ${index + 1}!',
              createdAt: DateTime.now(),
            ));
          });
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Unable to connect to video seat')),
          );
        }
      }
    } else {
      _showVideoSeatOptions(seat);
    }
  }

  void _showVideoSeatOptions(RoomSeat seat) {
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
                  seat.userName ?? 'Video Guest',
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
              'Video Seat ${seat.seatIndex + 1} ${seat.isHost ? "• Host 👑" : "• Co-Host 📹"}',
              style: const TextStyle(color: AppColors.gemYellow, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(Icons.card_giftcard_rounded, 'Send Gift', () {
                  Navigator.pop(context);
                  _openGiftModal(seat.userId ?? widget.room.hostId);
                }),
                if (isSelf)
                  _buildActionChip(Icons.logout_rounded, 'Leave Grid', () async {
                    Navigator.pop(context);
                    await PartyRoomApiService.leaveSeat(widget.room.id);
                    if (mounted) {
                      setState(() {
                        _videoSeats[seat.seatIndex] = RoomSeat(seatIndex: seat.seatIndex);
                        _amIOnSeat = false;
                        _mySeatIndex = null;
                        _chatMessages.add(PartyRoomMessage(
                          id: DateTime.now().millisecondsSinceEpoch,
                          roomId: widget.room.id,
                          type: 'system',
                          message: '👋 You stepped down from video grid',
                          createdAt: DateTime.now(),
                        ));
                      });
                      _scrollToBottom();
                    }
                  })
                else if (_isHost)
                  _buildActionChip(Icons.person_remove_rounded, 'Remove', () async {
                    Navigator.pop(context);
                    await PartyRoomApiService.kickSeat(widget.room.id, seatIndex: seat.seatIndex, userId: seat.userId);
                    if (mounted) {
                      setState(() {
                        _videoSeats[seat.seatIndex] = RoomSeat(seatIndex: seat.seatIndex);
                        _chatMessages.add(PartyRoomMessage(
                          id: DateTime.now().millisecondsSinceEpoch,
                          roomId: widget.room.id,
                          type: 'system',
                          message: '🚫 Host removed ${seat.userName} from video seat',
                          createdAt: DateTime.now(),
                        ));
                      });
                      _scrollToBottom();
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
    final emptyIndex = _videoSeats.indexWhere((s) => s.isEmpty);
    final targetSeat = emptyIndex != -1 ? emptyIndex : 1;

    InviteGuestsModal.show(
      context,
      roomId: widget.room.id,
      targetSeatIndex: targetSeat,
      onInvited: (invitee) {
        if (mounted) {
          setState(() {
            _chatMessages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '📹 Invited ${invitee.name} to Video Seat ${targetSeat + 1}!',
              createdAt: DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
      },
    );
  }

  void _openGiftModal([dynamic receiverId]) {
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
              _chatMessages.add(PartyRoomMessage(
                id: DateTime.now().millisecondsSinceEpoch,
                roomId: widget.room.id,
                type: 'gift',
                message: '🎁 You sent ${gift.name} (💎 ${gift.coins}) to party room!',
                createdAt: DateTime.now(),
              ));
            });
            _scrollToBottom();
          }
        },
      ),
    );
  }

  void _toggleMic() async {
    final next = !_isMyMicMuted;
    setState(() {
      _isMyMicMuted = next;
      if (_mySeatIndex != null && _mySeatIndex! < _videoSeats.length) {
        _videoSeats[_mySeatIndex!] = _videoSeats[_mySeatIndex!].copyWith(isMuted: next);
      }
    });
    await PartyRoomApiService.toggleMic(widget.room.id, isMuted: next);
  }

  void _toggleCamera() async {
    final next = !_isMyCameraOff;
    setState(() {
      _isMyCameraOff = next;
      if (_mySeatIndex != null && _mySeatIndex! < _videoSeats.length) {
        _videoSeats[_mySeatIndex!] = _videoSeats[_mySeatIndex!].copyWith(isVideoMuted: next);
      }
    });
    await PartyRoomApiService.toggleVideo(widget.room.id, isVideoMuted: next);
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
                              backgroundColor: const Color(0xFF381F4B),
                              child: ClipOval(
                                child: _currentRoom.hostAvatar.isNotEmpty
                                    ? CachedImageLoader(
                                        imageUrl: _currentRoom.hostAvatar,
                                        fit: BoxFit.cover,
                                      )
                                    : Text(
                                        _currentRoom.hostName.isNotEmpty ? _currentRoom.hostName[0].toUpperCase() : 'H',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _currentRoom.hostName,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    if (_currentRoom.hostIsVerified) ...[
                                      const SizedBox(width: 2),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 10),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${_currentRoom.audienceCount} online',
                                  style: const TextStyle(color: AppColors.onlineGreen, fontSize: 9),
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
                          height: 30,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _currentRoom.audienceAvatars.length,
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
                                  imageUrl: _currentRoom.audienceAvatars[index],
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
                        onPressed: () {
                          if (_isHost) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1B152E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('End Video Party?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: const Text('Ending will close video feeds for all connected guests.', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                                    child: const Text('End Party', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                // 2. Multi-Guest Dynamic Video Matrix Grid (supports up to 6-10 feeds)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: _videoSeats.length > 6 ? 6 : _videoSeats.length,
                      itemBuilder: (context, index) {
                        final seat = _videoSeats[index];
                        final displayIndex = index + 1;

                        return GestureDetector(
                          onTap: () => _handleSeatTap(index),
                          child: Container(
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
                                  ? Container(
                                      color: const Color(0xFF171324),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.videocam_rounded, color: AppColors.neonPink, size: 28),
                                          const SizedBox(height: 4),
                                          Text(
                                            '+ Video Seat $displayIndex',
                                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (seat.isVideoMuted)
                                          Container(
                                            color: const Color(0xFF110D1F),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 26),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Camera Off',
                                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else if (seat.userAvatar != null && seat.userAvatar!.isNotEmpty)
                                          CachedImageLoader(
                                            imageUrl: seat.userAvatar!,
                                            fit: BoxFit.cover,
                                          )
                                        else
                                          Container(
                                            color: const Color(0xFF2C194D),
                                            child: Center(
                                              child: Text(
                                                seat.userName?.isNotEmpty == true ? seat.userName![0].toUpperCase() : '$displayIndex',
                                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),

                                        // Dark gradient
                                        Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.transparent, Color(0xBB000000)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),

                                        // Bottom Bar
                                        Positioned(
                                          bottom: 4,
                                          left: 6,
                                          right: 6,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  seat.userName ?? 'Guest',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (seat.isHost)
                                                const Icon(Icons.military_tech_rounded, color: AppColors.gemYellow, size: 14)
                                              else if (seat.isMuted)
                                                const Icon(Icons.mic_off_rounded, color: Color(0xFFFF1744), size: 12)
                                              else
                                                const Icon(Icons.videocam_rounded, color: AppColors.onlineGreen, size: 12),
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
                const SizedBox(height: 4),

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
                        final isGift = msg.type == 'gift' || msg.message.startsWith('🎁') || msg.message.startsWith('🌹');
                        final isNotice = msg.type == 'system' || msg.message.startsWith('📢') || msg.message.startsWith('⚠️');
                        final isImage = msg.type == 'image' || (msg.imageUrl != null && msg.imageUrl!.isNotEmpty);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isGift
                                ? AppColors.warmOrange.withValues(alpha: 0.25)
                                : (isNotice ? AppColors.neonPurple.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.45)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isGift
                                  ? AppColors.gemYellow.withValues(alpha: 0.3)
                                  : (isNotice ? AppColors.neonPurple.withValues(alpha: 0.3) : Colors.transparent),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isNotice && !isGift && msg.senderName != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.senderName!,
                                      style: const TextStyle(
                                        color: AppColors.gemYellow,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lv.${msg.senderLevel}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 8.5),
                                    ),
                                  ],
                                ),
                              if (msg.message.isNotEmpty)
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    color: isGift ? AppColors.gemYellow : Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              if (isImage && msg.imageUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 140, maxWidth: 180),
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

                // 4. Bottom Controls Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF120E1F),
                    border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
                  ),
                  child: Row(
                    children: [
                      // Photo Camera Button
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
                          child: const Icon(Icons.photo_camera_rounded, color: AppColors.neonPink, size: 16),
                        ),
                      ),
                      const SizedBox(width: 6),

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
                      const SizedBox(width: 6),

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
                      const SizedBox(width: 6),

                      // Mic Toggle
                      GestureDetector(
                        onTap: _toggleMic,
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
                      const SizedBox(width: 6),

                      // Camera Toggle
                      GestureDetector(
                        onTap: _toggleCamera,
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
                      const SizedBox(width: 6),

                      // Add Guest / Invite Button
                      GestureDetector(
                        onTap: _showInviteModal,
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
                      const SizedBox(width: 6),

                      // Gift Button
                      GestureDetector(
                        onTap: () => _openGiftModal(),
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

          // Real-Time Live Gift Animation & Sender VIP Banner Overlay
          LiveGiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }
}
