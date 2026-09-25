import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../main.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/in_call_recharge_gems_sheet.dart';
import '../../../core/services/signaling_service.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/webrtc_call_service.dart';
import '../services/beauty_filter_engine.dart';
import '../services/pip_call_overlay.dart';
import '../widgets/webrtc_debug_modal.dart';
import '../widgets/camera_filter_tray.dart';
import '../widgets/in_call_profile_sheet.dart';
import '../widgets/in_call_chat_overlay.dart';
import '../widgets/in_call_gift_sheet.dart';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/call_end_confirmation_dialog.dart';

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

class ActiveWebRTCSession {
  final String? channelName;
  final WebRTCCallService webrtcService;
  final int callSeconds;
  final bool isConnectingCall;
  final bool isSwappedVideo;
  final bool isVideoBlurred;

  ActiveWebRTCSession({
    this.channelName,
    required this.webrtcService,
    required this.callSeconds,
    required this.isConnectingCall,
    required this.isSwappedVideo,
    required this.isVideoBlurred,
  });
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  static ActiveWebRTCSession? _activeSession;

  late final WebRTCCallService _webrtcService;
  final GlobalKey<GiftAnimationOverlayState> _giftAnimKey = GlobalKey<GiftAnimationOverlayState>();
  final GlobalKey<InCallChatOverlayState> _chatKey = GlobalKey<InCallChatOverlayState>();

  FilterPreset _currentFilter = BeautyFilterEngine.presets[1]; // Default to Beauty Glow (HD radiant skin)

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

  StreamSubscription? _wsEndedSub;
  StreamSubscription? _wsRejectedSub;
  StreamSubscription? _wsCancelledSub;
  StreamSubscription? _wsInCallMsgSub;
  StreamSubscription? _wsGiftSub;

  // In-call Quick Messages & Free Chances
  int _freeMessageChances = 2;
  String? _sentMessageFeedback;
  final List<String> _quickMessages = [
    'Be my girlfriend',
    "Hi , what's up babe ?",
    'Can we talk privately?',
    'You look so pretty! ❤️',
  ];

  Map<String, dynamic>? _featuredPackage;

  @override
  void initState() {
    super.initState();
    _isFreeTrialActive = true;
    _freeTrialRemaining = widget.freeDurationSeconds > 0 ? widget.freeDurationSeconds : 16;
    _ratePerMinute = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

    if (_activeSession != null && _activeSession!.channelName == widget.channelName) {
      _webrtcService = _activeSession!.webrtcService;
      _callSeconds = _activeSession!.callSeconds;
      _isConnectingCall = _activeSession!.isConnectingCall;
      _isSwappedVideo = _activeSession!.isSwappedVideo;
      _isVideoBlurred = _activeSession!.isVideoBlurred;
      _isCameraReady = true;
      _hasStartedWebRTC = true;
      _activeSession = null;
      _startTimer();
    } else {
      _webrtcService = WebRTCCallService();
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
    }

    _loadUserBalance();
    _loadFeaturedPackage();
    _loadCallConfig();
    _subscribeSignalingEvents();
  }

