import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final ModelProfile model;
  final int? callId;
  final String? channelName;
  final bool isFreeTrial;
  final int freeDurationSeconds;
  final int ratePerMinute;
  final String? ringtoneUrl;
  final String? callerName;
  final String? callerAvatar;

  const IncomingCallScreen({
    super.key,
    required this.model,
    this.callId,
    this.channelName,
    this.isFreeTrial = false,
    this.freeDurationSeconds = 10,
    this.ratePerMinute = 100,
    this.ringtoneUrl,
    this.callerName,
    this.callerAvatar,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusPollTimer;
  Timer? _timeoutTimer;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('WebRTC', 'INCOMING_CALL_RECEIVED');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ১. তাৎক্ষণিক ইনফিনিট লুপে ইনকামিং রিংটোন বাজানো
    CallSoundManager.playIncomingRingtone(widget.ringtoneUrl);

    // ২. সার্ভারকে রিংগিং কনফার্ম করা
    if (widget.callId != null) {
      CallApiService.confirmRinging(callId: widget.callId!);
    }

    // ৩. কলার কল কেটে দিলে সাথে সাথে রিসিভার স্ক্রিন ক্লোজ করার জন্য স্ট্যাটাস সিঙ্ক
    _startStatusPolling();

    // ৪. ৪৫ সেকেন্ড উত্তর না দিলে অটো মিসড কল
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      _stopRingtoneAndDismiss('Missed call');
    });
  }

  void _startStatusPolling() {
    if (widget.callId == null) return;
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) async {
      final statusData = await CallApiService.getCallStatus(widget.callId!);
      if (!mounted) return;
      if (statusData != null) {
        final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
        final isTerminated = statusData['is_terminated'] == true || statusData['data']?['is_terminated'] == true;
        
        if (status == 'cancelled' || status == 'ended' || status == 'rejected' || isTerminated) {
          timer.cancel();
          _stopRingtoneAndDismiss('Call cancelled by caller');
        }
      }
    });
  }

  void _stopRingtoneAndDismiss(String reason) {
    _statusPollTimer?.cancel();
    _timeoutTimer?.cancel();
    CallSoundManager.stopRingtone();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _timeoutTimer?.cancel();
    CallSoundManager.stopRingtone();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;
    AppLogger.info('WebRTC', 'CALL_ACCEPTED');
    
    _statusPollTimer?.cancel();
    _timeoutTimer?.cancel();

    // রিংটোন সাথে সাথে বন্ধ
    CallSoundManager.stopRingtone();

    // ব্যাকএন্ডে রিসিভ বাটন প্রেস নোটিফাই করা (অ্যাসিনক্রোনাসলি ব্যাকগ্রাউন্ডে)
    if (widget.callId != null) {
      unawaited(CallApiService.acceptCall(callId: widget.callId!));
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            model: widget.model,
            callId: widget.callId,
            channelName: widget.channelName,
            isFreeTrial: widget.isFreeTrial,
            freeDurationSeconds: widget.freeDurationSeconds,
            ratePerMinute: widget.ratePerMinute,
            isIncoming: true, // রিসিভার মোড সক্রিয়
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;
    _statusPollTimer?.cancel();
    _timeoutTimer?.cancel();

    await CallSoundManager.stopRingtone();

    if (widget.callId != null) {
      await CallApiService.rejectCall(callId: widget.callId!);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call from ${widget.model.name} declined'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.callerAvatar ?? widget.model.avatarUrl;
    final displayName = widget.callerName ?? widget.model.name;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // কলারের ব্যাকগ্রাউন্ড ছবি
          CachedImageLoader(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
          ),
          
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x77000000),
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.4, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // কলার ইনফো কার্ড
          Positioned(
            left: 24,
            bottom: 180,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.neonPink, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedImageLoader(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.badgePink,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.female_rounded, color: Colors.white, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${widget.model.age}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${widget.model.location} Division',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'VIDEO NOW!',
                    style: TextStyle(
                      color: AppColors.gemYellow,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Video chat request received!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // কল রিসিভ ও ডিক্লাইন বাটন
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _declineCall,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF2D55),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: GestureDetector(
                        onTap: _acceptCall,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E676),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}