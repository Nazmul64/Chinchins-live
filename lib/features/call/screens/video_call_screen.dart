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
  final String? channelName;
  final bool isFreeTrial;
  final int freeDurationSeconds;
  final int ratePerMinute;
  final bool isIncoming;
  final String? dialToneUrl;

  const VideoCallScreen({
    super.key,
    required this.model,
    this.callId,
    this.channelName,
    this.isFreeTrial = false,
    this.freeDurationSeconds = 10,
    this.ratePerMinute = 100,
    this.isIncoming = false,
    this.dialToneUrl,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCCallService _webrtcService = WebRTCCallService();
  bool _isCameraReady = false;
  bool _isConnectingCall = true;
  bool _isSwappedVideo = false;
  bool _isSpeakerOn = true;
  bool _hasStartedWebRTC = false;
  bool _isEndingCall = false;

  bool _showDebugOverlay = true;
  bool _isLogsExpanded = true;

  int _callSeconds = 0;
  Timer? _timer;
  Timer? _pollingTimer;
  bool _isMuted = false;
  bool _isCameraOff = false;
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
    _ratePerMinute = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

    _webrtcService.onDebugUpdate = () {
      if (mounted) setState(() {});
    };

    if (!widget.isIncoming) {
      _isConnectingCall = true;
      CallSoundManager.playOutgoingRingtone(widget.dialToneUrl);
    } else {
      _isConnectingCall = false; // রিসিভারের ক্ষেত্রে ডায়াল টোন বন্ধ থাকবে
    }

    _initWebRTCMediaAndFlow();
    _loadUserBalance();
  }

  Future<void> _initWebRTCMediaAndFlow() async {
    final success = await _webrtcService.initializeMedia();
    if (!mounted) return;
    setState(() {
      _isCameraReady = success;
      _isSpeakerOn = _webrtcService.isSpeakerOn;
    });

    _startCallStatusPolling();

    if (widget.isIncoming) {
      if (widget.callId != null && !_hasStartedWebRTC) {
        _hasStartedWebRTC = true;
        await _webrtcService.startCallAsReceiver(
          callId: widget.callId,
          channelName: widget.channelName,
          onRemoteStreamConnected: (stream) {
            if (mounted) {
              setState(() {
                _isConnectingCall = false;
                _webrtcService.remoteRenderer.srcObject = stream;
              });
              _startTimer();
            }
          },
          onCallEnded: () {
            if (mounted && !_isEndingCall) {
              _isEndingCall = true;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call ended'),
                  backgroundColor: AppColors.cardDarkElevated,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }
    } else {
      if (widget.callId != null && !_hasStartedWebRTC) {
        _hasStartedWebRTC = true;
        await _webrtcService.startCallAsCaller(
          callId: widget.callId,
          channelName: widget.channelName,
          onRemoteStreamConnected: (stream) {
            if (mounted) {
              CallSoundManager.stopRingtone();
              setState(() {
                _isConnectingCall = false;
                _webrtcService.remoteRenderer.srcObject = stream;
              });
              _startTimer();
            }
          },
          onCallEnded: () {
            if (mounted && !_isEndingCall) {
              _isEndingCall = true;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call ended'),
                  backgroundColor: AppColors.cardDarkElevated,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }
    }
  }

  void _startCallStatusPolling() {
    if (widget.callId == null) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!mounted || _isEndingCall) {
        timer.cancel();
        return;
      }

      final statusData = await CallApiService.getCallStatus(widget.callId!);
      if (!mounted || statusData == null) return;

      final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
      final isTerminated = statusData['is_terminated'] == true || statusData['data']?['is_terminated'] == true;

      if (status == 'rejected') {
        timer.cancel();
        await CallSoundManager.stopRingtone();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Host declined the call'),
              backgroundColor: AppColors.cardDarkElevated,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status == 'cancelled') {
        timer.cancel();
        await CallSoundManager.stopRingtone();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call was cancelled'),
              backgroundColor: AppColors.cardDarkElevated,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status == 'ended' || isTerminated) {
        timer.cancel();
        await CallSoundManager.stopRingtone();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call ended'),
              backgroundColor: AppColors.cardDarkElevated,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status == 'connected' || status == 'active' || status == 'accepted') {
        await CallSoundManager.stopRingtone();
        if (_isConnectingCall) {
          setState(() {
            _isConnectingCall = false; // "Calling..." ওভারলে সাথে সাথে দূর হবে
          });
        }
      }
    });
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

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    _timer?.cancel();
    _pollingTimer?.cancel();
    await CallSoundManager.stopRingtone();

    if (widget.callId != null) {
      if (_isConnectingCall || _callSeconds <= 0) {
        await CallApiService.cancelCall(callId: widget.callId!);
      } else {
        await CallApiService.endCall(
          callId: widget.callId!,
          durationSeconds: _callSeconds,
        );
      }
    }

    await _webrtcService.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    CallSoundManager.stopRingtone();
    _webrtcService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        bool trialJustEnded = false;
        setState(() {
          _callSeconds++;
          if (_isFreeTrialActive && _freeTrialRemaining > 0) {
            _freeTrialRemaining--;
            if (_freeTrialRemaining <= 0) {
              _isFreeTrialActive = false;
              trialJustEnded = true;
            }
          }
        });

        if (trialJustEnded) {
          // Free trial completed (10 seconds)
          if (_userGems < _ratePerMinute) {
            // Insufficient coins after free trial -> immediately prompt recharge
            _showRechargePopup();
          } else if (widget.callId != null) {
            _sendInCallPulse();
          }
        } else if (widget.callId != null && _callSeconds % 60 == 0 && !_isFreeTrialActive) {
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
    _endCall();
  }

  void _onGetCoinsSuccess() {
    setState(() {
      _userGems += 7560;
      _isRechargeDialogVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Gems added! Video call extended.'),
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
          // ১. মূল ফুলস্ক্রিন ভিডিও ভিউ
          GestureDetector(
            onTap: () {
              setState(() {
                _isSwappedVideo = !_isSwappedVideo;
              });
            },
            child: _buildMainVideoView(),
          ),

          IgnorePointer(
            child: Container(
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
          ),

          // ২. Ringing / Calling ইন্ডিকেটর (কানেক্ট হলে বা রিমোট স্ট্রিম এলে স্বয়ংক্রিয়ভাবে হাইড হবে)
          if (_isConnectingCall && !_webrtcService.hasRemoteStream)
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.model.isOnline ? 'Ringing...' : 'Calling...',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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

          // ৩. টপ হেডার বার (টাইমার, জেমস ও মডেল ইনফো)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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

          // ৪. কর্নার PiP উইন্ডো (নিজের সেলফি ক্যামেরা)
          if (!_isRechargeDialogVisible)
            Positioned(
              top: 140,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSwappedVideo = !_isSwappedVideo;
                  });
                },
                child: Container(
                  width: 110,
                  height: 155,
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
                        _buildPipVideoView(),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  _isSwappedVideo ? widget.model.name : 'You',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ৫. বটম কল কন্ট্রোলস
          if (!_isRechargeDialogVisible)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCallControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        isActive: true,
                        activeColor: Colors.white24,
                        onTap: () {
                          _webrtcService.switchCamera();
                        },
                      ),
                      _buildCallControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        isActive: _isSpeakerOn,
                        activeColor: _isSpeakerOn ? const Color(0xFF00E676) : Colors.white24,
                        onTap: () {
                          setState(() {
                            _isSpeakerOn = !_isSpeakerOn;
                          });
                          _webrtcService.toggleSpeakerphone(_isSpeakerOn);
                        },
                      ),
                      _buildCallControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: !_isMuted,
                        activeColor: _isMuted ? const Color(0xFFFF2D55) : Colors.white24,
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                          _webrtcService.toggleMute(_isMuted);
                        },
                      ),
                      GestureDetector(
                        onTap: _endCall,
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
                      _buildCallControlButton(
                        icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        isActive: !_isCameraOff,
                        activeColor: _isCameraOff ? const Color(0xFFFF2D55) : Colors.white24,
                        onTap: () {
                          setState(() {
                            _isCameraOff = !_isCameraOff;
                          });
                          _webrtcService.toggleCamera(_isCameraOff);
                        },
                      ),
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
            ),

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

          if (!_isRechargeDialogVisible)
            _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainVideoView() {
    if (!_isSwappedVideo) {
      if (_webrtcService.hasRemoteStream) {
        return RTCVideoView(
          _webrtcService.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        return CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
        );
      }
    } else {
      if (_isCameraOff) {
        return Container(
          color: const Color(0xFF151026),
          child: const Center(
            child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
          ),
        );
      } else if (_isCameraReady) {
        return RTCVideoView(
          _webrtcService.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.neonPink),
        );
      }
    }
  }

  Widget _buildPipVideoView() {
    if (!_isSwappedVideo) {
      if (_isCameraOff) {
        return Container(
          color: const Color(0xFF1E1830),
          child: const Center(
            child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
          ),
        );
      } else if (_isCameraReady) {
        return RTCVideoView(
          _webrtcService.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
        );
      }
    } else {
      if (_webrtcService.hasRemoteStream) {
        return RTCVideoView(
          _webrtcService.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        return CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
        );
      }
    }
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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activeColor,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDebugOverlay() {
    if (!_showDebugOverlay) {
      return Positioned(
        top: 140,
        left: 16,
        child: GestureDetector(
          onTap: () => setState(() => _showDebugOverlay = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neonPink, width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bug_report_rounded, color: AppColors.neonPink, size: 14),
                SizedBox(width: 4),
                Text('Debug', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final pcConnected = _webrtcService.pcState.toLowerCase().contains('connected');
    final iceConnected = _webrtcService.iceState.toLowerCase().contains('connected') || _webrtcService.iceState.toLowerCase().contains('completed');

    return Positioned(
      top: 140,
      left: 12,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.62,
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xE6100B20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bug_report_rounded, color: AppColors.neonPink, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.isIncoming ? 'RECEIVER DEBUG' : 'CALLER DEBUG',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isLogsExpanded = !_isLogsExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isLogsExpanded ? AppColors.neonPink : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isLogsExpanded ? 'Logs ▲' : 'Logs ▼',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _showDebugOverlay = false),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildDebugChip('PC', _webrtcService.pcState, pcConnected ? Colors.green : Colors.amber),
                _buildDebugChip('ICE', _webrtcService.iceState, iceConnected ? Colors.green : Colors.amber),
                _buildDebugChip('Offer', _webrtcService.offerState, Colors.cyan),
                _buildDebugChip('Answer', _webrtcService.answerState, Colors.purpleAccent),
                _buildDebugChip('Cand', 'S:${_webrtcService.iceCandidatesSent} R:${_webrtcService.iceCandidatesReceived}', Colors.blueAccent),
                _buildDebugChip('Remote', _webrtcService.hasRemoteStream ? 'Attached ✅' : 'Waiting ⏳', _webrtcService.hasRemoteStream ? Colors.green : Colors.orange),
              ],
            ),
            if (_webrtcService.lastError != 'None') ...[
              const SizedBox(height: 4),
              Text(
                'Err: ${_webrtcService.lastError}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (_isLogsExpanded) ...[
              const SizedBox(height: 6),
              const Text('Real-Time Event Stream:', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _webrtcService.debugLogs.length,
                    itemBuilder: (context, index) {
                      final log = _webrtcService.debugLogs[index];
                      final isErr = log.contains('ERROR') || log.contains('Error');
                      final isOk = log.contains('attached') || log.contains('SENT') || log.contains('successfully');
                      return Text(
                        log,
                        style: TextStyle(
                          color: isErr ? Colors.redAccent : (isOk ? Colors.greenAccent : Colors.white70),
                          fontSize: 8.5,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugChip(String label, String value, Color color) { 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}