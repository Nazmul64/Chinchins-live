import 'dart:async';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../main.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/in_call_recharge_gems_sheet.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/streaming_service.dart';
import '../services/beauty_filter_engine.dart';
import '../services/pip_call_overlay.dart';
import '../widgets/call_end_confirmation_dialog.dart';
import '../widgets/camera_filter_tray.dart';
import '../widgets/in_call_profile_sheet.dart';
import '../widgets/in_call_chat_overlay.dart';
import '../widgets/in_call_gift_sheet.dart';
import '../widgets/gift_animation_overlay.dart';

class ActiveAgoraCallSession {
  final String channelName;
  final RtcEngine engine;
  final int? remoteUid;
  final int callSeconds;
  final bool isConnecting;
  final bool isAudioMuted;
  final bool isVideoOff;
  final bool isSwappedVideo;
  final bool isVideoBlurred;

  ActiveAgoraCallSession({
    required this.channelName,
    required this.engine,
    this.remoteUid,
    required this.callSeconds,
    required this.isConnecting,
    required this.isAudioMuted,
    required this.isVideoOff,
    required this.isSwappedVideo,
    required this.isVideoBlurred,
  });
}

class AgoraCallScreen extends StatefulWidget {
  final ModelProfile model;
  final int? callId;
  final String channelName;
  final String appId;
  final String token;
  final int uid;
  final bool isFreeTrial;
  final int freeDurationSeconds;
  final int ratePerMinute;
  final bool isIncoming;
  final String? dialToneUrl;
  final bool isTempToken;
  final bool isVideo;
  final bool debugMode;
  final String logLevel;

