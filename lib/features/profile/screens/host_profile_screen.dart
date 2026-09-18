import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../widgets/gifts_received_card.dart';
import 'level_progression_screen.dart';
import '../../call/screens/incoming_call_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/call_sound_manager.dart';
import '../../call/services/streaming_service.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/services/gifts_api_service.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../auth/services/auth_api_service.dart';

class HostProfileScreen extends StatefulWidget {
  final ModelProfile model;

  const HostProfileScreen({
    super.key,
    required this.model,
  });

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen>
    with TickerProviderStateMixin {
  late int _selectedGalleryIndex;
  final List<_FloatingHeart> _hearts = [];
  Timer? _heartTimer;
  UserGiftsData? _giftsData;
  late ModelProfile _currentModel;

  @override
  void initState() {
    super.initState();
    _currentModel = widget.model;
    _selectedGalleryIndex = 0;

    // Fast instant cached gifts data
    _giftsData = GiftsApiService.getCachedReceivedGifts(widget.model.id);
    _loadHostGifts();
    _loadFullProfile();

    // Trigger RESTful profile view notification & auto-callback
    _triggerProfileViewAndAutoCallback();

    // Emit cute floating love reaction hearts periodically matching Screenshot 3
    _heartTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (mounted) {
        _emitHeart();
      }
    });
  }

  Future<void> _loadFullProfile() async {
    final fresh = await ProfileApiService.getProfile(widget.model.id);
    if (fresh != null && mounted) {
      setState(() {
        _currentModel = fresh;
      });
    }
  }

  void _triggerProfileViewAndAutoCallback() {
    ProfileApiService.recordProfileView(widget.model.id).then((res) {
      if (res != null && mounted) {
        final callback = res['callback'] as Map<String, dynamic>?;
        if (callback != null && callback['auto_call_triggered'] == true) {
          // Host automatically initiates callback after visiting their profile
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
              final rawCallId = callback['call_id'];
              final int? callId = rawCallId is int
                  ? rawCallId
                  : int.tryParse(rawCallId?.toString() ?? '0');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IncomingCallScreen(
                    model: _currentModel,
                    callId: callId,
                    channelName: callback['channel_name']?.toString(),
                    isFreeTrial: true,
                    freeDurationSeconds: callback['free_duration_seconds'] is int
                        ? callback['free_duration_seconds'] as int
                        : 10,
                    ratePerMinute: callback['required_coins'] is int
                        ? callback['required_coins'] as int
                        : (_currentModel.pricePerMin > 0 ? _currentModel.pricePerMin : 100),
                  ),
                ),
              );
            }
          });
        }
      }
    });
  }

  Future<void> _loadHostGifts() async {
    final data = await GiftsApiService.getReceivedGifts(widget.model.id);
    if (mounted && data != null) {
      setState(() {
        _giftsData = data;
      });
    }
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }

  void _emitHeart({bool isUserClick = false}) {
    if (isUserClick) {
      GiftsApiService.sendLike(userId: _currentModel.id, count: 1, context: 'profile').then((res) {
        if (mounted) {
          _loadHostGifts();
        }
      });
    }
    setState(() {
      _hearts.add(_FloatingHeart(
        key: UniqueKey(),
        onComplete: (key) {
          if (mounted) {
            setState(() {
              _hearts.removeWhere((h) => h.key == key);
            });
          }
        },
      ));
    });
  }

  Future<void> _startVideoCall() async {
    final int cachedCoins = WalletApiService.getCachedCoins();
    final int ratePerMin = _currentModel.pricePerMin > 0 ? _currentModel.pricePerMin : 100;

    // ⚡ ZERO-DELAY INSTANT SYNCHRONOUS CHECK (<0.001s):
    if (cachedCoins < ratePerMin) {
      _showRechargeSheet();
      return;
    }

    final savedUser = await AuthApiService.getSavedUser();
    final myId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
    final myAccountId = savedUser?['account_id']?.toString();

    if (!mounted) return;
    if ((myId != null && (myId == _currentModel.id || myId == _currentModel.accountId)) ||
        (myAccountId != null && (myAccountId == _currentModel.accountId || myAccountId == _currentModel.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call your own profile! Please choose another user to call.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Secondary check against fresh savedUser:
    final int userCoins = (savedUser?['coins'] is num)
        ? (savedUser!['coins'] as num).toInt()
        : (int.tryParse('${savedUser?['coins']}') ?? cachedCoins);

    if (userCoins < ratePerMin) {
      _showRechargeSheet();
      return;
    }

    CallSoundManager.playOutgoingRingtone();

    try {
      final res = await CallApiService.initiateCall(
        receiverId: _currentModel.id,
        receiverAccountId: _currentModel.accountId,
        callType: 'video',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final int? callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '');
        final channelName = res['channel_name']?.toString() ?? 'call_${_currentModel.id}';
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : (_currentModel.pricePerMin > 0 ? _currentModel.pricePerMin : 100);

        StreamingService.startDynamicCall(
          context: context,
          model: _currentModel,
          callId: callId,
          channelName: channelName,
          isFreeTrial: isFreeTrial,
          freeDurationSeconds: freeSecs,
          ratePerMinute: ratePerMin,
          dialToneUrl: res['dial_tone_url']?.toString(),
          initialSessionData: res,
        );
      } else if (res['is_low_balance'] == true ||
                 res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED' ||
                 res['code'] == 'INSUFFICIENT_BALANCE' ||
                 res['show_recharge_modal'] == true) {
        CallSoundManager.stopRingtone();
        _showRechargeSheet(modalData: res['recharge_modal_data'] as Map<String, dynamic>?);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startAudioCall() async {
    final int cachedCoins = WalletApiService.getCachedCoins();
    final int ratePerMin = 60; // Standard audio rate

    // ⚡ ZERO-DELAY INSTANT SYNCHRONOUS CHECK (<0.001s):
    if (cachedCoins < ratePerMin) {
      _showRechargeSheet();
      return;
    }

    final savedUser = await AuthApiService.getSavedUser();
    final myId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
    final myAccountId = savedUser?['account_id']?.toString();

    if (!mounted) return;
    if ((myId != null && (myId == _currentModel.id || myId == _currentModel.accountId)) ||
        (myAccountId != null && (myAccountId == _currentModel.accountId || myAccountId == _currentModel.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call your own profile! Please choose another user to call.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Secondary check against fresh savedUser:
    final int userCoins = (savedUser?['coins'] is num)
        ? (savedUser!['coins'] as num).toInt()
        : (int.tryParse('${savedUser?['coins']}') ?? cachedCoins);

    if (userCoins < ratePerMin) {
      _showRechargeSheet();
      return;
    }

    CallSoundManager.playOutgoingRingtone();

    try {
      final res = await CallApiService.initiateCall(
        receiverId: _currentModel.id,
        receiverAccountId: _currentModel.accountId,
        callType: 'audio',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final int? callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '');
        final channelName = res['channel_name']?.toString() ?? 'audio_call_${_currentModel.id}';
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : (_currentModel.pricePerMin > 0 ? _currentModel.pricePerMin : 100);

        StreamingService.startDynamicCall(
          context: context,
          model: _currentModel,
          callId: callId,
          channelName: channelName,
          callType: 'audio',
          isFreeTrial: isFreeTrial,
          freeDurationSeconds: freeSecs,
          ratePerMinute: ratePerMin,
          dialToneUrl: res['dial_tone_url']?.toString(),
          initialSessionData: res,
        );
      } else if (res['is_low_balance'] == true ||
                 res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED' ||
                 res['code'] == 'INSUFFICIENT_BALANCE' ||
                 res['show_recharge_modal'] == true) {
        CallSoundManager.stopRingtone();
        _showRechargeSheet(modalData: res['recharge_modal_data'] as Map<String, dynamic>?);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showRechargeSheet({Map<String, dynamic>? modalData}) {
    RechargeGemsSheet.show(
      context,
      model: _currentModel,
      receiverId: _currentModel.id,
      receiverName: _currentModel.name,
      receiverAvatarUrl: _currentModel.avatarUrl,
      modalData: modalData,
      onRechargeSuccess: () {
        _startVideoCall();
      },
    );
  }

  void _showTopFansSheet(ModelProfile model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: GiftsApiService.getTopFans(model.id),
        builder: (context, snapshot) {
          final topFans = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('👑', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'Top Fans Leaderboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting && topFans.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: AppColors.gemYellow),
                    ),
                  )
                else if (topFans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Top fan: ${_giftsData?.topFan.name ?? model.topFan}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  ...topFans.map((fan) {
                    final rank = fan['rank'] ?? 1;
                    final crown = rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank'));
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedImageLoader(
                            imageUrl: fan['avatar_url']?.toString() ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(crown, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            fan['display_name']?.toString() ?? 'Fan',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Total: ${fan['formatted_coins'] ?? fan['total_coins'] ?? 0} coins',
                        style: const TextStyle(color: AppColors.gemYellow, fontSize: 12),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sendHiGreeting() {
    ProfileApiService.sendHiGreeting(_currentModel.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent greeting to ${_currentModel.name}! 👋'),
        backgroundColor: const Color(0xFF8E24AA),
        duration: const Duration(seconds: 2),
      ),
    );

    final thread = ChatThread(
      id: 't_${_currentModel.id}',
      modelId: _currentModel.id,
      name: _currentModel.name,
      avatarUrl: _currentModel.avatarUrl,
      lastMessage: 'Hi! 👋',
      time: 'Just now',
      messages: [
        ChatMessage(
          id: 'hi_${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'me',
          senderName: 'Me',
          senderAvatar: _currentModel.avatarUrl,
          text: 'Hi! 👋',
          type: MessageType.text,
          time: 'Just now',
          isFromMe: true,
        ),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = _currentModel;
    final gallery = model.galleryUrls.isNotEmpty
        ? model.galleryUrls
        : [if (model.coverPhotoUrl != null) model.coverPhotoUrl!, model.avatarUrl];
    final activePhotoUrl = gallery.isNotEmpty
        ? gallery[_selectedGalleryIndex % gallery.length]
        : (model.coverPhotoUrl ?? model.avatarUrl);
    final displayName = model.fullName.isNotEmpty ? model.fullName : model.name;
    final isMale = model.gender?.toLowerCase() == 'male';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Scrollable Profile Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Photo with Horizontal Gallery Thumbnails at bottom (matching Screenshot 3)
                Stack(
                  children: [
                    // Main Cover Image
                    SizedBox(
                      height: 380,
                      width: double.infinity,
                      child: CachedImageLoader(
                        imageUrl: activePhotoUrl,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Gradient overlay
                    Container(
                      height: 380,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x88000000),
                            Colors.transparent,
                            Color(0xDD0F0E17),
                            AppColors.backgroundDark,
                          ],
                          stops: [0.0, 0.35, 0.8, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Horizontal Thumbnail Strip (previews at the bottom of cover photo - Screenshot 3)
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: gallery.length,
                          itemBuilder: (context, index) {
                            final isSelected = _selectedGalleryIndex == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGalleryIndex = index;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 54,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white24,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedImageLoader(
                                    imageUrl: gallery[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Profile Details Sheet Header (Avatar, Name, ID, Badges & Emitting Heart)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Host Avatar + Name + ID Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Host Avatar with Profile Base Frame & Badge
                              AvatarWithFrame(
                                avatarUrl: model.avatarUrl,
                                frameUrl: model.avatarFrameUrl,
                                level: model.currentLevel > 0 ? model.currentLevel : model.level,
                                badgeColor: model.badgeColor,
                                glowColor: model.glowColor,
                                size: 62,
                                showLevelBadge: true,
                              ),
                              const SizedBox(width: 12),

                              // Name & ID
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Blue Verified Badge (v)
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF00E5FF),
                                            border: Border.all(color: Colors.white, width: 1),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'v',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // ID Badge with copy
                                    GestureDetector(
                                      onTap: () {
                                        final copyId = model.effectiveAccountId;
                                        Clipboard.setData(ClipboardData(text: copyId));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('ID $copyId copied to clipboard'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardDarkElevated,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ID ${model.effectiveAccountId}',
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 11),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Circular Glowing Heart / Like Button (Screenshot 1 & 2)
                              GestureDetector(
                                onTap: () {
                                  _emitHeart(isUserClick: true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('You liked ${model.name}! ❤️'),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: AppColors.neonPink,
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF4081), Color(0xFFFF80AB), Color(0xFFFF5252)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF4081).withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Status Badges Row: Active, Lv4, Location, Age (matching Screenshot 3)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              // Active Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.onlineGreen),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: AppColors.onlineGreen, size: 6),
                                    SizedBox(width: 4),
                                    Text('Active', style: TextStyle(color: AppColors.onlineGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Host Level Badge Pill (Tappable to view progression)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LevelProgressionScreen(
                                        accountId: model.effectiveAccountId,
                                        userId: model.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: HexColor.fromHex(model.badgeColor, defaultColor: const Color(0xFF7C4DFF)),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: HexColor.fromHex(model.badgeColor, defaultColor: const Color(0xFF7C4DFF)).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Lv.${model.currentLevel > 0 ? model.currentLevel : model.level}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 8),
                                    ],
                                  ),
                                ),
                              ),

                              // Location Pill (e.g. Pakistan / Bangladesh)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B0FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white, size: 11),
                                    const SizedBox(width: 2),
                                    Text(model.location, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Age Pill (e.g. ♀ 27 or ♂ 25)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isMale ? const Color(0xFF3B82F6) : const Color(0xFFE91E63),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isMale ? Icons.male_rounded : Icons.female_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text('${model.age}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 1. Close Friends (0/3) 3 Cards matching Screenshot 3
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1828),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Close Friends (0/3)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      size: 15,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: List.generate(
                                    3,
                                    (index) => Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          left: index == 0 ? 0 : 4,
                                          right: index == 2 ? 0 : 4,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF272438), // Distinct rounded card
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.05),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF3A354D),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.chair_rounded,
                                                  color: Colors.white70,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Waiting for\nsomeone',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10.5,
                                                height: 1.25,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. Introduction (Screenshot 4)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1828),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Introduction',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  model.intro.isNotEmpty ? model.intro : 'Suggest good friends',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Speaking Language (Screenshot 4)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1828),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Speaking language',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (model.languages.isNotEmpty ? model.languages : ['Urdu', 'English'])
                                      .map(
                                        (lang) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF272438),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            lang,
                                            style: const TextStyle(
                                              color: Color(0xFFE2E8F0),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Honor (Charm Level & Top Fans Badges - Screenshot 3)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'Honor',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              _buildCharmAndFansRow(model),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 5. Gifts Received > Card (Screenshot 1 & 2)
                          GiftsReceivedCard(userId: model.id, model: model),
                          const SizedBox(height: 14),

                          // 6. Gallery Card matching Screenshot 1 & 2
                          _buildGallerySection(),
                          const SizedBox(height: 14),
                        ],
                      ),

                      // Floating Emitting Love Hearts Stack
                      Positioned(
                        top: 24,
                        right: 24,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              ..._hearts,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top Back Navigation Button & Options
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 22),
                        onPressed: _showRechargeSheet,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Bar matching Screenshot 1 & 2: (Circular Hi Button + Video Call Pill Button)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0E18).withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Hi Button (Circular purple/lavender button on left matching Screenshot 1 & 2)
                    GestureDetector(
                      onTap: _sendHiGreeting,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFBA68C8), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8E24AA).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Hi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Video Call Action Bar (Phone icon + Video Call + 💎 2700/min) matching Screenshot 1 & 2
                    Expanded(
                      child: GestureDetector(
                        onTap: _startVideoCall,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E24AA), Color(0xFFD81B60), Color(0xFFE91E63)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE91E63).withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Video Call',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 12),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${model.pricePerMin > 0 ? model.pricePerMin : 2700}/min',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharmAndFansRow(ModelProfile model) {
    return Row(
      children: [
        // Left: Charm Level Badge matching Screenshot 1 & 3
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C1935), Color(0xFF1B1325)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                // Diamond icon in gold rounded diamond box
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8F00).withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '💎',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Charm Level',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, color: Color(0xFFFF80AB), size: 10),
                            const SizedBox(width: 3),
                            Text(
                              _giftsData?.charmLevel.levelTag ?? 'Lv${model.level > 0 ? model.level : 6}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
          ),
        ),
        const SizedBox(width: 10),

        // Right: Top Fans Badge matching Screenshot 1 & 3
        Expanded(
          child: GestureDetector(
            onTap: () => _showTopFansSheet(model),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2248), Color(0xFF141732)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                        ),
                        child: ClipOval(
                          child: (_giftsData?.topFan.avatarUrl.isNotEmpty == true)
                              ? CachedImageLoader(
                                  imageUrl: _giftsData!.topFan.avatarUrl,
                                  fit: BoxFit.cover,
                                )
                              : (model.avatarUrl.isNotEmpty
                                  ? CachedImageLoader(
                                      imageUrl: model.avatarUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.person, color: Colors.white70, size: 20)),
                        ),
                      ),
                      const Positioned(
                        top: -6,
                        left: -2,
                        child: Text('👑', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Top Fans',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _giftsData?.topFan.name.isNotEmpty == true
                              ? _giftsData!.topFan.name
                              : (model.topFan.isNotEmpty ? model.topFan : 'SUPER_BOY...'),
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGallerySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E1722), // Warm copper/pink glow
            Color(0xFF1A1325), // Dark purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gallery Header with Glowing Crystal Crown matching Screenshot 1 & 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Crystal glowing crown artwork
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: const Text('👑✨', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Avatar Frame 1
          const Text(
            'Avatar Frame 1',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          // Rose Ribbon Frame Preview
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF472B6),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF472B6).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Colors.white30,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// Helper Widget for Floating Rising Love Reaction Particles matching Screenshot 3
class _FloatingHeart extends StatefulWidget {
  final ValueChanged<Key> onComplete;

  const _FloatingHeart({
    required super.key,
    required this.onComplete,
  });

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late double _randomX;

  @override
  void initState() {
    super.initState();
    _randomX = (math.Random().nextDouble() - 0.5) * 40;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward().then((_) {
        widget.onComplete(widget.key!);
      });

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _translateY = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_randomX, _translateY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF4081),
              size: 22,
            ),
          ),
        );
      },
    );
  }
}
