import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/video_call_pill.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/gift_picker_modal.dart';
import '../widgets/animated_in_chat_gift_button.dart';
import '../widgets/chat_partner_header_card.dart';
import '../widgets/report_user_modal.dart';
import '../services/chat_api_service.dart';
import '../../auth/services/auth_api_service.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/call_sound_manager.dart';
import '../../call/services/streaming_service.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../../core/services/gifts_api_service.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<ChatMessage> _messages = [];
  String _myUserId = '5';
  int _freeMessagesRemaining = 5;
  bool _isLoadingMessages = false;
  Timer? _realtimePollTimer;

  // Partner Profile & Moderation State
  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;
  String _partnerCountryFlag = '🇧🇩';
  String _partnerCountryName = 'Bangladesh';
  int _partnerAge = 22;
  String _partnerGender = 'Female';
  String _partnerGenderIcon = '♀';
  String _partnerLevel = 'Lv. 5';
  String _partnerGreeting = 'Hey handsome! Thanks for visiting my profile ❤️';
  String _partnerAvatar = '';
  bool _showEmojiStrip = false;
  int _videoCallRate = 100;

  // Voice recording state
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordDurationTimer;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _partnerAvatar = widget.thread.avatarUrl;
    _messages = List.from(widget.thread.messages);
    _videoCallRate = widget.thread.videoCallRate > 0 ? widget.thread.videoCallRate : 100;
    _initChatUserAndMessages();
    _loadCallConfig();
    _startRealtimePolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadCallConfig() async {
    try {
      final cfg = await CallApiService.getCallConfig();
      if (cfg != null && mounted) {
        final dynamic rpm = cfg['video_call_rate'] ?? cfg['rate_per_minute'];
        if (rpm != null) {
          final parsedRpm = int.tryParse(rpm.toString());
          if (parsedRpm != null && parsedRpm > 0) {
            setState(() {
              _videoCallRate = parsedRpm;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    _recordDurationTimer?.cancel();
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRealtimePolling() {
    _realtimePollTimer?.cancel();
    // Refresh chat messages in real time every 3.5s
    _realtimePollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted && !_isRecording) {
        _loadServerMessages(silent: true);
      }
    });
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

  Future<void> _loadServerMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingMessages = true);
    }
    try {
      final res = await ChatApiService.getMessagesWithUser(widget.thread.modelId);
      if (res != null && mounted) {
        if (res['free_messages_remaining'] is int) {
          _freeMessagesRemaining = res['free_messages_remaining'] as int;
        }

        // Check if partner profile/avatar is returned in chat_partner
        final chatPartner = res['chat_partner'] as Map<String, dynamic>?;
        String partnerAvatar = _partnerAvatar.isNotEmpty ? _partnerAvatar : widget.thread.avatarUrl;
        if (chatPartner != null) {
          final pAvatar = chatPartner['avatar_url']?.toString() ??
              chatPartner['avatar']?.toString() ??
              chatPartner['profile_photo']?.toString() ??
              chatPartner['cover_photo_url']?.toString();
          if (pAvatar != null && pAvatar.isNotEmpty) {
            partnerAvatar = pAvatar;
          }

          final dynamic rawRate = chatPartner['video_call_rate'] ?? chatPartner['price_per_min'] ?? chatPartner['call_rate'];
          if (rawRate != null) {
            final parsedR = int.tryParse(rawRate.toString());
            if (parsedR != null && parsedR > 0) {
              _videoCallRate = parsedR;
            }
          }

          setState(() {
            _partnerAvatar = partnerAvatar;
            if (chatPartner['is_blocked_by_me'] is bool) {
              _isBlockedByMe = chatPartner['is_blocked_by_me'] as bool;
            }
            if (chatPartner['is_blocked_by_them'] is bool) {
              _isBlockedByThem = chatPartner['is_blocked_by_them'] as bool;
            }
            if (chatPartner['country_flag'] != null) {
              _partnerCountryFlag = chatPartner['country_flag'].toString();
            }
            if (chatPartner['country'] != null) {
              _partnerCountryName = chatPartner['country'].toString();
            }
            if (chatPartner['age'] is int) {
              _partnerAge = chatPartner['age'] as int;
            }
            if (chatPartner['gender'] != null) {
              final g = chatPartner['gender'].toString().toLowerCase();
              _partnerGender = g.startsWith('m') ? 'Male' : 'Female';
              _partnerGenderIcon = g.startsWith('m') ? '♂' : '♀';
            }
            if (chatPartner['gender_icon'] != null) {
              _partnerGenderIcon = chatPartner['gender_icon'].toString();
            }
            if (chatPartner['level'] != null) {
              _partnerLevel = chatPartner['level'].toString();
            }
            if (chatPartner['greeting_message'] != null && chatPartner['greeting_message'].toString().isNotEmpty) {
              _partnerGreeting = chatPartner['greeting_message'].toString();
            } else if (chatPartner['bio'] != null && chatPartner['bio'].toString().isNotEmpty) {
              _partnerGreeting = chatPartner['bio'].toString();
            }
          });
        }

        if (res['messages'] is List) {
          final serverMsgs = (res['messages'] as List).map((m) {
            return ChatMessage.fromJson(
              m as Map<String, dynamic>,
              myUserId: _myUserId,
              partnerName: widget.thread.name,
              partnerAvatar: partnerAvatar,
            );
          }).toList();

          if (serverMsgs.isNotEmpty) {
            final oldLength = _messages.length;
            setState(() {
              _messages = serverMsgs;
              _isLoadingMessages = false;
            });
            if (serverMsgs.length > oldLength) {
              _scrollToBottom();
            }
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted && !silent) {
      setState(() => _isLoadingMessages = false);
    }
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

  // --- Real Voice Recording Actions ---
  Future<void> _startVoiceRecording() async {
    if (_isBlockedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please unblock user to send voice notes.')),
      );
      return;
    }
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentRecordingPath = path;

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordDurationTimer?.cancel();
        _recordDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _recordDuration++;
            });
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required for voice notes.')),
        );
      }
    } catch (e) {
      debugPrint('[VoiceRecord Error]: $e');
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    _recordDurationTimer?.cancel();
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      final duration = _recordDuration > 0 ? _recordDuration : 1;

      setState(() {
        _isRecording = false;
      });

      if (path != null && File(path).existsSync()) {
        final now = DateFormat('HH:mm').format(DateTime.now());
        final voiceMsg = ChatMessage(
          id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _myUserId,
          senderName: 'Me',
          senderAvatar: '',
          text: 'Voice Message ($duration s)',
          type: MessageType.voice,
          time: now,
          isFromMe: true,
          imageUrl: path,
          callDurationSeconds: duration,
        );

        setState(() {
          _messages.add(voiceMsg);
        });
        _scrollToBottom();

        // Upload actual recorded audio file
        final res = await ChatApiService.sendMessage(
          receiverId: widget.thread.modelId,
          voiceFile: File(path),
          type: 'voice',
          duration: duration,
        );

        if (!mounted) return;

        if (res['is_limit_reached'] == true || res['code'] == 'MESSAGE_LIMIT_REACHED') {
          RechargeGemsSheet.show(
            context,
            receiverId: widget.thread.modelId,
            receiverName: widget.thread.name,
            receiverAvatarUrl: widget.thread.avatarUrl,
            modalData: res['recharge_modal_data'] as Map<String, dynamic>?,
            onRechargeSuccess: () {
              _loadServerMessages();
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[StopVoiceRecord Error]: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordDurationTimer?.cancel();
    try {
      await _audioRecorder.stop();
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
  }

  // --- Real Image Picking & Upload ---
  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isBlockedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please unblock user to send images.')),
      );
      return;
    }
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final now = DateFormat('HH:mm').format(DateTime.now());

        final imgMsg = ChatMessage(
          id: 'img_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _myUserId,
          senderName: 'Me',
          senderAvatar: '',
          text: '',
          type: MessageType.image,
          time: now,
          isFromMe: true,
          imageUrl: pickedFile.path,
        );

        setState(() {
          _messages.add(imgMsg);
        });
        _scrollToBottom();

        final res = await ChatApiService.sendMessage(
          receiverId: widget.thread.modelId,
          imageFile: imageFile,
          type: 'image',
        );

        if (!mounted) return;

        if (res['is_limit_reached'] == true || res['code'] == 'MESSAGE_LIMIT_REACHED') {
          RechargeGemsSheet.show(
            context,
            receiverId: widget.thread.modelId,
            receiverName: widget.thread.name,
            receiverAvatarUrl: widget.thread.avatarUrl,
            modalData: res['recharge_modal_data'] as Map<String, dynamic>?,
            onRechargeSuccess: () {
              _loadServerMessages();
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[ImagePick Error]: $e');
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Send Photo',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonPink.withValues(alpha: 0.2),
                            border: Border.all(color: AppColors.neonPink),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: AppColors.neonPink, size: 26),
                        ),
                        const SizedBox(height: 8),
                        const Text('Camera', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00B0FF).withValues(alpha: 0.2),
                            border: Border.all(color: const Color(0xFF00B0FF)),
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Color(0xFF00B0FF), size: 26),
                        ),
                        const SizedBox(height: 8),
                        const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_isBlockedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please unblock user to send messages.')),
      );
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateFormat('HH:mm').format(DateTime.now());
    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId,
      senderName: 'Me',
      senderAvatar: '',
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

    if (res['is_limit_reached'] == true ||
        res['code'] == 'MESSAGE_LIMIT_REACHED' ||
        res['show_recharge_modal'] == true) {
      // Revert optimistically appended message & restore input text
      setState(() {
        _messages.remove(newMsg);
        _textController.text = text;
      });
      // Free message limit reached! Prompt coin recharge modal
      RechargeGemsSheet.show(
        context,
        receiverId: widget.thread.modelId,
        receiverName: widget.thread.name,
        receiverAvatarUrl: widget.thread.avatarUrl,
        modalData: res['recharge_modal_data'] as Map<String, dynamic>?,
        onRechargeSuccess: () {
          _sendMessage();
        },
      );
    } else if (res['success'] == true) {
      if (res['data']?['sender']?['free_messages_remaining'] is int) {
        setState(() {
          _freeMessagesRemaining = res['data']['sender']['free_messages_remaining'] as int;
        });
      }
    }
  }

  void _sendGift(GiftItem gift) {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final giftMsg = ChatMessage(
      id: 'gift_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId,
      senderName: 'Me',
      senderAvatar: '',
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
    // In background, notify server of gift
    GiftsApiService.sendGift(
      receiverId: widget.thread.modelId,
      giftId: gift.id,
      context: 'chat',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 You sent ${gift.emoji} ${gift.name} to ${widget.thread.name}!'),
        backgroundColor: AppColors.neonPink,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openVideoCall() async {
    final model = ModelProfile(
      id: widget.thread.modelId,
      accountId: widget.thread.modelId,
      name: widget.thread.name,
      age: 22,
      location: 'Live Host',
      intro: 'Live video with me',
      languages: const ['Bengali', 'English'],
      avatarUrl: widget.thread.avatarUrl,
      galleryUrls: [widget.thread.avatarUrl],
      pricePerMin: widget.thread.videoCallRate > 0 ? widget.thread.videoCallRate : 100,
    );

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
      // 1. Check call permission & user balance via POST /api/call/check-permission
      final permRes = await CallApiService.checkCallPermission(
        receiverId: model.id,
        callType: 'video',
      );

      if (permRes['can_call'] == false || permRes['show_recharge_modal'] == true || permRes['status'] == false) {
        CallSoundManager.stopRingtone();
        if (!mounted) return;
        Navigator.pop(context); // Close progress dialog
        RechargeGemsSheet.show(
          context,
          model: model,
          receiverId: widget.thread.modelId,
          receiverName: widget.thread.name,
          receiverAvatarUrl: widget.thread.avatarUrl,
          modalData: permRes['recharge_modal_data'] as Map<String, dynamic>?,
          onRechargeSuccess: () {
            _openVideoCall();
          },
        );
        return;
      }

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
        final channelName = res['channel_name']?.toString() ?? 'chat_call_${model.id}';
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : model.pricePerMin;

        StreamingService.startDynamicCall(
          context: context,
          model: model,
          callId: callId,
          channelName: channelName,
          isFreeTrial: isFreeTrial,
          freeDurationSeconds: freeSecs,
          ratePerMinute: ratePerMin,
          dialToneUrl: res['dial_tone_url']?.toString(),
        );
      } else if (res['is_low_balance'] == true ||
                 res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED' ||
                 res['code'] == 'INSUFFICIENT_BALANCE' ||
                 res['show_recharge_modal'] == true) {
        CallSoundManager.stopRingtone();
        RechargeGemsSheet.show(
          context,
          model: model,
          receiverId: widget.thread.modelId,
          receiverName: widget.thread.name,
          receiverAvatarUrl: widget.thread.avatarUrl,
          modalData: res['recharge_modal_data'] as Map<String, dynamic>?,
          onRechargeSuccess: () {
            _openVideoCall();
          },
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
      orElse: () => ModelProfile(
        id: widget.thread.modelId,
        name: widget.thread.name,
        age: _partnerAge,
        location: _partnerCountryName,
        intro: _partnerGreeting,
        languages: const ['Bengali', 'English'],
        avatarUrl: _partnerAvatar.isNotEmpty ? _partnerAvatar : widget.thread.avatarUrl,
        galleryUrls: widget.thread.avatarUrl.isNotEmpty ? [widget.thread.avatarUrl] : [],
        pricePerMin: widget.thread.videoCallRate > 0 ? widget.thread.videoCallRate : 1800,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: model),
      ),
    );
  }

  void _showChatOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                _isBlockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
                color: _isBlockedByMe ? const Color(0xFF00E676) : const Color(0xFFFF5252),
              ),
              title: Text(
                _isBlockedByMe ? 'Unblock ${widget.thread.name}' : 'Block ${widget.thread.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                _isBlockedByMe
                    ? 'Allow incoming calls and messages'
                    : 'Prevent this user from messaging or calling you',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _toggleBlockUser();
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.amber),
              title: Text(
                'Report ${widget.thread.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text(
                'Report harassment, fraud, or inappropriate behavior',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ReportUserModal.show(
                  context,
                  reportedUserId: widget.thread.modelId,
                  partnerName: widget.thread.name,
                );
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.white60),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBlockUser() async {
    if (_isBlockedByMe) {
      final res = await ChatApiService.unblockUser(widget.thread.modelId);
      if (res['success'] == true) {
        setState(() => _isBlockedByMe = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unblocked ${widget.thread.name}.'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      }
    } else {
      final res = await ChatApiService.blockUser(widget.thread.modelId);
      if (res['success'] == true) {
        setState(() => _isBlockedByMe = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Blocked ${widget.thread.name}.'),
              backgroundColor: const Color(0xFFD32F2F),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAvatar = _partnerAvatar.isNotEmpty ? _partnerAvatar : widget.thread.avatarUrl;

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
                    imageUrl: effectiveAvatar,
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
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFA000), Color(0xFFFF6F00)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _partnerLevel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
            onTap: _isBlockedByMe ? null : _openVideoCall,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: _isBlockedByMe ? null : AppColors.orangeGradient,
                color: _isBlockedByMe ? Colors.white24 : null,
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
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _showChatOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Free messages remaining indicator banner
          if (_freeMessagesRemaining > 0 && !_isBlockedByMe && !_isBlockedByThem)
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

          if (_isLoadingMessages && _messages.isEmpty)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
            ),

          // Chat messages timeline + Top Partner Profile Header Card
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                // First item is the Chat Partner Profile Badge Card
                if (index == 0) {
                  return ChatPartnerHeaderCard(
                    partnerName: widget.thread.name,
                    avatarUrl: effectiveAvatar,
                    countryFlag: _partnerCountryFlag,
                    countryName: _partnerCountryName,
                    age: _partnerAge,
                    genderText: _partnerGender,
                    genderIcon: _partnerGenderIcon,
                    levelText: _partnerLevel,
                    greetingText: _partnerGreeting,
                    onTap: _openProfile,
                    onCallTap: _openVideoCall,
                  );
                }

                final message = _messages[index - 1];
                return ChatBubble(
                  message: message,
                  fallbackAvatar: effectiveAvatar,
                  partnerName: widget.thread.name,
                  onImageTap: message.imageUrl != null && message.imageUrl!.isNotEmpty
                      ? () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.black.withValues(alpha: 0.92),
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                children: [
                                  Center(
                                    child: InteractiveViewer(
                                      maxScale: 4.0,
                                      child: CachedImageLoader(
                                        imageUrl: message.imageUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 40,
                                    right: 20,
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          ),

          // Blocked Notification Banner OR Interactive Bottom Input Bar
          if (_isBlockedByMe)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF231526),
                border: Border(top: BorderSide(color: Color(0xFFFF5252), width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Color(0xFFFF5252), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have blocked ${widget.thread.name}.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleBlockUser,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.18),
                        foregroundColor: const Color(0xFF00E676),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            )
          else if (_isBlockedByThem)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF231526),
              child: const SafeArea(
                top: false,
                child: Center(
                  child: Text(
                    'You cannot send messages to this user.',
                    style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            )
          else
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
                  // Quick Emoji Action Strip (Toggleable via Heart Icon)
                  if (!_isRecording && _showEmojiStrip)
                    Container(
                      height: 34,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ...['❤️', '🔥', '😍', '💋', '🌹', '🎉', '👑', '✨', '💎', '🥰', '😘', '👋'].map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                _textController.text = '${_textController.text}$emoji';
                                _textController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _textController.text.length),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 17)),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  // Row 1: Voice Recording Active Mode OR Regular Input Bar
                  if (_isRecording)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C162E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.neonPink, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Recording 0:0${_recordDuration % 60}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _cancelVoiceRecording,
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 28),
                            onPressed: _stopAndSendVoiceRecording,
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Quick Emoji / Heart Reaction Toggle Button
                        IconButton(
                          icon: Icon(
                            _showEmojiStrip ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _showEmojiStrip ? const Color(0xFFFF2D75) : const Color(0xFFFF6994),
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() => _showEmojiStrip = !_showEmojiStrip);
                          },
                          tooltip: 'Quick Reactions',
                        ),

                        // Image / Camera Attachment Button
                        IconButton(
                          icon: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Color(0xFF00B0FF),
                            size: 24,
                          ),
                          onPressed: _showImageSourcePicker,
                          tooltip: 'Send Image',
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
                        const SizedBox(width: 4),

                        // Voice Note Mic Button (Real Recording)
                        IconButton(
                          icon: const Icon(
                            Icons.mic_rounded,
                            color: AppColors.onlineGreen,
                            size: 26,
                          ),
                          onPressed: _startVoiceRecording,
                          tooltip: 'Record Voice Note',
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

                  // Row 2: Video Call Action Pill & Animated Gift Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Video Call Pill Button with Dynamic Rate from Admin / Backend
                      VideoCallPill(
                        pricePerMin: _videoCallRate,
                        label: '',
                        onTap: _openVideoCall,
                      ),

                      // Animated Glowing In-Chat Gift Button
                      AnimatedInChatGiftButton(
                        onTap: () {
                          GiftPickerModal.show(
                            context,
                            receiverId: widget.thread.modelId,
                            receiverName: widget.thread.name,
                            receiverAvatarUrl: effectiveAvatar,
                            onGiftSelected: _sendGift,
                          );
                        },
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
