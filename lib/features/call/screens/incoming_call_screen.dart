import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/callkit_service.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/streaming_service.dart';

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
  final Map<String, dynamic>? initialSessionData;

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
    this.initialSessionData,
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
  StreamSubscription? _wsCancelledSub;
  StreamSubscription? _wsEndedSub;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    StreamingService.isCallActive = true;
    try {
      WakelockPlus.enable();
    } catch (_) {}
    AppLogger.info('WebRTC', 'INCOMING_CALL_RECEIVED');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ?. ????????? ??????? ???? ??????? ?????? ??????
    CallSoundManager.playIncomingRingtone(widget.ringtoneUrl);

    // ?. ????????? ?????? ??????? ???
    if (widget.callId != null) {
      CallApiService.confirmRinging(callId: widget.callId!);
    }

    // ?. ????????? ????-???? ? ????????? ?????
    _subscribeSignalingEvents();
    _startStatusPolling();

    // ?. ?? ??????? ????? ?? ???? ??? ???? ??
    _timeoutTimer = Timer(const Duration(seconds: 50), () {
      _stopRingtoneAndDismiss('Missed call');
    });
  }

  void _subscribeSignalingEvents() {
    _wsCancelledSub = SignalingService().onCallCancelled.listen((data) {
      final payload = (data['data'] is Map) ? data['data'] as Map<String, dynamic> : data;
      final dynamic evCallId = payload['call_id'] ?? payload['id'] ?? payload['session_id'] ?? data['call_id'] ?? data['id'];
      final dynamic evChannel = payload['channel_name'] ?? payload['room_name'] ?? payload['channel'] ?? data['channel_name'] ?? data['room_name'];
      final bool matchesCallId = evCallId != null && widget.callId != null && evCallId.toString() == widget.callId.toString();
      final bool matchesChannel = evChannel != null && widget.channelName != null && widget.channelName!.isNotEmpty && evChannel.toString() == widget.channelName.toString();
      if (!matchesCallId && !matchesChannel) return;
      _stopRingtoneAndDismiss('Call cancelled by caller');
    });
    _wsEndedSub = SignalingService().onCallEnded.listen((data) {
      final payload = (data['data'] is Map) ? data['data'] as Map<String, dynamic> : data;
      final dynamic evCallId = payload['call_id'] ?? payload['id'] ?? payload['session_id'] ?? data['call_id'] ?? data['id'];
      final dynamic evChannel = payload['channel_name'] ?? payload['room_name'] ?? payload['channel'] ?? data['channel_name'] ?? data['room_name'];
      final bool matchesCallId = evCallId != null && widget.callId != null && evCallId.toString() == widget.callId.toString();
      final bool matchesChannel = evChannel != null && widget.channelName != null && widget.channelName!.isNotEmpty && evChannel.toString() == widget.channelName.toString();
      if (!matchesCallId && !matchesChannel) return;
      _stopRingtoneAndDismiss('Call ended by caller');
    });
  }

  void _startStatusPolling() {
    if (widget.callId == null) return;
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 6000), (timer) async {
      if (!mounted || _isProcessingAction) {
        timer.cancel();
        return;
      }
      final statusData = await CallApiService.getCallStatus(
        widget.callId!,
        channelName: widget.channelName,
      );
      if (!mounted || _isProcessingAction) return;
      if (statusData != null) {
        final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
        final isRinging = statusData['is_ringing'] == true || statusData['data']?['is_ringing'] == true;
        final isActive = statusData['is_active'] == true || statusData['data']?['is_active'] == true;

        // Never dismiss if server still reports call is ringing or active
        if (isRinging || isActive) return;

        // Only dismiss if the caller explicitly cancelled the call
        if (status == 'cancelled' || status == 'caller_cancelled') {
          timer.cancel();
          _stopRingtoneAndDismiss('Call cancelled by caller');
        }
      }
    });
  }

  void _stopRingtoneAndDismiss(String reason) {
    StreamingService.isCallActive = false;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _wsCancelledSub?.cancel();
    _wsCancelledSub = null;
    _wsEndedSub?.cancel();
    _wsEndedSub = null;
    CallSoundManager.stopRingtone();
    CallkitService.endAllCalls();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    try {
      WakelockPlus.disable();
    } catch (_) {}
    if (!_isProcessingAction) {
      StreamingService.isCallActive = false;
    }
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _wsCancelledSub?.cancel();
    _wsCancelledSub = null;
    _wsEndedSub?.cancel();
    _wsEndedSub = null;
    CallSoundManager.stopRingtone();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;
    AppLogger.info('WebRTC', 'CALL_ACCEPTED');
    
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _wsCancelledSub?.cancel();
    _wsCancelledSub = null;
    _wsEndedSub?.cancel();
    _wsEndedSub = null;

    // ?????? ???? ???? ????
    CallSoundManager.stopRingtone();
    CallkitService.endAllCalls();

    final dynamic rawCallId = widget.callId ??
        widget.initialSessionData?['call_id'] ??
        widget.initialSessionData?['id'] ??
        widget.initialSessionData?['data']?['call_id'] ??
        widget.initialSessionData?['data']?['id'];
    final int? effectiveCallId = (rawCallId is int)
        ? rawCallId
        : int.tryParse(rawCallId?.toString() ?? '');

    debugPrint('[IncomingCallScreen] ?? Green Accept Button Tapped! CallId: $effectiveCallId');

    Map<String, dynamic>? acceptData;
    if (effectiveCallId != null && effectiveCallId > 0) {
      // ?? Explicitly await POST /api/call/accept to guarantee server marks call as accepted
      try {
        acceptData = await CallApiService.acceptCall(
          callId: effectiveCallId,
          channelName: widget.channelName,
        );
        debugPrint('[IncomingCallScreen] ? acceptCall response: $acceptData');
      } catch (e) {
        debugPrint('[IncomingCallScreen] ? acceptCall error: $e');
      }
    }

    if (mounted) {
      StreamingService.startDynamicCall(
        context: context,
        model: widget.model,
        callId: effectiveCallId ?? widget.callId,
        channelName: widget.channelName ?? 'incoming_call_${effectiveCallId ?? widget.model.id}',
        isFreeTrial: widget.isFreeTrial,
        freeDurationSeconds: widget.freeDurationSeconds,
        ratePerMinute: widget.ratePerMinute,
        isIncoming: true,
        initialSessionData: acceptData ?? widget.initialSessionData,
      );
    }
  }

  Future<void> _declineCall() async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _wsCancelledSub?.cancel();
    _wsCancelledSub = null;
    _wsEndedSub?.cancel();
    _wsEndedSub = null;

    await CallSoundManager.stopRingtone();
    CallkitService.endAllCalls();

    if (widget.callId != null) {
      await CallApiService.rejectCall(
        callId: widget.callId!,
        reason: 'declined',
      );
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
          // ?????? ????????????? ???
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

          // ???? ???? ?????
          // Caller Information Card
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ((widget.model.gender?.toLowerCase() ?? '') == 'male' ||
                                          (widget.initialSessionData?['caller_gender'] ?? '') == 'male' ||
                                          (widget.initialSessionData?['caller']?['gender'] ?? '') == 'male')
                                      ? const Color(0xFF2979FF)
                                      : AppColors.badgePink,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      ((widget.model.gender?.toLowerCase() ?? '') == 'male' ||
                                              (widget.initialSessionData?['caller_gender'] ?? '') == 'male' ||
                                              (widget.initialSessionData?['caller']?['gender'] ?? '') == 'male')
                                          ? Icons.male_rounded
                                          : Icons.female_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '',
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00897B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (widget.model.country.toLowerCase().contains('india') ||
                                              (widget.initialSessionData?['caller_country'] ?? '').toString().toLowerCase().contains('india'))
                                          ? '???? '
                                          : '???? ',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Text(
                                      (widget.model.country.isNotEmpty && widget.model.country != 'null')
                                          ? widget.model.country
                                          : (widget.initialSessionData?['caller_country'] ?? widget.model.location).toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
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
