import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/in_call_recharge_gems_sheet.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/webrtc_call_service.dart';
import '../widgets/webrtc_debug_modal.dart';

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
    this.freeDurationSeconds = 16,
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
  bool _hasStartedWebRTC = false;
  bool _isEndingCall = false;

  int _callSeconds = 0;
  Timer? _timer;
  Timer? _pollingTimer;
  int _userGems = 0;
  bool _isRechargeSheetOpen = false;
  bool _isVideoBlurred = false;
  bool _isFreeTrialActive = true;
  int _freeTrialRemaining = 16;
  int _ratePerMinute = 100;
  bool _isPulseInProgress = false;
  bool _hasStartedTimer = false;

  // In-call Quick Messages & Free Chances
  int _freeMessageChances = 2;
  String? _sentMessageFeedback;
  final List<String> _quickMessages = [
    'Be my girlfriend',
    "Hi , what's up babe ?",
    'Can we talk privately?',
    'You look so pretty! ❤️',
  ];

  @override
  void initState() {
    super.initState();
    _isFreeTrialActive = true;
    _freeTrialRemaining = widget.freeDurationSeconds > 0 ? widget.freeDurationSeconds : 16;
    _ratePerMinute = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

    _webrtcService.onIceStateChanged = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _onMediaConnected();
      }
    };

    if (!widget.isIncoming) {
      _isConnectingCall = true;
      CallSoundManager.playOutgoingRingtone(widget.dialToneUrl);
    } else {
      _isConnectingCall = false;
    }

    _initWebRTCMediaAndFlow();
    _loadUserBalance();
  }

  void _onMediaConnected([MediaStream? stream]) {
    if (stream != null) {
      _webrtcService.remoteRenderer.srcObject = stream;
    }
    CallSoundManager.stopRingtone();

    // Force maximum loud speakerphone audio
    _webrtcService.toggleSpeakerphone(true);
    Future.delayed(const Duration(milliseconds: 300), () {
      _webrtcService.toggleSpeakerphone(true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _webrtcService.toggleSpeakerphone(true);
    });

    if (mounted) {
      setState(() {
        _isConnectingCall = false;
      });
    }
    if (!_hasStartedTimer) {
      _hasStartedTimer = true;
      if (widget.callId != null) {
        CallApiService.notifyCallConnected(
          callId: widget.callId!,
          mediaStatus: 'connected',
        );
      }
      _startTimer();
    }
  }

  Future<void> _initWebRTCMediaAndFlow() async {
    final success = await _webrtcService.initializeMedia();
    if (!mounted) return;
    setState(() {
      _isCameraReady = success;
    });

    _webrtcService.remoteRenderer.onFirstFrameRendered = () {
      if (mounted) {
        setState(() {
          _isConnectingCall = false;
        });
      }
    };
    _webrtcService.remoteRenderer.onResize = () {
      if (mounted) setState(() {});
    };

    _startCallStatusPolling();

    if (widget.isIncoming) {
      if (widget.callId != null && !_hasStartedWebRTC) {
        _hasStartedWebRTC = true;
        await _webrtcService.startCallAsReceiver(
          callId: widget.callId,
          channelName: widget.channelName,
          onRemoteStreamConnected: (stream) {
            _onMediaConnected(stream);
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
            _onMediaConnected(stream);
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
            _isConnectingCall = false;
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
      if (!mounted) return;
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
        // 16s Free preview expired
        if (_userGems < _ratePerMinute) {
          setState(() {
            _isVideoBlurred = true;
          });
          _webrtcService.toggleMute(true);
          _showInCallRechargeSheet();
        } else if (widget.callId != null) {
          _sendInCallPulse();
        }
      } else if (widget.callId != null && _callSeconds % 60 == 0 && !_isFreeTrialActive) {
        _sendInCallPulse();
      }
    });
  }

  Future<void> _sendInCallPulse() async {
    if (_isPulseInProgress || widget.callId == null || _isRechargeSheetOpen) return;
    _isPulseInProgress = true;

    try {
      final res = await CallApiService.deductIntervalPulse(
        callId: widget.callId!,
        elapsedSeconds: _callSeconds,
        coins: _ratePerMinute,
      );

      if (!mounted) return;

      if (res['should_terminate_call'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        setState(() {
          _isVideoBlurred = true;
        });
        _webrtcService.toggleMute(true);
        _showInCallRechargeSheet();
      } else if (res['success'] == true) {
        if (res['current_coins'] != null) {
          setState(() {
            _userGems = (res['current_coins'] is int)
                ? res['current_coins']
                : int.tryParse(res['current_coins'].toString()) ?? _userGems;
            _isVideoBlurred = false;
          });
          _webrtcService.toggleMute(false);
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

  void _showInCallRechargeSheet() {
    if (_isRechargeSheetOpen) return;
    _isRechargeSheetOpen = true;

    InCallRechargeGemsSheet.show(
      context,
      model: widget.model,
      userGems: _userGems,
      ratePerMinute: _ratePerMinute,
      onClose: () {
        _isRechargeSheetOpen = false;
      },
      onRechargeSuccess: (addedGems) {
        _isRechargeSheetOpen = false;
        setState(() {
          _userGems += addedGems;
          _isVideoBlurred = false;
        });
        _webrtcService.toggleMute(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Gems added! Video call extended.'),
            backgroundColor: AppColors.onlineGreen,
            duration: Duration(seconds: 2),
          ),
        );
      },
    ).then((_) {
      _isRechargeSheetOpen = false;
    });
  }

  void _sendQuickMessage(String msg) {
    if (_freeMessageChances > 0) {
      setState(() {
        _freeMessageChances--;
        _sentMessageFeedback = msg;
      });
    } else {
      setState(() {
        _sentMessageFeedback = msg;
      });
    }

    if (widget.callId != null) {
      CallApiService.sendQuickMessage(
        callId: widget.callId!,
        receiverId: widget.model.id,
        message: msg,
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _sentMessageFeedback == msg) {
        setState(() {
          _sentMessageFeedback = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ১. মূল ফুলস্ক্রিন ভিডিও ভিউ (ঝাপসা/Blur সাপোর্টসহ)
          GestureDetector(
            onTap: () {
              setState(() {
                _isSwappedVideo = !_isSwappedVideo;
              });
            },
            child: _isVideoBlurred
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: _buildMainVideoView(),
                  )
                : _buildMainVideoView(),
          ),

          // শ্যাডো গ্রেডিয়েন্ট ওভারলে
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Color(0xDD000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ২. Ringing / Calling ইন্ডিকেটর
          if (_isConnectingCall && !_webrtcService.hasRemoteStream)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    WebRTCDebugModal.show(
                      context,
                      webrtcService: _webrtcService,
                      callId: widget.callId,
                      isIncoming: widget.isIncoming,
                      callerOrReceiverName: widget.model.name,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.9), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPink.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neonPink.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🛠️ ডিবাগ লগ',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ৩. টপ হেডার বার: ডিবাগ আইকন ও Dev Mode ব্যাজ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Host Info Capsule with Level Base Frame
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarWithFrame(
                          avatarUrl: widget.model.avatarUrl,
                          frameUrl: widget.model.avatarFrameUrl,
                          level: widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level,
                          badgeColor: widget.model.badgeColor,
                          glowColor: widget.model.glowColor,
                          size: 32,
                          showLevelBadge: false,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.model.name,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Lv.${widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level}',
                              style: TextStyle(
                                color: HexColor.fromHex(widget.model.badgeColor, defaultColor: AppColors.gemYellow),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Debug / Dev Mode Button
                  GestureDetector(
                    onTap: () {
                      WebRTCDebugModal.show(
                        context,
                        webrtcService: _webrtcService,
                        callId: widget.callId,
                        isIncoming: widget.isIncoming,
                        callerOrReceiverName: widget.model.name,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 1.2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bug_report_rounded, color: AppColors.neonPink, size: 14),
                          SizedBox(width: 4),
                          Text('Dev mode', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ৪. কর্নার PiP উইন্ডো (সেলফি ক্যামেরা + ডিউরেশন টাইমার) matching Screenshot 2 & 3
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSwappedVideo = !_isSwappedVideo;
                });
              },
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPipVideoView(),
                      // কল ডিউরেশন লেবেল (যেমন 00:06 / 00:11)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDuration(_callSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ৫. সেন্টারে ১৬ সেকেন্ড ফ্রি প্রিভিউ অ্যালার্ট ব্যানার (Screenshot 2 & 3)
          if (_isFreeTrialActive && _freeTrialRemaining > 0)
            Positioned(
              left: 20,
              right: 20,
              bottom: 230,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFFFF5722),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'After $_freeTrialRemaining seconds,you will be charged $_ratePerMinute coins per minute.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ৬. ফ্লোটিং মিনি জেম প্যাকেজ উইজেট (Screenshot 3-তে লাল দাগ দিয়ে মার্ক করা)
          Positioned(
            right: 16,
            bottom: 150,
            child: GestureDetector(
              onTap: _showInCallRechargeSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF281056), Color(0xFF6A1B9A)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 14),
                        SizedBox(width: 4),
                        Text(
                          '7560',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'BDT 150.00',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ৭. সেন্ড করা কুইক মেসেজের ফ্লোটিং টোস্ট
          if (_sentMessageFeedback != null)
            Positioned(
              bottom: 125,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neonPink, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Sent: "$_sentMessageFeedback"',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // ৮. বটম কুইক মেসেজ চিপস ও সুইচ অফ পাওয়ার বাটন (Screenshot 2 & 3)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // কুইক চ্যাট চিপস রো
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickMessages.map((msg) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _sendQuickMessage(msg),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Text(
                                msg,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ফ্রি মেসেজ চান্স লেবেল এবং কাট/পাওয়ার সুইচ বাটন (⏻)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You have $_freeMessageChances free message chances',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // পাওয়ার/কাট সুইচ বাটন (⏻)
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.65),
                            border: Border.all(color: Colors.white70, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.power_settings_new_rounded,
                            color: Colors.white,
                            size: 22,
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
      if (_isCameraReady) {
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
      if (_isCameraReady) {
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
}