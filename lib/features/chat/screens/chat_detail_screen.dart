import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/video_call_pill.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/gift_picker_modal.dart';
import '../services/chat_api_service.dart';
import '../../auth/services/auth_api_service.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/call_sound_manager.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../../core/data/mock_data.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatDetailScreen({
    super.key,
    required this.thread,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  String _myUserId = '5';
  int _freeMessagesRemaining = 5;
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.thread.messages);
    _initChatUserAndMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _initChatUserAndMessages() async {
    try {
      final savedUser = await AuthApiService.getSavedUser();
      if (savedUser != null) {
        _myUserId = savedUser['id']?.toString() ?? '5';
      }
    } catch (_) {}

    // Mark conversation read on server
    ChatApiService.markAsRead(widget.thread.modelId);

    // Fetch real chat history from server
    await _loadServerMessages();
  }

  Future<void> _loadServerMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      final res = await ChatApiService.getMessagesWithUser(widget.thread.modelId);
      if (res != null && mounted) {
        if (res['free_messages_remaining'] is int) {
          _freeMessagesRemaining = res['free_messages_remaining'] as int;
        }

        if (res['messages'] is List) {
          final serverMsgs = (res['messages'] as List).map((m) {
            return ChatMessage.fromJson(
              m as Map<String, dynamic>,
              myUserId: _myUserId,
              partnerName: widget.thread.name,
              partnerAvatar: widget.thread.avatarUrl,
            );
          }).toList();

          if (serverMsgs.isNotEmpty) {
            setState(() {
              _messages = serverMsgs;
              _isLoadingMessages = false;
            });
            _scrollToBottom();
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingMessages = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateFormat('HH:mm').format(DateTime.now());
    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId,
      senderName: 'Me',
      senderAvatar: MockData.imgMoyna,
      text: text,
      type: MessageType.text,
      time: now,
      isFromMe: true,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
    });

    _scrollToBottom();

    // Call RESTful send message API
    final res = await ChatApiService.sendMessage(
      receiverId: widget.thread.modelId,
      message: text,
      type: 'text',
    );

    if (!mounted) return;

    if (res['is_limit_reached'] == true || res['code'] == 'MESSAGE_LIMIT_REACHED') {
      // Free message limit reached! Prompt coin recharge modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RechargeGemsSheet(
          onRechargeSuccess: () {
            _sendMessage();
          },
        ),
      );
    } else if (res['success'] == true) {
      if (res['data']?['sender']?['free_messages_remaining'] is int) {
        setState(() {
          _freeMessagesRemaining = res['data']['sender']['free_messages_remaining'] as int;
        });
      }
    } else {
      // Simulate cute automated reply if offline/test mode
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        final replyMsg = ChatMessage(
          id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
          senderId: widget.thread.modelId,
          senderName: widget.thread.name,
          senderAvatar: widget.thread.avatarUrl,
          text: 'Aww sweet! Call me on video right now so we can talk privately ❤️',
          type: MessageType.text,
          time: DateFormat('HH:mm').format(DateTime.now()),
          isFromMe: false,
        );
        setState(() {
          _messages.add(replyMsg);
        });
        _scrollToBottom();
      });
    }
  }

  Future<void> _sendVoiceNote() async {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final voiceMsg = ChatMessage(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId,
      senderName: 'Me',
      senderAvatar: MockData.imgMoyna,
      text: 'Voice Message (0:04)',
      type: MessageType.voice,
      time: now,
      isFromMe: true,
      callDurationSeconds: 4,
    );

    setState(() {
      _messages.add(voiceMsg);
    });
    _scrollToBottom();

    final res = await ChatApiService.sendMessage(
      receiverId: widget.thread.modelId,
      message: 'Voice Message',
      type: 'voice',
      duration: 4,
    );

    if (!mounted) return;

    if (res['is_limit_reached'] == true || res['code'] == 'MESSAGE_LIMIT_REACHED') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RechargeGemsSheet(
          onRechargeSuccess: () {
            _sendVoiceNote();
          },
        ),
      );
    }
  }

  void _sendGift(GiftItem gift) {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final giftMsg = ChatMessage(
      id: 'gift_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: 'Me',
      senderAvatar: MockData.imgMoyna,
      text: 'Sent ${gift.name} ${gift.emoji}',
      type: MessageType.gift,
      time: now,
      isFromMe: true,
      giftName: gift.name,
      giftEmoji: gift.emoji,
    );

    setState(() {
      _messages.add(giftMsg);
    });

    _scrollToBottom();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 You sent ${gift.emoji} ${gift.name} to ${widget.thread.name}!'),
        backgroundColor: AppColors.neonPink,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openVideoCall() async {
    final model = MockData.models.firstWhere(
      (m) => m.id == widget.thread.modelId || m.name == widget.thread.name,
      orElse: () => ModelProfile(
        id: widget.thread.modelId,
        name: widget.thread.name,
        age: 21,
        location: 'Dhaka',
        intro: 'Live video with me',
        languages: const ['Bengali', 'English'],
        avatarUrl: widget.thread.avatarUrl,
        galleryUrls: [widget.thread.avatarUrl],
        charmLevel: 8900,
        topFan: 'user_fan',
        pricePerMin: 1800,
      ),
    );

    // 1. 🔑 Instant 0ms Outgoing Ringtone
    CallSoundManager.playOutgoingRingtone();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.neonPink),
              SizedBox(height: 14),
              Text(
                'Connecting Video Call...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await CallApiService.initiateCall(
        receiverId: model.id,
        receiverAccountId: model.accountId,
        callType: 'video',
      );

      if (!mounted) {
        CallSoundManager.stopRingtone();
        return;
      }
      Navigator.pop(context); // Close progress dialog

      if (res['success'] == true) {
        final int? callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '');
        final channelName = res['channel_name']?.toString();
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : (model.pricePerMin > 0 ? model.pricePerMin : 100);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              model: model,
              callId: callId,
              channelName: channelName,
              isFreeTrial: isFreeTrial,
              freeDurationSeconds: freeSecs,
              ratePerMinute: ratePerMin,
              dialToneUrl: res['dial_tone_url']?.toString(),
            ),
          ),
        ).then((_) => CallSoundManager.stopRingtone());
      } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        CallSoundManager.stopRingtone();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RechargeGemsSheet(
            model: model,
            onRechargeSuccess: () {
              _openVideoCall();
            },
          ),
        );
      } else {
        CallSoundManager.stopRingtone();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Could not initiate call.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      CallSoundManager.stopRingtone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openProfile() {
    final model = MockData.models.firstWhere(
      (m) => m.id == widget.thread.modelId || m.name == widget.thread.name,
      orElse: () => MockData.models.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 1,
        leadingWidth: 40,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _openProfile,
          child: Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: CachedImageLoader(
                    imageUrl: widget.thread.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.thread.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.gemYellow,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.onlineGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: AppColors.onlineGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
        actions: [
          // Top Quick Video Call Action
          GestureDetector(
            onTap: _openVideoCall,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Free messages remaining indicator banner
          if (_freeMessagesRemaining > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: const Color(0xFF1E1430),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.neonPink, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    '$_freeMessagesRemaining free ${_freeMessagesRemaining == 1 ? "message" : "messages"} remaining',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoadingMessages)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
            ),

          // Chat messages timeline
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),

          // Interactive Bottom Input Bar matching Screenshot 2
          Container(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                top: BorderSide(color: AppColors.cardBorder, width: 0.8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Text Input and Send
                  Row(
                    children: [
                      // Emoji button
                      IconButton(
                        icon: const Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: AppColors.gemYellow,
                          size: 24,
                        ),
                        onPressed: () {
                          _textController.text += '😍';
                        },
                      ),

                      // Text Field
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.cardDarkElevated,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.cardBorder, width: 0.8),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Send message',
                              hintStyle: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 6),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Voice Note Mic Button
                      IconButton(
                        icon: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.onlineGreen,
                          size: 24,
                        ),
                        onPressed: _sendVoiceNote,
                        tooltip: 'Send Voice Note',
                      ),

                      // Send Button
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Video Call Action Pill & Gift Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Video Call Pill Button (1800/min)
                      VideoCallPill(
                        pricePerMin: 1800,
                        label: '',
                        onTap: _openVideoCall,
                      ),

                      // Quick Gift Box Button
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => GiftPickerModal(
                              onGiftSelected: _sendGift,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gemYellow.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Send Gift 🎁',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