  void _subscribeSignalingEvents() {
    final signaling = SignalingService();
    if (widget.callId != null) {
      signaling.subscribeToCallRoom(widget.callId.toString());
    }
    if (widget.channelName != null && widget.channelName!.isNotEmpty && widget.channelName != widget.callId?.toString()) {
      signaling.subscribeToCallRoom(widget.channelName!);
    }

    _wsEndedSub = signaling.onCallEnded.listen((data) {
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsRejectedSub = signaling.onCallRejected.listen((data) {
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsCancelledSub = signaling.onCallCancelled.listen((data) {
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsInCallMsgSub = signaling.onInCallMessage.listen((data) {
      if (mounted) {
        _chatKey.currentState?.addIncomingMessage(data);
      }
    });

    _wsGiftSub = signaling.onLiveGift.listen((data) {
      debugPrint('[VideoCallScreen] Received Gift via WebSocket: $data');
      final giftData = data['gift_data'] ?? data['gift'];
      final giftName = (giftData is Map ? giftData['name'] : null) ?? data['gift_name'] ?? 'Luxury Gift';
      final coins = data['total_coins'] ?? (giftData is Map ? giftData['coin_price'] : null) ?? data['coins'] ?? 100;
      final animUrl = (giftData is Map ? (giftData['animation_asset_url'] ?? giftData['icon_url']) : null) ??
          data['animation_url']?.toString() ?? data['animation_asset_url']?.toString() ?? data['image_url']?.toString();
      final senderName = data['sender_name'] ?? data['user_name'] ?? data['sender']?['name'] ?? 'Partner';

      if (mounted) {
        _giftAnimKey.currentState?.playGiftAnimationDynamic(
          giftName: giftName,
          animationUrl: animUrl,
          senderName: senderName,
          coins: coins is int ? coins : int.tryParse('$coins') ?? 100,
        );

        _chatKey.currentState?.addIncomingMessage({
          'id': 'gift_${DateTime.now().millisecondsSinceEpoch}',
          'sender_name': senderName,
          'message': '🎁 sent $giftName ($coins Coins)!',
          'type': 'gift',
          'is_me': false,
        });
      }
    });
  }

  Future<void> _loadCallConfig() async {
    try {
      final cfg = await CallApiService.getCallConfig();
      if (cfg != null && mounted) {
        final dynamic freeSecs = cfg['free_trial_duration_seconds'] ?? cfg['free_duration_seconds'] ?? cfg['free_trial_seconds'];
        if (freeSecs != null) {
          final parsed = int.tryParse(freeSecs.toString());
          if (parsed != null && parsed > 0 && _callSeconds == 0) {
            setState(() {
              _freeTrialRemaining = parsed;
            });
          }
        }
        final dynamic rpm = cfg['video_call_rate'] ?? cfg['rate_per_minute'];
        if (rpm != null) {
          final parsedRpm = int.tryParse(rpm.toString());
          if (parsedRpm != null && parsedRpm > 0) {
            setState(() {
              _ratePerMinute = parsedRpm;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFeaturedPackage() async {
    try {
      final packages = await WalletApiService.getCoinPackages();
      if (packages.isNotEmpty && mounted) {
        setState(() {
          _featuredPackage = packages.first;
        });
      }
    } catch (_) {}
  }

  void _onMediaConnected([MediaStream? stream]) {
    if (stream != null && _webrtcService.remoteRenderer.srcObject != stream) {
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

  static void _endActiveSession({int? callId, int? durationSeconds}) async {
    if (_activeSession != null) {
      try {
        await _activeSession!.webrtcService.dispose();
      } catch (_) {}
      _activeSession = null;
    }
    if (callId != null) {
      try {
        await CallApiService.endCall(callId: callId, durationSeconds: durationSeconds ?? 0);
      } catch (_) {}
    }
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;
    _timer?.cancel();
    _pollingTimer?.cancel();
    _wsEndedSub?.cancel();
    _wsRejectedSub?.cancel();
    _wsCancelledSub?.cancel();
    _wsInCallMsgSub?.cancel();
    _wsGiftSub?.cancel();
    await CallSoundManager.stopRingtone();

    // ⚡ 1. Instantly close screen (0.00ms delay)
    if (mounted) Navigator.pop(context);

    // 2. Perform API end/cancel and WebRTC cleanup in background
    final callId = widget.callId;
    final isConnecting = _isConnectingCall;
    final callSecs = _callSeconds;
    final webrtc = _webrtcService;

    Future.microtask(() async {
      try {
        if (callId != null) {
          if (isConnecting || callSecs <= 0) {
            await CallApiService.cancelCall(callId: callId);
          } else {
            await CallApiService.endCall(
              callId: callId,
              durationSeconds: callSecs,
            );
          }
        }
        await webrtc.dispose();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    _wsEndedSub?.cancel();
    _wsRejectedSub?.cancel();
    _wsCancelledSub?.cancel();
    _wsInCallMsgSub?.cancel();
    CallSoundManager.stopRingtone();

    if (PiPCallOverlay.isMinimized && _activeSession != null) {
      debugPrint('[VideoCallScreen] Preserving active WebRTC session for PiP overlay');
    } else {
      _isEndingCall = true;
      _webrtcService.dispose();
      _activeSession = null;
    }
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
          _webrtcService.setCallMuted(true);
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
        _webrtcService.setCallMuted(true);
        _showInCallRechargeSheet();
      } else if (res['success'] == true) {
        if (res['current_coins'] != null) {
          setState(() {
            _userGems = (res['current_coins'] is int)
                ? res['current_coins']
                : int.tryParse(res['current_coins'].toString()) ?? _userGems;
            _isVideoBlurred = false;
          });
          _webrtcService.setCallMuted(false);
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
        if (_userGems < _ratePerMinute && mounted) {
          setState(() {
            _isVideoBlurred = true;
          });
          _webrtcService.setCallMuted(true);
        }
      },
      onRechargeSuccess: (addedGems) {
        _isRechargeSheetOpen = false;
        setState(() {
          _userGems += addedGems;
          _isVideoBlurred = false;
        });
        _webrtcService.setCallMuted(false);
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
      if (_userGems < _ratePerMinute && mounted) {
        setState(() {
          _isVideoBlurred = true;
        });
        _webrtcService.setCallMuted(true);
      }
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

    _chatKey.currentState?.addIncomingMessage({
      'sender_name': 'You',
      'message': msg,
      'is_me': true,
      'type': 'quick_reply',
      'created_at': DateTime.now().toIso8601String(),
    });

    final dynamic sessionId = widget.callId ?? widget.channelName;
    if (sessionId != null) {
      CallApiService.sendCallChatMessage(
        callSessionId: sessionId,
        receiverId: widget.model.id,
        message: msg,
        type: 'quick_reply',
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

  Future<void> _handleUserHangup() async {
    if (!_isConnectingCall && _callSeconds > 0) {
      final shouldEnd = await showCallEndConfirmationDialog(
        context,
        peerName: widget.model.name,
      );
      if (shouldEnd != true) return;
    }
    _endCall();
  }

  void _minimizeToPiP() {
    _activeSession = ActiveWebRTCSession(
      channelName: widget.channelName,
      webrtcService: _webrtcService,
      callSeconds: _callSeconds,
      isConnectingCall: _isConnectingCall,
      isSwappedVideo: _isSwappedVideo,
      isVideoBlurred: _isVideoBlurred,
    );

    PiPCallOverlay.showMiniWindow(
      context,
      remoteVideoView: RepaintBoundary(child: _buildMainVideoView()),
      peerName: widget.model.name,
      callDurationText: _formatDuration(_callSeconds),
      callSessionId: widget.callId ?? widget.channelName,
      onTapRestore: () {
        final navState = ChinchinsLiveApp.navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
        navState.push(
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              model: widget.model,
              callId: widget.callId,
              channelName: widget.channelName,
              isIncoming: widget.isIncoming,
              dialToneUrl: widget.dialToneUrl,
              freeDurationSeconds: widget.freeDurationSeconds,
              ratePerMinute: widget.ratePerMinute,
              isFreeTrial: widget.isFreeTrial,
            ),
          ),
        );
      },
      onEndCall: () {
        _endActiveSession(callId: widget.callId, durationSeconds: _callSeconds);
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _minimizeToPiP();
        }
      },
      child: GiftAnimationOverlay(
        key: _giftAnimKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ১. মূল ফুলস্ক্রিন ভিডিও ভিউ (ঝাপসা/Blur ও বিউটি ফিল্টার সাপোর্টসহ)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSwappedVideo = !_isSwappedVideo;
                  });
                },
                child: _isVideoBlurred
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMainVideoView(),
                            Container(color: Colors.black.withValues(alpha: 0.65)),
                          ],
                        ),
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

              // ২. Ringing / Calling ডিবাগ ইন্ডিকেটর (কেবলমাত্র অ্যাডমিন থেকে Debug Mode On থাকলে প্রদর্শিত হবে)
              if (_isConnectingCall && !_webrtcService.hasRemoteStream && RemoteConfigService.instance.config.isDebugHudEnabled)
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

              // ৩. টপ হেডার বার: ব্যাক/ডাউন অ্যারো + হোস্ট প্রোফাইল ক্যাপসুল (টপ-লেফটে) এবং PiP উইন্ডো (টপ-রাইটে)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Down Arrow (⌄) [Minimizes to PiP without dropping call] + Host Profile Capsule
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 34),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: _minimizeToPiP,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              InCallProfileSheet.show(context, model: widget.model);
                            },
                            child: Container(
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
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Right: PiP Window (Single Clean Instance with Timer) + Dev Mode Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
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
                                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
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
                                    // Call Duration Timer Label
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ৪. রাইট সাইডবারে ইন-কল কুইক অ্যাকশন বোতাম (ফিল্টার, লাইভ চ্যাট ও গিফট)
              Positioned(
                right: 14,
                bottom: 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✨ TikTok-Style Beauty Filters Button
                    _buildFloatingActionButton(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Beauty',
                      color: AppColors.neonPink,
                      onTap: () {
                        CameraFilterTray.show(
                          context,
                          currentFilter: _currentFilter,
                          onFilterSelected: (preset) {
                            setState(() => _currentFilter = preset);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 💬 In-Call Live Chat Drawer Toggle Button
                    _buildFloatingActionButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                      color: const Color(0xFF00E5FF),
                      onTap: () {
                        _chatKey.currentState?.toggleChatDrawer();
                      },
                    ),
                    const SizedBox(height: 12),

                    // 🎁 Virtual Luxury Gifts Button
                    _buildFloatingActionButton(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Gift',
                      color: const Color(0xFFFFD54F),
                      onTap: () {
                        InCallGiftSheet.show(
                          context,
                          receiverId: widget.model.id,
                          receiverName: widget.model.name,
                          callSessionId: widget.callId ?? widget.channelName,
                          onGiftSent: (anim) {
                            _giftAnimKey.currentState?.playGiftAnimation(anim);
                            _chatKey.currentState?.addIncomingMessage({
                              'id': 'gift_${DateTime.now().millisecondsSinceEpoch}',
                              'sender_name': 'You',
                              'message': '🎁 sent ${anim.giftName} (${anim.coins} Coins)!',
                              'type': 'gift',
                              'is_me': true,
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // ফ্লোটিং মিনি জেম প্যাকেজ উইজেট
                    GestureDetector(
                      onTap: _showInCallRechargeSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF281056), Color(0xFF6A1B9A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '${_featuredPackage?['coins'] ?? _featuredPackage?['amount'] ?? 32000}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

              // ৫. ইন-কল লাইভ চ্যাট, কুইক মেসেজ এবং বটম কন্ট্রোল (একক রেসপনসিভ কলাম)
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // কুইক মেসেজ সেন্ড ফিডব্যাক টোস্ট
                      if (_sentMessageFeedback != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
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

                      // ইন-কল লাইভ চ্যাট ওভারলে (বাম পাশে রেন্ডার হবে যাতে ডানের বোতামগুলো ওভারল্যাপ না হয়)
                      Padding(
                        padding: const EdgeInsets.only(right: 64),
                        child: InCallChatOverlay(
                          key: _chatKey,
                          callSessionId: widget.callId ?? widget.channelName,
                          receiverId: widget.model.id,
                          receiverName: widget.model.name,
                        ),
                      ),
                      const SizedBox(height: 8),

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
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
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
                            onTap: _handleUserHangup,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(color: Colors.white70, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
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
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoView() {
    Widget videoWidget;
    if (!_isSwappedVideo) {
      if (_webrtcService.hasRemoteStream) {
        videoWidget = RTCVideoView(
          _webrtcService.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        videoWidget = CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
        );
      }
    } else {
      if (_isCameraReady) {
        videoWidget = RTCVideoView(
          _webrtcService.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        videoWidget = const Center(
          child: CircularProgressIndicator(color: AppColors.neonPink),
        );
      }
    }

    return RepaintBoundary(
      child: BeautyFilterEngine.applyFilterToWidget(
        child: videoWidget,
        filter: _currentFilter,
      ),
    );
  }

  Widget _buildPipVideoView() {
    Widget pipWidget;
    if (!_isSwappedVideo) {
      if (_isCameraReady) {
        pipWidget = RTCVideoView(
          _webrtcService.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        pipWidget = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
        );
      }
    } else {
      if (_webrtcService.hasRemoteStream) {
        pipWidget = RTCVideoView(
          _webrtcService.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        pipWidget = CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
        );
      }
    }

    return RepaintBoundary(
      child: BeautyFilterEngine.applyFilterToWidget(
        child: pipWidget,
        filter: _currentFilter,
      ),
    );
  }
}