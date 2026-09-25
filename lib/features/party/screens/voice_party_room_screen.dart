import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/group_room.dart';
import '../../../core/models/live_gift_event.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/services/live_gift_reverb_service.dart';
import '../../../core/widgets/live_gift_animation_overlay.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../services/livekit_service.dart';
import '../widgets/room_seat_widget.dart';
import '../widgets/seat_requests_sheet.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../auth/services/auth_api_service.dart';
import '../../profile/services/level_bases_api_service.dart';
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

class _VoicePartyRoomScreenState extends State<VoicePartyRoomScreen>
    with TickerProviderStateMixin {
  final GlobalKey<State<LiveGiftAnimationOverlay>> _giftOverlayKey = GlobalKey();
  final LiveKitService _liveKitService = LiveKitService();
  Room? _room;
  EventsListener<RoomEvent>? _liveKitListener;

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
  int _myLevel = 1;
  bool _hasRequestedSeat = false;
  int _pendingRequestsCount = 0;

  // Active Speaker & Top Gifter tracker
  String? _activeSpeakerName;
  String _topGifterName = 'Arif';

  Timer? _pollingTimer;
  Timer? _billingTimer;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _seats = List.from(widget.room.seats);

    // Ensure 8 seats exist for the 2x4 layout
    while (_seats.length < 8) {
      _seats.add(RoomSeat(seatIndex: _seats.length));
    }

    // Ensure Host is on Seat 0 (Seat #1)
    if (_seats.isNotEmpty && _seats[0].isEmpty) {
      _seats[0] = RoomSeat(
        seatIndex: 0,
        userId: widget.room.hostId,
        userName: widget.room.hostName.isNotEmpty ? widget.room.hostName : 'Host',
        userAvatar: widget.room.hostAvatar,
        isHost: true,
        status: 'occupied',
        role: 'host',
      );
    }


    _initUserData();
    _joinRoomOnServer();
    _loadMessages();
    _checkPendingRequests();

    // 1. Subscribe to Live Gifts & Reverb WebSockets
    LiveGiftReverbService().subscribeToLiveRoom(
      streamId: widget.room.id,
      onGiftReceived: (giftEvent) {
        if (mounted) {
          (_giftOverlayKey.currentState as dynamic)?.playGift(giftEvent);
          setState(() {
            _topGifterName = giftEvent.senderName;
          });
          _addMessageSafely(PartyRoomMessage(
            id: DateTime.now().millisecondsSinceEpoch,
            roomId: widget.room.id,
            type: 'gift',
            message: '🎁 ${giftEvent.senderName} sent ${giftEvent.giftName}! (💎 ${giftEvent.coinsSpent})',
            senderName: giftEvent.senderName,
            senderAvatar: giftEvent.senderAvatar,
            createdAt: DateTime.now(),
          ));
        }
      },
      onMessageReceived: (message) {
        _addMessageSafely(message);
      },
      onSeatUpdated: (seatData) {
        if (mounted) {
          _handleReverbSeatUpdate(seatData);
        }
      },
      onSeatRequested: (reqData) {
        if (mounted && _isHost) {
          _handleIncomingSeatRequest(reqData);
        }
      },
    );

    // 2. Poll room updates every 5 seconds as fallback
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshRoomState();
      if (_isHost) _checkPendingRequests();
    });

    // 3. 50/50 Minute Billing Timer (Every 60 seconds)
    _billingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _runMinuteBilling();
    });
  }

  void _addMessageSafely(PartyRoomMessage newMessage) {
    if (!mounted) return;
    final isExist = _messages.any((msg) =>
        msg.id == newMessage.id ||
        (msg.message == newMessage.message &&
            msg.senderName == newMessage.senderName &&
            DateTime.now().difference(msg.createdAt).inSeconds.abs() < 3));

    if (!isExist) {
      setState(() {
        _messages.add(newMessage);
      });
      _scrollChatToBottom();
    }
  }

  void _handleIncomingSeatRequest(Map<String, dynamic> reqData) {
    _checkPendingRequests();
    if (!mounted || !_isHost) return;

    final reqId = reqData['request_id'] ?? reqData['id'] ?? reqData['invitation_id'];
    final uName = reqData['user_name'] ?? reqData['name'] ?? (reqData['user'] is Map ? (reqData['user']['display_name'] ?? reqData['user']['name']) : 'একজন দর্শক');
    final sIdx = reqData['seat_index'] ?? 2;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('সিট রিকোয়েস্ট 🎙️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$uName সিট $sIdx-এ বসতে চান।', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (reqId != null) {
                await PartyRoomApiService.respondSeatRequest(widget.room.id, reqId, action: 'reject');
                _checkPendingRequests();
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (reqId != null) {
                final res = await PartyRoomApiService.respondSeatRequest(widget.room.id, reqId, action: 'accept');
                if (res['success'] == true) {
                  _refreshRoomState();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$uName-এর রিকোয়েস্ট গ্রহণ করা হয়েছে')),
                    );
                  }
                }
                _checkPendingRequests();
              }
            },
            child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _initUserData() async {
    final user = await AuthApiService.getSavedUser();
    if (user != null && mounted) {
      final uid = user['id']?.toString() ?? '';
      setState(() {
        _myUserId = uid;
        _myUserName = user['name']?.toString() ?? user['nickname']?.toString() ?? 'You';
        _myUserAvatar = user['avatar_url']?.toString() ?? user['avatar']?.toString() ?? '';
        _myLevel = user['level'] is int ? user['level'] as int : (int.tryParse(user['level']?.toString() ?? '1') ?? 1);
        _isHost = (_currentRoom.hostId == uid) ||
            (_currentRoom.seats.isNotEmpty && _currentRoom.seats.first.userId == uid);

        // Check if user is currently seated
        final mySeat = _seats.indexWhere((s) => s.userId == uid);
        if (mySeat != -1) {
          _amIOnSeat = true;
          _mySeatIndex = mySeat;
        } else if (_isHost) {
          _amIOnSeat = true;
          _mySeatIndex = 0;
        }
      });
    }
    _initLiveKitAudio();
  }

  Future<void> _initLiveKitAudio() async {
    try {
      await Permission.microphone.request();

      // Ensure audio outputs through phone loudspeaker
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('[VoiceParty] Speakerphone error: $e');
      }

      final isSpeaker = _amIOnSeat || _isHost;
      String token = _currentRoom.rtc?.livekitToken ??
          _currentRoom.rtc?.token ??
          widget.room.rtc?.livekitToken ??
          widget.room.rtc?.token ??
          '';
      String livekitUrl = _currentRoom.rtc?.livekitUrl ??
          widget.room.rtc?.livekitUrl ??
          'wss://chinchins.live/livekit';

      if (token.isEmpty) {
        final fresh = await PartyRoomApiService.getPartyRoomDetails(widget.room.id);
        if (fresh != null) {
          if (mounted) setState(() => _currentRoom = fresh);
          token = fresh.rtc?.livekitToken ?? fresh.rtc?.token ?? '';
          livekitUrl = fresh.rtc?.livekitUrl ?? livekitUrl;
        }
      }

      _room = await _liveKitService.connectToRoom(
        token: token.isNotEmpty ? token : 'party_voice_${widget.room.id}',
        isHost: isSpeaker,
        isAudioOnly: true,
        customServerUrl: livekitUrl,
      );

      if (_room != null && mounted) {
        _liveKitListener = _room!.createListener();
        _liveKitListener!
          ..on<ParticipantConnectedEvent>((_) {
            if (mounted) setState(() {});
          })
          ..on<ParticipantDisconnectedEvent>((_) {
            if (mounted) setState(() {});
          })
          ..on<TrackMutedEvent>((_) {
            if (mounted) setState(() {});
          })
          ..on<TrackUnmutedEvent>((_) {
            if (mounted) setState(() {});
          })
          ..on<ActiveSpeakersChangedEvent>((event) {
            if (mounted) _handleLiveKitSpeakers(event.speakers);
          });

        // Default mic unmuted when seated/host
        if (isSpeaker) {
          await _room!.localParticipant?.setMicrophoneEnabled(true);
          setState(() => _isMyMicMuted = false);
        }

        try {
          await Hardware.instance.setSpeakerphoneOn(true);
        } catch (_) {}

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('[VoiceParty] LiveKit connect error: $e');
    }
  }

  void _handleLiveKitSpeakers(List<Participant> speakers) {
    final speakingIdentities = speakers.map((p) => p.identity).toSet();
    bool changed = false;
    final updatedSeats = List<RoomSeat>.from(_seats);
    String? currentSpeaker;

    for (int i = 0; i < updatedSeats.length; i++) {
      final seat = updatedSeats[i];
      if (seat.isEmpty) continue;

      final isUserSpeaking = speakingIdentities.contains(seat.userId) ||
          speakingIdentities.contains(seat.accountId) ||
          speakingIdentities.contains(seat.userName) ||
          (seat.userId == _myUserId && _room?.localParticipant?.isSpeaking == true);

      if (isUserSpeaking && currentSpeaker == null) {
        currentSpeaker = seat.userName;
      }

      if (seat.isSpeaking != isUserSpeaking) {
        updatedSeats[i] = seat.copyWith(isSpeaking: isUserSpeaking);
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {
        _seats = updatedSeats;
        _activeSpeakerName = currentSpeaker;
      });

      if (_amIOnSeat) {
        final myIsSpeaking = _room?.localParticipant?.isSpeaking == true;
        PartyRoomApiService.notifySpeakingState(widget.room.id, isSpeaking: myIsSpeaking);
      }
    }
  }

  void _handleReverbSeatUpdate(Map<String, dynamic> data) {
    final rawIdx = data['seat_index'] != null ? int.tryParse(data['seat_index'].toString()) : null;
    int seatIdx = 0;
    if (rawIdx != null) {
      seatIdx = rawIdx > 0 ? (rawIdx - 1) : rawIdx;
    }
    if (seatIdx < 0 || seatIdx >= _seats.length) return;

    final userData = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : (data['user_profile'] is Map<String, dynamic> ? data['user_profile'] as Map<String, dynamic> : null);

    final userId = data['user_id']?.toString() ?? userData?['id']?.toString();
    final userName = userData?['name']?.toString() ?? userData?['nickname']?.toString() ?? data['user_name']?.toString();
    final userAvatar = userData?['avatar_url']?.toString() ?? userData?['avatar']?.toString() ?? data['avatar_url']?.toString();
    final isSpeaking = data['is_speaking'] == true;
    final isMuted = data['is_muted'] == true;
    final isKicked = data['action'] == 'kicked' || data['status'] == 'empty' || (userId == null || userId == '0' || userId.isEmpty);

    setState(() {
      if (isKicked) {
        _seats[seatIdx] = RoomSeat(seatIndex: seatIdx);
        if (userId == _myUserId) {
          _amIOnSeat = false;
          _mySeatIndex = null;
          _room?.localParticipant?.setMicrophoneEnabled(false);
        }
      } else {
        _seats[seatIdx] = _seats[seatIdx].copyWith(
          userId: userId,
          userName: userName ?? _seats[seatIdx].userName,
          userAvatar: userAvatar ?? _seats[seatIdx].userAvatar,
          isSpeaking: isSpeaking,
          isMuted: isMuted,
          status: 'occupied',
          role: seatIdx == 0 ? 'host' : 'guest',
        );
        if (userId == _myUserId) {
          _amIOnSeat = true;
          _mySeatIndex = seatIdx;
          _room?.localParticipant?.setMicrophoneEnabled(!isMuted);
        }
      }
    });
  }

  Future<void> _joinRoomOnServer() async {
    await PartyRoomApiService.joinRoom(widget.room.id);
  }

  Future<void> _checkPendingRequests() async {
    if (!_isHost) return;
    final requests = await PartyRoomApiService.getSeatRequests(widget.room.id);
    if (mounted) {
      setState(() {
        _pendingRequestsCount = requests.length;
      });
    }
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
      setState(() {
        _messages.add(PartyRoomMessage(
          id: 1,
          roomId: widget.room.id,
          type: 'system',
          message: widget.room.announcement ?? '📢 লাইভ ভয়েস রুমে স্বাগতম! সবার সাথে আনন্দের সাথে আড্ডা দিন ✨',
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
        while (_seats.length < 8) {
          _seats.add(RoomSeat(seatIndex: _seats.length));
        }

        if (_seats.isNotEmpty && _seats[0].isEmpty) {
          _seats[0] = RoomSeat(
            seatIndex: 0,
            userId: _currentRoom.hostId,
            userName: _currentRoom.hostName,
            userAvatar: _currentRoom.hostAvatar,
            isHost: true,
            status: 'occupied',
            role: 'host',
          );
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
    if (_amIOnSeat && !_isHost) {
      final res = await PartyRoomApiService.deductInterval(widget.room.id, minutes: 1);
      if (res['insufficient_balance'] == true || res['evicted_from_seat'] == true) {
        if (mounted) {
          await _room?.localParticipant?.setMicrophoneEnabled(false);

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
              message: '⚠️ কয়েন ব্যালেন্স শেষ হওয়ায় আপনাকে স্পিকার স্টেজ থেকে অডিয়েন্সে সরানো হয়েছে।',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('কয়েন শেষ! কথা বলতে রিচার্জ করুন।'),
              backgroundColor: const Color(0xFFFF1744),
              action: SnackBarAction(
                label: 'Recharge',
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

    _liveKitListener?.dispose();
    _liveKitService.disconnect();

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

    // Optimistically add message locally immediately
    final localMsg = PartyRoomMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      roomId: widget.room.id,
      type: 'text',
      message: text,
      senderName: _myUserName ?? 'You',
      senderAvatar: _myUserAvatar,
      senderLevel: _myLevel,
      senderIsVerified: true,
      reactions: const {},
      createdAt: DateTime.now(),
    );

    _addMessageSafely(localMsg);

    await PartyRoomApiService.sendMessage(widget.room.id, message: text);
  }

  void _toggleReaction(int msgIndex, String emoji) {
    setState(() {
      final msg = _messages[msgIndex];
      final currentMap = Map<String, int>.from(msg.reactions);
      final count = currentMap[emoji] ?? 0;
      currentMap[emoji] = count + 1;
      _messages[msgIndex] = msg.copyWith(reactions: currentMap);
    });
  }

  void _showReactionPicker(int msgIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['💜', '😂', '🔥', '❤️', '👏', '🎉'].map((emoji) {
            return InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _toggleReaction(msgIndex, emoji);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleSeatTap(int index) async {
    final seat = _seats[index];

    if (seat.isEmpty) {
      // Direct Take Seat or Request
      final res = await PartyRoomApiService.takeSeat(widget.room.id, seatIndex: index + 1);
      if (mounted) {
        if (res['success'] == true) {
          await _room?.localParticipant?.setMicrophoneEnabled(true);

          setState(() {
            if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
              _seats[_mySeatIndex!] = RoomSeat(seatIndex: _mySeatIndex!);
            }
            _seats[index] = RoomSeat(
              seatIndex: index,
              userId: _myUserId ?? '1',
              userName: _myUserName ?? 'You',
              userAvatar: _myUserAvatar,
              frameSvgUrl: LevelBasesApiService.getFrameUrlForLevel(_myLevel),
              isSpeaking: false,
              isMuted: false,
              status: 'occupied',
              role: index == 0 ? 'host' : 'guest',
            );
            _amIOnSeat = true;
            _isMyMicMuted = false;
            _mySeatIndex = index;
            _messages.add(PartyRoomMessage(
              id: DateTime.now().millisecondsSinceEpoch,
              roomId: widget.room.id,
              type: 'system',
              message: '🎤 You joined Seat ${index + 1}!',
              createdAt: DateTime.now(),
            ));
          });
          _scrollChatToBottom();
        } else {
          _requestToSpeak(seatIndex: index + 1);
        }
      }
    } else {
      _showUserSeatOptions(seat);
    }
  }

  void _requestToSpeak({int? seatIndex}) async {
    if (_hasRequestedSeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আপনার রিকোয়েস্ট ইতিমধ্যে পাঠানো হয়েছে')),
      );
      return;
    }

    final res = await PartyRoomApiService.requestSeat(widget.room.id, seatIndex: seatIndex);
    if (mounted) {
      setState(() => _hasRequestedSeat = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'হোস্টের কাছে কথা বলার রিকোয়েস্ট পাঠানো হয়েছে!'),
          backgroundColor: const Color(0xFF00E5FF),
        ),
      );
    }
  }

  void _showUserSeatOptions(RoomSeat seat) {
    final isSelf = seat.userId == _myUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF1E293B),
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
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600),
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
                    await _room?.localParticipant?.setMicrophoneEnabled(false);

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
                    await PartyRoomApiService.kickSeat(widget.room.id, seatIndex: seat.seatIndex + 1, userId: seat.userId);
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
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  void _openGuestRequestsModal() {
    SeatRequestsBottomSheet.show(
      context,
      roomId: widget.room.id,
      onResponded: (req, accepted) {
        if (accepted) {
          _refreshRoomState();
        }
        _checkPendingRequests();
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
          final messenger = ScaffoldMessenger.of(context);
          final res = await PartyRoomApiService.sendGift(
            widget.room.id,
            giftId: gift.giftId > 0 ? gift.giftId : (int.tryParse(gift.id) ?? 1),
            receiverId: targetId,
            count: 1,
          );

          if (!mounted) return;
          if (res['insufficient_balance'] == true) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Insufficient gems balance! Please top up.'),
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
              _topGifterName = _myUserName ?? 'You';
              _messages.add(PartyRoomMessage(
                id: DateTime.now().millisecondsSinceEpoch,
                roomId: widget.room.id,
                type: 'gift',
                message: '🎁 You sent ${gift.name} (💎 ${gift.coins}) to party room!',
                senderName: _myUserName ?? 'You',
                senderAvatar: _myUserAvatar,
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
    await _room?.localParticipant?.setMicrophoneEnabled(!nextState);
    await PartyRoomApiService.toggleMic(widget.room.id, isMuted: nextState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Stack(
        children: [
          // 1. Subtle Background Glowing Watermark & Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0B0E14),
                    Color(0xFF101726),
                    Color(0xFF090D15),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Glowing "Let's Chat" Watermark on bottom right
          Positioned(
            right: 16,
            bottom: 120,
            child: Opacity(
              opacity: 0.15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('👑', style: TextStyle(fontSize: 22)),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFFA855F7), Color(0xFFEC4899)],
                    ).createShader(bounds),
                    child: const Text(
                      "Let's\nChat",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        height: 0.9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Responsive Column
          SafeArea(
            child: Column(
              children: [
                // TOP APP BAR (Host info, Viewer count, Guest Requests badge, Leave)
                _buildTopAppBar(),

                // 8-SEAT STAGE GRID (2 rows x 4 columns)
                _buildVoiceStageGrid(),

                // ACTIVE SPEAKER & TOP GIFTER TICKER BAR
                _buildSpeakingTickerBar(),

                // UNLIMITED REAL-TIME LIVE CHAT STREAM
                Expanded(
                  child: _buildLiveChatList(),
                ),

                // BOTTOM ACTION BAR (Mic, Gift, Message Input, Send, Raise Hand)
                _buildBottomActionBar(),
              ],
            ),
          ),

          // Real-Time Live Gift Animation & Sender VIP Banner Overlay
          LiveGiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }

  /// 1. Top Bar Widget (Responsive Layout without Share button)
  Widget _buildTopAppBar() {
    final roomHostAvatar = _currentRoom.hostAvatar.isNotEmpty ? _currentRoom.hostAvatar : widget.room.hostAvatar;
    final roomHostName = _currentRoom.hostName.isNotEmpty ? _currentRoom.hostName : (widget.room.hostName.isNotEmpty ? widget.room.hostName : 'Host');
    final activeAudienceCount = _currentRoom.audienceCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),

          // Host Profile Picture (Dynamic database image)
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: roomHostAvatar.isNotEmpty ? NetworkImage(roomHostAvatar) : null,
            child: roomHostAvatar.isEmpty
                ? Text(
                    roomHostName.isNotEmpty ? roomHostName[0].toUpperCase() : 'H',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),

          // Responsive Host Name & Audience Counter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roomHostName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "👁 $activeAudienceCount জন দেখছেন",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                ),
              ],
            ),
          ),

          // Host Guest Requests Badge (If Host)
          if (_isHost && _pendingRequestsCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _openGuestRequestsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1744),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pan_tool_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '$_pendingRequestsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Leave Button
          ElevatedButton(
            onPressed: () => _handleLeaveAction(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("Leave ✌️", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLeaveAction() {
    if (_isHost) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131A26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('রুম শেষ করবেন?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('হোস্ট রুম থেকে বের হলে রুমটি সমাপ্ত হবে।', style: TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
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
  }

  /// 2. Voice Stage Grid (Responsive on Phones & Tablets)
  Widget _buildVoiceStageGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: isTablet
          ? GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 900 ? 8 : 6,
                childAspectRatio: 0.85,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _seats.length,
              itemBuilder: (ctx, index) => RoomSeatWidget(
                seat: _seats[index],
                isTopGifter: false,
                onTap: () => _handleSeatTap(index),
              ),
            )
          : Column(
              children: [
                // Row 1 (Seats 0 to 3)
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: RoomSeatWidget(
                        seat: _seats[index],
                        isTopGifter: false,
                        onTap: () => _handleSeatTap(index),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),

                // Row 2 (Seats 4 to 7)
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: RoomSeatWidget(
                        seat: _seats[index + 4],
                        isTopGifter: false,
                        onTap: () => _handleSeatTap(index + 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 3. Speaking Ticker Bar
  Widget _buildSpeakingTickerBar() {
    final isAnyoneSpeaking = _activeSpeakerName != null && _activeSpeakerName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, color: Color(0xFFA855F7), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isAnyoneSpeaking ? '$_activeSpeakerName এখন বলছেন...' : 'কথা বলতে মাইক আনমিউট করুন 🎙️',
              style: TextStyle(
                color: isAnyoneSpeaking ? const Color(0xFF00FF88) : Colors.white60,
                fontSize: 11.5,
                fontWeight: isAnyoneSpeaking ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_topGifterName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1F40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👑', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    'Top Gifter: $_topGifterName 🎁',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 5. Live Chat Stream List
  Widget _buildLiveChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isNotice = msg.type == 'system' || msg.message.startsWith('📢') || msg.message.startsWith('🎉') || msg.message.startsWith('⚠️');
        final isGift = msg.type == 'gift' || msg.message.startsWith('🎁');
        final timeStr = DateFormat('h:mm a').format(msg.createdAt);

        if (isNotice) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Text(
              msg.message,
              style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
            ),
          );
        }

        if (isGift) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF78350F).withValues(alpha: 0.6),
                  const Color(0xFF451A03).withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: Text(
              msg.message,
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender Avatar
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1E293B),
                child: ClipOval(
                  child: (msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty)
                      ? CachedImageLoader(imageUrl: msg.senderAvatar!, fit: BoxFit.cover)
                      : Text(
                          (msg.senderName?.isNotEmpty == true) ? msg.senderName![0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // Chat Bubble
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Timestamp
                    Row(
                      children: [
                        Text(
                          msg.senderName ?? 'Guest',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (msg.senderIsVerified) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 12),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Message Bubble Card
                    GestureDetector(
                      onLongPress: () => _showReactionPicker(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                          border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          msg.message,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                        ),
                      ),
                    ),

                    // Reaction Pills (💜 12, 😂 8, 🔥 5)
                    if (msg.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: msg.reactions.entries.map((entry) {
                            return InkWell(
                              onTap: () => _toggleReaction(index, entry.key),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A26),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(entry.key, style: const TextStyle(fontSize: 10)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${entry.value}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 6. Bottom Action Control Bar
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0E14),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // 1. Mic Button (Glowing Blue Circle)
          InkWell(
            onTap: _toggleMic,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isMyMicMuted
                    ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)])
                    : const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF00E5FF)]),
                boxShadow: [
                  BoxShadow(
                    color: _isMyMicMuted
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                _isMyMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Gift Box Button
          InkWell(
            onTap: () => _openGiftPicker(),
            borderRadius: BorderRadius.circular(20),
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
                    color: const Color(0xFFFFC837).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🎁', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 3. 3-Dots Menu Button
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('অতিরিক্ত অপশন ও রুম সেটিংস')),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 6),

          // 4. Message Input Capsule
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131A26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white38, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'মেসেজ লিখুন...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 5. Send Button
          InkWell(
            onTap: _sendChatMessage,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 6),

          // 6. Raise Hand / Speak Request Button (For Audience / Listeners)
          if (!_amIOnSeat && !_isHost)
            InkWell(
              onTap: _requestToSpeak,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _hasRequestedSeat
                      ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)])
                      : const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF00E5FF)]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _hasRequestedSeat ? '⏳' : '✋',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