  const AgoraCallScreen({
    super.key,
    required this.model,
    this.callId,
    required this.channelName,
    required this.appId,
    required this.token,
    required this.uid,
    this.isTempToken = false,
    this.isFreeTrial = false,
    this.freeDurationSeconds = 16,
    this.ratePerMinute = 100,
    this.isIncoming = false,
    this.dialToneUrl,
    this.isVideo = true,
    this.debugMode = false,
    this.logLevel = 'info',
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  static ActiveAgoraCallSession? _activeSession;

  final GlobalKey<InCallChatOverlayState> _chatKey = GlobalKey<InCallChatOverlayState>();
  final GlobalKey<GiftAnimationOverlayState> _giftAnimKey = GlobalKey<GiftAnimationOverlayState>();
  FilterPreset _currentFilter = BeautyFilterEngine.presets[1]; // Beauty Glow

  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isConnecting = true;
  bool _isEndingCall = false;

  bool _isAudioMuted = false;
  bool _isVideoOff = false;
  bool _isSwappedVideo = false;
  bool _isVideoBlurred = false;

  String _lastAgoraError = 'None';
  String _agoraConnectionState = 'Connecting...';

  int _callSeconds = 0;
  Timer? _timer;
  Timer? _pollingTimer;
  StreamSubscription? _wsEndedSub;
  StreamSubscription? _wsRejectedSub;
  StreamSubscription? _wsCancelledSub;
  StreamSubscription? _wsInCallMsgSub;
  StreamSubscription? _wsGiftSub;
  int _userGems = 0;
  bool _isRechargeSheetOpen = false;
  bool _isFreeTrialActive = true;
  int _freeTrialRemaining = 16;
  int _ratePerMinute = 100;
  bool _isPulseInProgress = false;
  bool _hasStartedTimer = false;

  // In-call Quick Messages
  int _freeMessageChances = 2;
  String? _sentMessageFeedback;
  final List<String> _quickMessages = [
    'Be my girlfriend',
    "Hi , what's up babe ?",
    'Can we talk privately?',
    'You look so pretty! ❤️',
  ];

  Map<String, dynamic>? _featuredPackage;
  int _featuredPackageCoins = 0;

  @override
  void initState() {
    super.initState();
    _isFreeTrialActive = true;
    _freeTrialRemaining = widget.freeDurationSeconds > 0 ? widget.freeDurationSeconds : 16;
    _ratePerMinute = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

    if (_activeSession != null && _activeSession!.channelName == widget.channelName) {
      // Reattach to running active session smoothly
      _engine = _activeSession!.engine;
      _remoteUid = _activeSession!.remoteUid;
      _callSeconds = _activeSession!.callSeconds;
      _isConnecting = _activeSession!.isConnecting;
      _isAudioMuted = _activeSession!.isAudioMuted;
      _isVideoOff = _activeSession!.isVideoOff;
      _isSwappedVideo = _activeSession!.isSwappedVideo;
      _isVideoBlurred = _activeSession!.isVideoBlurred;
      _localUserJoined = true;
      _activeSession = null;
      _startCallTimer();
    } else {
      if (!widget.isIncoming) {
        _isConnecting = true;
        CallSoundManager.playOutgoingRingtone(widget.dialToneUrl);
      } else {
        _isConnecting = false;
      }
      _initAgoraEngine();
    }

    _loadUserBalance();
    _loadFeaturedPackage();
    _loadCallConfig();
    _startCallStatusPolling();
    _subscribeSignalingEvents();
  }

  void _subscribeSignalingEvents() {
    final signaling = SignalingService();
    if (widget.callId != null) {
      signaling.subscribeToCallRoom(widget.callId.toString());
    }
    if (widget.channelName.isNotEmpty && widget.channelName != widget.callId?.toString()) {
      signaling.subscribeToCallRoom(widget.channelName);
    }

    _wsEndedSub = signaling.onCallEnded.listen((data) {
      debugPrint('[AgoraCallScreen] Received onCallEnded via WebSocket: $data');
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsRejectedSub = signaling.onCallRejected.listen((data) {
      debugPrint('[AgoraCallScreen] Received onCallRejected via WebSocket: $data');
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsCancelledSub = signaling.onCallCancelled.listen((data) {
      debugPrint('[AgoraCallScreen] Received onCallCancelled via WebSocket: $data');
      CallSoundManager.stopRingtone();
      if (mounted && !_isEndingCall) {
        _endCall();
      }
    });
    _wsInCallMsgSub = signaling.onInCallMessage.listen((data) {
      debugPrint('[AgoraCallScreen] Received InCallMessage via WebSocket: $data');
      if (mounted) {
        _chatKey.currentState?.addIncomingMessage(data);
      }
    });

    _wsGiftSub = signaling.onLiveGift.listen((data) {
      debugPrint('[AgoraCallScreen] Received Gift via WebSocket: $data');
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

  void _startCallStatusPolling() {
    if (widget.callId == null) return;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _pollCallStatus();
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
          final dynamic coins = _featuredPackage?['coins'] ?? _featuredPackage?['gems'];
          _featuredPackageCoins = coins is int ? coins : (int.tryParse(coins?.toString() ?? '0') ?? 1000);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserBalance() async {
    try {
      final balanceData = await WalletApiService.getWalletBalance();
      if (balanceData != null && mounted) {
        final coinsVal = balanceData['coins'] ?? balanceData['user_coins'] ?? balanceData['current_coins'];
        setState(() {
          _userGems = coinsVal is int
              ? coinsVal
              : int.tryParse(coinsVal?.toString() ?? '0') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _initAgoraEngine() async {
    try {
      await [Permission.camera, Permission.microphone].request();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: widget.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Set dynamic logging level
      LogLevel level = LogLevel.logLevelInfo;
      if (widget.logLevel == 'error') level = LogLevel.logLevelError;
      if (widget.logLevel == 'warning') level = LogLevel.logLevelWarn;
      if (widget.logLevel == 'verbose' || widget.logLevel == 'debug' || widget.debugMode) {
        level = LogLevel.logLevelDebug;
      }
      await _engine!.setLogLevel(level);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) {
              setState(() {
                _localUserJoined = true;
                _agoraConnectionState = 'Channel Joined (UID: ${connection.localUid})';
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (mounted) {
              CallSoundManager.stopRingtone();
              setState(() {
                _remoteUid = remoteUid;
                _isConnecting = false;
                _agoraConnectionState = 'Remote User Joined (UID: $remoteUid)';
              });
              if (widget.callId != null) {
                CallApiService.notifyCallConnected(
                  callId: widget.callId!,
                  mediaStatus: 'connected',
                );
              }
              _startCallTimer();
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (mounted) {
              setState(() {
                _remoteUid = null;
                _agoraConnectionState = 'Remote User Offline ($reason)';
              });
              _endCall();
            }
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[AgoraCallScreen] ConnectionState: $state, reason: $reason');
            if (mounted) {
              setState(() {
                _agoraConnectionState = '$state ($reason)';
                if (state == ConnectionStateType.connectionStateConnected) {
                  _localUserJoined = true;
                }
              });
            }
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
            debugPrint('[AgoraCallScreen] Token expiring soon. Auto-renewing from Laravel backend...');
            try {
              final newToken = await StreamingService.refreshAgoraToken(
                channelName: widget.channelName,
                uid: widget.isTempToken ? 0 : widget.uid,
              );
              if (newToken.isNotEmpty && _engine != null) {
                await _engine!.renewToken(newToken);
                debugPrint('[AgoraCallScreen] Agora Token successfully renewed!');
              }
            } catch (e) {
              debugPrint('[AgoraCallScreen] Token renew error: $e');
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AgoraCallScreen] Error $err: $msg');
            if (mounted) {
              setState(() {
                _lastAgoraError = 'Code $err: $msg';
              });
              if (err == ErrorCodeType.errTokenExpired || err == ErrorCodeType.errInvalidToken) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Agora token invalid or expired. Check Admin settings.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          },
        ),
      );

      if (widget.isVideo) {
        await _engine!.enableVideo();
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 30,
            bitrate: 2200,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      // Crystal-clear loud voice profile with automatic echo cancellation & maximum volume boost
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setEnableSpeakerphone(true);
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      // 🔊 Enable Acoustic Echo Cancellation (AEC), Noise Suppression (NS), Auto Gain Control (AGC) & OpenSL
      try {
        await _engine!.setParameters('{"che.audio.enable.aec": true}');
        await _engine!.setParameters('{"che.audio.enable.ns": true}');
        await _engine!.setParameters('{"che.audio.enable.agc": true}');
        await _engine!.setParameters('{"che.audio.opensl": true}');
      } catch (_) {}

      await _engine!.adjustRecordingSignalVolume(400);
      await _engine!.adjustPlaybackSignalVolume(400);

      // In Agora Console, "Generate Temp Token" generates token with UID 0.
      // Dynamic HMAC-SHA256 tokens generated by Laravel backend are signed for widget.uid.
      final int uidToJoin = widget.isTempToken ? 0 : widget.uid;
      debugPrint('[AgoraCallScreen] Joining channel: ${widget.channelName}, uid: $uidToJoin, isTempToken: ${widget.isTempToken}');

      await _engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: uidToJoin,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      debugPrint('[AgoraCallScreen] _initAgoraEngine error: $e');
      if (mounted) {
        setState(() {
          _lastAgoraError = 'Init Exception: $e';
        });
      }
    }
  }

  void _startCallTimer() {
    if (_hasStartedTimer) return;
    _hasStartedTimer = true;

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
        if (_userGems < _ratePerMinute) {
          setState(() {
            _isVideoBlurred = true;
          });
          _engine?.muteLocalAudioStream(true);
          _showInCallRechargeSheet();
        } else if (widget.callId != null) {
          _sendInCallPulse();
        }
      } else if (widget.callId != null && _callSeconds % 60 == 0 && !_isFreeTrialActive) {
        _sendInCallPulse();
      }
    });
  }

  Future<void> _pollCallStatus() async {
    if (widget.callId == null || _isEndingCall) return;
    try {
      final statusData = await CallApiService.getCallStatus(widget.callId!);
      if (!mounted || statusData == null || _isEndingCall) return;
      final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
      final isTerminated = statusData['is_terminated'] == true ||
          statusData['data']?['is_terminated'] == true ||
          status == 'ended' ||
          status == 'rejected' ||
          status == 'cancelled' ||
          status == 'declined' ||
          status == 'missed' ||
          status == 'timeout';
      if (isTerminated) {
        CallSoundManager.stopRingtone();
        _endCall();
      }
    } catch (_) {}
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
        _engine?.muteLocalAudioStream(true);
        _engine?.muteAllRemoteAudioStreams(true);
        _showInCallRechargeSheet();
      } else if (res['success'] == true) {
        if (res['current_coins'] != null) {
          setState(() {
            _userGems = (res['current_coins'] is int)
                ? res['current_coins']
                : int.tryParse(res['current_coins'].toString()) ?? _userGems;
            _isVideoBlurred = false;
          });
          _engine?.muteLocalAudioStream(false);
          _engine?.muteAllRemoteAudioStreams(false);
        }
      }
    } catch (_) {}
    _isPulseInProgress = false;
  }

  void _showInCallRechargeSheet() {
    if (_isRechargeSheetOpen || !mounted) return;
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
          _engine?.muteLocalAudioStream(true);
          _engine?.muteAllRemoteAudioStreams(true);
        }
      },
      onRechargeSuccess: (addedGems) {
        _isRechargeSheetOpen = false;
        setState(() {
          _userGems += addedGems;
          _isVideoBlurred = false;
        });
        _engine?.muteLocalAudioStream(false);
        _engine?.muteAllRemoteAudioStreams(false);
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
        _engine?.muteLocalAudioStream(true);
        _engine?.muteAllRemoteAudioStreams(true);
      }
    });
  }

  void _sendQuickMessage(String message) {
    if (_freeMessageChances > 0) {
      setState(() {
        _freeMessageChances--;
        _sentMessageFeedback = message;
      });
    } else {
      setState(() {
        _sentMessageFeedback = message;
      });
    }

    _chatKey.currentState?.addIncomingMessage({
      'sender_name': 'You',
      'message': message,
      'is_me': true,
      'type': 'quick_reply',
      'created_at': DateTime.now().toIso8601String(),
    });

    final dynamic sessionId = widget.callId ?? widget.channelName;
    if (sessionId != null) {
      CallApiService.sendCallChatMessage(
        callSessionId: sessionId,
        receiverId: widget.model.id,
        message: message,
        type: 'quick_reply',
      );
    }

    Timer(const Duration(seconds: 3), () {
      if (mounted && _sentMessageFeedback == message) {
        setState(() {
          _sentMessageFeedback = null;
        });
      }
    });
  }

  static void _endActiveSession({int? callId, int? durationSeconds}) async {
    if (_activeSession != null) {
      try {
        await _activeSession!.engine.leaveChannel();
        await _activeSession!.engine.release();
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
    CallSoundManager.stopRingtone();
    _timer?.cancel();
    _pollingTimer?.cancel();
    _wsEndedSub?.cancel();
    _wsRejectedSub?.cancel();
    _wsCancelledSub?.cancel();
    _wsInCallMsgSub?.cancel();
    _wsGiftSub?.cancel();

    // ⚡ 1. Instantly close screen (0.00ms delay)
    if (mounted) {
      Navigator.of(context).pop();
    }

    // 2. Perform API cancellation and Agora engine release in background
    final callId = widget.callId;
    final isConnecting = _isConnecting;
    final callSecs = _callSeconds;
    final engine = _engine;
    _engine = null;

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
        if (engine != null) {
          await engine.leaveChannel();
          await engine.release();
        }
      } catch (_) {}
    });
  }

  Future<void> _handleUserHangup() async {
    if (!_isConnecting && _callSeconds > 0) {
      final shouldEnd = await showCallEndConfirmationDialog(
        context,
        peerName: widget.model.name,
      );
      if (shouldEnd != true) return;
    }
    _endCall();
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

    // If minimized, preserve engine for PiP window restoration
    if (PiPCallOverlay.isMinimized && _activeSession != null) {
      debugPrint('[AgoraCallScreen] Preserving active session for PiP overlay');
    } else {
      _isEndingCall = true;
      if (_engine != null) {
        _engine!.leaveChannel();
        _engine!.release();
        _engine = null;
      }
      _activeSession = null;
    }
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _minimizeToPiP() {
    if (_engine == null) return;
    _activeSession = ActiveAgoraCallSession(
      channelName: widget.channelName,
      engine: _engine!,
      remoteUid: _remoteUid,
      callSeconds: _callSeconds,
      isConnecting: _isConnecting,
      isAudioMuted: _isAudioMuted,
      isVideoOff: _isVideoOff,
      isSwappedVideo: _isSwappedVideo,
      isVideoBlurred: _isVideoBlurred,
    );

    PiPCallOverlay.showMiniWindow(
      context,
      remoteVideoView: RepaintBoundary(
        child: _remoteUid != null && widget.isVideo && _engine != null
            ? _buildVideoView(isMain: true)
            : _buildVoiceAudioState(),
      ),
      peerName: widget.model.name,
      callDurationText: _formatDuration(_callSeconds),
      callSessionId: widget.callId ?? widget.channelName,
      onTapRestore: () {
        final navState = ChinchinsLiveApp.navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
        navState.push(
          MaterialPageRoute(
            builder: (_) => AgoraCallScreen(
              model: widget.model,
              callId: widget.callId,
              channelName: widget.channelName,
              appId: widget.appId,
              token: widget.token,
              uid: widget.uid,
              isTempToken: widget.isTempToken,
              isFreeTrial: widget.isFreeTrial,
              freeDurationSeconds: widget.freeDurationSeconds,
              ratePerMinute: widget.ratePerMinute,
              isIncoming: widget.isIncoming,
              dialToneUrl: widget.dialToneUrl,
              isVideo: widget.isVideo,
              debugMode: widget.debugMode,
              logLevel: widget.logLevel,
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
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Remote Video / Background View
            Positioned.fill(
              child: _isConnecting
                  ? _buildConnectingState()
                  : (_remoteUid != null && widget.isVideo && _engine != null
                      ? _buildVideoView(isMain: true)
                      : _buildVoiceAudioState()),
            ),

            // 2. Top Bar (Host Profile Info & Balance / Coins Packages)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 34),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _minimizeToPiP,
                  ),
                  const SizedBox(width: 4),
                  // Host Badge
                  GestureDetector(
                    onTap: () {
                      InCallProfileSheet.show(context, model: widget.model);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          AvatarWithFrame(
                            avatarUrl: widget.model.avatarUrl,
                            frameUrl: widget.model.avatarFrameUrl,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.model.name,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, color: Color(0xFF00E676), size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(_callSeconds),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Featured Coin Package / Recharge Button (Configured from Admin Panel)
                  GestureDetector(
                    onTap: _showInCallRechargeSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${_featuredPackageCoins > 0 ? _featuredPackageCoins : (_featuredPackage?['coins'] ?? 1000)} Gems',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Local / Remote Camera PiP Preview & Dev Mode (Top Right)
            if (widget.isVideo && _engine != null && !_isVideoOff && (_localUserJoined || _remoteUid != null))
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSwappedVideo = !_isSwappedVideo;
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 105,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white38, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: _buildVideoView(isMain: false),
                        ),
                      ),
                    ),
                    // Dev Mode Button for Agora (Only visible if debugMode is enabled in Admin Config)
                    if (widget.debugMode && RemoteConfigService.instance.config.isDebugHudEnabled)
                      GestureDetector(
                        onTap: _showAgoraDevModeModal,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bug_report_rounded, color: AppColors.neonPink, size: 13),
                              SizedBox(width: 4),
                              Text('Dev mode', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 4. Right Sidebar: In-Call Actions (Beauty Filter, Live Chat, Gifts)
            Positioned(
              right: 14,
              bottom: 160,
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

                  // 💬 In-Call Live Chat Drawer Toggle (Text & Image Sharing)
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
                ],
              ),
            ),

            // 5, 6, 7 & 8. ইন-কল লাইভ চ্যাট, কুইক মেসেজ এবং বটম কন্ট্রোল টুলবার (একক রেসপনসিভ কলাম)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
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
                              const Icon(Icons.favorite, color: AppColors.neonPink, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _sentMessageFeedback!,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ইন-কল লাইভ চ্যাট ওভারলে (বাম পাশে রেন্ডার হবে)
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

                    // ইন-কল কুইক মেসেজ বার
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final msg in _quickMessages)
                            Padding(
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
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // বটম টুলবার কন্ট্রোলস (Mute, Camera, Flip, Hangup, Recharge)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute Mic Toggle
                        _buildCircleButton(
                          icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: _isAudioMuted ? Colors.redAccent : Colors.white24,
                          onTap: () {
                            setState(() => _isAudioMuted = !_isAudioMuted);
                            _engine?.muteLocalAudioStream(_isAudioMuted);
                          },
                        ),

                        // Camera Toggle
                        if (widget.isVideo)
                          _buildCircleButton(
                            icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                            color: _isVideoOff ? Colors.redAccent : Colors.white24,
                            onTap: () {
                              setState(() => _isVideoOff = !_isVideoOff);
                              _engine?.muteLocalVideoStream(_isVideoOff);
                            },
                          ),

                        // End Call Hangup
                        GestureDetector(
                          onTap: _handleUserHangup,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2E63),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF2E63),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                          ),
                        ),

                        // Switch Camera
                        if (widget.isVideo)
                          _buildCircleButton(
                            icon: Icons.switch_camera_rounded,
                            color: Colors.white24,
                            onTap: () {
                              _engine?.switchCamera();
                            },
                          ),

                        // Recharge Sheet Button
                        _buildCircleButton(
                          icon: Icons.card_giftcard_rounded,
                          color: AppColors.neonPink.withValues(alpha: 0.35),
                          onTap: _showInCallRechargeSheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 9. Luxury Full-Screen Gift Animation Overlay
            Positioned.fill(
              child: GiftAnimationOverlay(
                key: _giftAnimKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
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
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView({required bool isMain}) {
    if (_engine == null) return const SizedBox.shrink();

    // If swapped: main shows local (uid 0), pip shows remote (_remoteUid)
    // If not swapped: main shows remote (_remoteUid), pip shows local (uid 0)
    final bool showLocal = isMain ? _isSwappedVideo : !_isSwappedVideo;

    if (showLocal) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(_currentFilter.matrix),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      );
    } else {
      if (_remoteUid == null) {
        return _buildConnectingState();
      }
      final remoteView = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );

      if (isMain && _isVideoBlurred) {
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
          child: Stack(
            fit: StackFit.expand,
            children: [
              remoteView,
              Container(color: Colors.black.withValues(alpha: 0.65)),
            ],
          ),
        );
      }
      return remoteView;
    }
  }

  void _showAgoraDevModeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161224),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bug_report_rounded, color: AppColors.neonPink, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Agora লাইভ ডায়াগনস্টিক প্যানেল',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                _buildDebugRow('ইঞ্জিন ড্রাইভার', 'Agora Cloud RTC Engine'),
                _buildDebugRow('সংযোগ অবস্থা', _agoraConnectionState),
                _buildDebugRow('সর্বশেষ ত্রুটি / এরর', _lastAgoraError),
                _buildDebugRow('চ্যানেল নেম', widget.channelName),
                _buildDebugRow('কল আইডি', '#${widget.callId ?? "N/A"}'),
                _buildDebugRow('Agora App ID', widget.appId.length > 8 ? '${widget.appId.substring(0, 8)}...' : widget.appId),
                _buildDebugRow('টোকেন ধরন', widget.isTempToken ? 'Temp Token (UID 0)' : 'Dynamic HMAC Signed Token'),
                _buildDebugRow('টোকেন স্ট্যাটাস', widget.token.isNotEmpty ? 'Active (${widget.token.length} chars)' : 'EMPTY (No Token)'),
                _buildDebugRow('লোকাল UID', '${widget.isTempToken ? 0 : widget.uid}'),
                _buildDebugRow('রিমোট UID', _remoteUid != null ? '$_remoteUid' : 'অপেক্ষমান (Waiting)'),
                _buildDebugRow('স্পিকার ও সাউন্ড', 'সক্রিয় (100% Volume, High Quality)'),
                _buildDebugRow('কল সময়', _formatDuration(_callSeconds)),
                _buildDebugRow('ফ্রি ট্রায়াল বাকি', '$_freeTrialRemaining সেকেন্ড'),
                _buildDebugRow('ইউজার জেম ব্যালেন্স', '$_userGems Gems'),
                _buildDebugRow('কল রেট', '$_ratePerMinute Gems/min'),
                _buildDebugRow('ঝাপসা/ব্লার মোড', _isVideoBlurred ? 'সক্রিয় (Active)' : 'নিষ্ক্রিয় (Off)'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConnectingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Rich Full-Screen Background Avatar with Frosted Glass & Jewel Tone Gradient
        CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        // Glassmorphism Frost & Gradient Lighting Overlay
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    const Color(0xFF140D26).withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Center Profile with Radiant Glow Ring & Clean Calling Status
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Ring Container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gemYellow.withValues(alpha: 0.45),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: AppColors.neonPink.withValues(alpha: 0.35),
                      blurRadius: 45,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: AvatarWithFrame(
                  avatarUrl: widget.model.avatarUrl,
                  frameUrl: widget.model.avatarFrameUrl,
                  level: widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level,
                  badgeColor: widget.model.badgeColor,
                  glowColor: widget.model.glowColor,
                  size: 132,
                  showLevelBadge: true,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.model.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
                  ],
                ),
              ),
              if (RemoteConfigService.instance.config.isDebugHudEnabled) ...[
                const SizedBox(height: 12),
                // Clean calling status pill (Only visible in debug / dev mode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.model.isOnline ? 'Ringing...' : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceAudioState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    const Color(0xFF130B24).withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onlineGreen.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: AvatarWithFrame(
                  avatarUrl: widget.model.avatarUrl,
                  frameUrl: widget.model.avatarFrameUrl,
                  level: widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level,
                  badgeColor: widget.model.badgeColor,
                  glowColor: widget.model.glowColor,
                  size: 142,
                  showLevelBadge: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.model.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Color(0xFF00E676), size: 10),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_callSeconds),
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
