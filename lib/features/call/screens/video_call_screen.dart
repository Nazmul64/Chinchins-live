import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/continue_call_recharge_dialog.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/webrtc_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final ModelProfile model;
  final int? callId;
  final bool isFreeTrial;
  final int freeDurationSeconds;

  const VideoCallScreen({
    super.key,
    required this.model,
    this.callId,
    this.isFreeTrial = false,
    this.freeDurationSeconds = 10,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCCallService _webrtcService = WebRTCCallService();
  bool _isCameraReady = false;
  bool _isConnectingCall = true;

  int _callSeconds = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isBeautyFilterOn = true;
  String? _activeGiftShower;
  int _userGems = 0;
  bool _isRechargeDialogVisible = false;
  bool _isFreeTrialActive = false;
  int _freeTrialRemaining = 0;
  int _ratePerMinute = 100;
  bool _isPulseInProgress = false;

  @override
  void initState() {
    super.initState();
    _isFreeTrialActive = widget.isFreeTrial;
    _freeTrialRemaining = widget.freeDurationSeconds;
    _ratePerMinute = widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100;

    _playDialingTone();
    _initWebRTCMedia();
    _loadUserBalance();
    _connectCallSession();
    _startTimer();
  }

  Future<void> _playDialingTone() async {
    await CallSoundManager.playOutgoingRingtone();
    // Stop dialing tone after 2.5 seconds as receiver connects
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        CallSoundManager.stopRingtone();
        setState(() {
          _isConnectingCall = false;
        });
      }
    });
  }

  Future<void> _initWebRTCMedia() async {
    final success = await _webrtcService.initializeMedia();
    if (mounted) {
      setState(() {
        _isCameraReady = success;
      });
    }
  }

  Future<void> _loadUserBalance() async {
    final balanceData = await WalletApiService.getWalletBalance();
    if (balanceData != null && mounted) {
      final coinsVal = balanceData['coins'] ?? balanceData['user_coins'] ?? balanceData['current_coins'];
      setState(() {
        _userGems = coinsVal is int
            ? coinsVal
            : int.tryParse(coinsVal?.toString() ?? '0') ?? 0;
      });
    }
  }

  Future<void> _connectCallSession() async {
    if (widget.callId != null) {
      await CallApiService.startCall(callId: widget.callId!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CallSoundManager.stopRingtone();
    _webrtcService.dispose();
    if (widget.callId != null) {
      CallApiService.endCall(
        callId: widget.callId!,
        durationSeconds: _callSeconds,
      );
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callSeconds++;
          if (_isFreeTrialActive && _freeTrialRemaining > 0) {
            _freeTrialRemaining--;
            if (_freeTrialRemaining <= 0) {
              _isFreeTrialActive = false;
            }
          }
        });

        // In-call pulse billing every 10 seconds or when free trial finishes
        if (widget.callId != null && (_callSeconds % 10 == 0 || (_freeTrialRemaining == 0 && _isFreeTrialActive))) {
          _sendInCallPulse();
        }
      }
    });
  }

  Future<void> _sendInCallPulse() async {
    if (_isPulseInProgress || widget.callId == null || _isRechargeDialogVisible) return;
    _isPulseInProgress = true;

    try {
      final res = await CallApiService.deductIntervalPulse(
        callId: widget.callId!,
        elapsedSeconds: _callSeconds,
        coins: _ratePerMinute,
      );

      if (!mounted) return;

      if (res['should_terminate_call'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        _showRechargePopup();
      } else if (res['success'] == true) {
        if (res['current_coins'] != null) {
          setState(() {
            _userGems = (res['current_coins'] is int)
                ? res['current_coins']
                : int.tryParse(res['current_coins'].toString()) ?? _userGems;
          });
        }
      }
    } catch (_) {}
    _isPulseInProgress = false;
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showGiftShower(GiftItem gift) {
    setState(() {
      _activeGiftShower = gift.emoji;
      _userGems -= gift.coins;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _activeGiftShower = null;
        });
      }
    });
  }

  void _showRechargePopup() {
    CallSoundManager.stopRingtone();
    setState(() {
      _isRechargeDialogVisible = true;
    });
  }

  void _hideRechargePopupAndEndCall() {
    setState(() {
      _isRechargeDialogVisible = false;
    });
    Navigator.pop(context);
  }

  void _onGetCoinsSuccess() {
    setState(() {
      _userGems += 7560;
      _isRechargeDialogVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 7,560 Gems added! Video call extended.'),
        backgroundColor: AppColors.onlineGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Host Video Stream Feed (Live Remote Stream or Live Profile)
          if (_webrtcService.remoteStream != null)
            RTCVideoView(
              _webrtcService.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            CachedImageLoader(
              imageUrl: widget.model.avatarUrl,
              fit: BoxFit.cover,
            ),

          // Dark overlay gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.4, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Connecting indicator / Ringing badge
          if (_isConnectingCall)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Ringing & Connecting...',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Animated Gift Overlay
          if (_activeGiftShower != null)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1.6),
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
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 3. Top Call Duration & "Continue Video Call" Pills matching Screenshot
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Top Row: Host Pill + Gems + Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Host Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(widget.model.avatarUrl),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.model.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top Timer Box matching Screenshot (01:19)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gemYellow.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$_userGems',
                                  style: const TextStyle(
                                    color: AppColors.gemYellow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Text(
                              _formatDuration(_callSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isFreeTrialActive && _freeTrialRemaining > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.orangeGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            '🎉 Free Trial Active: ${_freeTrialRemaining}s free',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // "Continue Video Call 💎 Rate/min" Pill matching Screenshot
                  GestureDetector(
                    onTap: _showRechargePopup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Continue Video Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.model.pricePerMin}/min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),

          // 4. Floating Real Self-Camera Preview (Top Right)
          if (!_isRechargeDialogVisible)
            Positioned(
              top: 140,
              right: 16,
              child: Container(
                width: 105,
                height: 145,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 2.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: const Color(0xFF1E1830),
                        child: _isCameraOff
                            ? const Center(
                                child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
                              )
                            : _isCameraReady
                                ? RTCVideoView(
                                    _webrtcService.localRenderer,
                                    mirror: true,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                                  ),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Bottom Call Controls (shown when recharge popup is closed)
          if (!_isRechargeDialogVisible)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Beauty Filter Toggle
                    _buildCallControlButton(
                      icon: Icons.auto_fix_high_rounded,
                      isActive: _isBeautyFilterOn,
                      activeColor: AppColors.neonPurple,
                      onTap: () {
                        setState(() {
                          _isBeautyFilterOn = !_isBeautyFilterOn;
                        });
                      },
                    ),

                    // Mic Toggle
                    _buildCallControlButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: !_isMuted,
                      activeColor: Colors.white24,
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        _webrtcService.toggleMute(_isMuted);
                      },
                    ),

                    // End Call Button (Big Red) -> Hangs up
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 64,
                        height: 64,
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
                          size: 32,
                        ),
                      ),
                    ),

                    // Camera Toggle (On / Off)
                    _buildCallControlButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isActive: !_isCameraOff,
                      activeColor: Colors.white24,
                      onTap: () {
                        setState(() {
                          _isCameraOff = !_isCameraOff;
                        });
                        _webrtcService.toggleCamera(_isCameraOff);
                      },
                    ),

                    // Send Live Gift Button
                    _buildCallControlButton(
                      icon: Icons.card_giftcard_rounded,
                      isActive: true,
                      activeColor: AppColors.warmOrange,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => GiftPickerModal(
                            onGiftSelected: _showGiftShower,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // 6. Centered Overlaid Dialog matching Screenshot
          if (_isRechargeDialogVisible)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: ContinueCallRechargeDialog(
                  model: widget.model,
                  durationText: _formatDuration(_callSeconds),
                  onClose: _hideRechargePopupAndEndCall,
                  onGetCoins: _onGetCoinsSuccess,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : Colors.black45,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
