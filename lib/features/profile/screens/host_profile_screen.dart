import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../widgets/gifts_received_grid.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/call_sound_manager.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedGalleryIndex = 0;

    // Emit cute floating love reaction hearts periodically matching Screenshot 3
    _heartTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (mounted) {
        _emitHeart();
      }
    });
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }

  void _emitHeart() {
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
        receiverId: widget.model.id,
        receiverAccountId: widget.model.accountId,
        callType: 'video',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (res['success'] == true) {
        final int? callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '');
        final channelName = res['channel_name']?.toString();
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              model: widget.model,
              callId: callId,
              channelName: channelName,
              isFreeTrial: isFreeTrial,
              freeDurationSeconds: freeSecs,
              ratePerMinute: ratePerMin,
              dialToneUrl: res['dial_tone_url']?.toString(),
            ),
          ),
        );
      } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        CallSoundManager.stopRingtone();
        _showRechargeSheet();
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

  Future<void> _startAudioCall() async {
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
                'Connecting Audio Call...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await CallApiService.initiateCall(
        receiverId: widget.model.id,
        receiverAccountId: widget.model.accountId,
        callType: 'audio',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (res['success'] == true) {
        final int? callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '');
        final channelName = res['channel_name']?.toString();
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;
        final ratePerMin = (res['rate_per_minute'] is int) ? res['rate_per_minute'] as int : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              model: widget.model,
              callId: callId,
              channelName: channelName,
              isFreeTrial: isFreeTrial,
              freeDurationSeconds: freeSecs,
              ratePerMinute: ratePerMin,
              dialToneUrl: res['dial_tone_url']?.toString(),
            ),
          ),
        );
      } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        CallSoundManager.stopRingtone();
        _showRechargeSheet();
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

  void _showRechargeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RechargeGemsSheet(
        model: widget.model,
        onRechargeSuccess: () {
          _startVideoCall();
        },
      ),
    );
  }

  void _sendHiGreeting() {
    final thread = ChatThread(
      id: 't_${widget.model.id}',
      modelId: widget.model.id,
      name: widget.model.name,
      avatarUrl: widget.model.avatarUrl,
      lastMessage: 'Hi! ❤️',
      time: 'Just now',
      messages: [
        ChatMessage(
          id: 'hi_1',
          senderId: 'me',
          senderName: 'Me',
          senderAvatar: widget.model.avatarUrl,
          text: 'Hi! ❤️',
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
    final model = widget.model;
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
                              // Avatar
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                                ),
                                child: ClipOval(
                                  child: CachedImageLoader(
                                    imageUrl: model.avatarUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
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
                                        Clipboard.setData(ClipboardData(text: model.id));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('ID copied to clipboard'),
                                            duration: Duration(seconds: 1),
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
                                              'ID ${model.id}',
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

                              // Lv4 Purple Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C4DFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Lv${model.level}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

                          // Close Friends (0/3) with Armchair / Sofa Icons (Screenshot 3)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder, width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Close Friends (0/3)',
                                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.help_outline_rounded, color: AppColors.textMuted, size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: List.generate(
                                    3,
                                    (index) => Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF262238),
                                        border: Border.all(color: AppColors.cardBorder),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.chair_rounded,
                                          color: Color(0xFF9E9E9E),
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Introduction
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder, width: 0.8),
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
                                  model.intro,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Speaking Languages
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder, width: 0.8),
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
                                  children: model.languages
                                      .map(
                                        (lang) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardDarkElevated,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppColors.cardBorder),
                                          ),
                                          child: Text(lang, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Interests & Tags
                          if (model.tags.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder, width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Interests & Tags',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: model.tags
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF2E1C44), Color(0xFF1E132D)],
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: AppColors.neonPurple.withValues(alpha: 0.4),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(
                                                color: Color(0xFFFFD1E3),
                                                fontSize: 12,
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
                          if (model.tags.isNotEmpty) const SizedBox(height: 12),

                          // Gifts Received
                          const GiftsReceivedGrid(),
                        ],
                      ),

                      // Floating Emitting Love Hearts Stack (User circled in red on right of Screenshot 3)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Render all active rising floating hearts
                            ..._hearts,

                            // Heart Reaction Glowing Base Button
                            GestureDetector(
                              onTap: _emitHeart,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF2D75), Color(0xFFFF6D00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonPink.withValues(alpha: 0.6),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
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

          // Sticky Bottom Bar matching Screenshot 3: (Hi Button + Video Call 1800/min)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.95),
                border: const Border(
                  top: BorderSide(color: AppColors.cardBorder, width: 0.8),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Hi Button (Circular purple pill on left)
                    GestureDetector(
                      onTap: _sendHiGreeting,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Hi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Audio Call Button (Circular green icon)
                    GestureDetector(
                      onTap: _startAudioCall,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.call_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Video Call Action Bar (1800/min) matching Screenshot 3
                    Expanded(
                      child: GestureDetector(
                        onTap: _startVideoCall,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E24AA), Color(0xFFE91E63)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPink.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Video Call',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${model.pricePerMin}/min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
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
