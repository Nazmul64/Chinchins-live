import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' hide VideoDimensions;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../main.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/in_call_recharge_gems_sheet.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/utils/permission_helper.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';
import '../services/streaming_service.dart';
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
  final Map<String, dynamic>? initialSessionData;

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
    this.initialSessionData,
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

  // LiveKit Engine State
  Room? _liveKitRoom;
  EventsListener<RoomEvent>? _liveKitListener;
  VideoTrack? _remoteLiveKitVideoTrack;
  LocalVideoTrack? _localLiveKitVideoTrack;
  bool _isLiveKitCall = false;

  bool _isCameraReady = false;
  bool _isConnectingCall = true;
  bool _isCallAccepted = false;
  bool _isSwappedVideo = false;
  bool _hasStartedWebRTC = false;
  bool _isEndingCall = false;
  bool _hasInitiatedCall = false;

  int _callSeconds = 0;
  Timer? _timer;
  Timer? _pollingTimer;
  Timer? _ringTimeoutTimer;
  int _userGems = 0;
  bool _isRechargeSheetOpen = false;
  bool _isVideoBlurred = false;
  bool _isFreeTrialActive = true;
  int _freeTrialRemaining = 16;
  int _ratePerMinute = 100;
  bool _isPulseInProgress = false;
  bool _hasStartedTimer = false;

  StreamSubscription? _wsAcceptedSub;
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

  int? _callId;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    StreamingService.isCallActive = true;
    try {
      WakelockPlus.enable();
    } catch (_) {}
    _callId = widget.callId;
    _channelName = widget.channelName;
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
      _isCallAccepted = true;
      _activeSession = null;
      _startTimer();
    } else {
      _webrtcService = WebRTCCallService();
      _webrtcService.onIceStateChanged = (RTCIceConnectionState state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          if (_isCallAccepted || widget.isIncoming) {
            _onMediaConnected();
          }
        }
      };
      _webrtcService.onCallAccepted = (data) {
        debugPrint('[VideoCallScreen] 🟢 onCallAccepted from WebRTCCallService: $data');
        _handleCallAccepted(data);
      };

      if (!widget.isIncoming) {
        _isConnectingCall = true;
        _isCallAccepted = false;
        CallSoundManager.playOutgoingRingtone(widget.dialToneUrl);

        // 🛑 ৪৫ সেকেন্ড রিংগিং টাইমআউট (অটোমেটিক কল কেটে যাওয়া)
        _ringTimeoutTimer?.cancel();
        _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
          if (!_isCallAccepted && !_isEndingCall) {
            _cancelCallOnTimeout();
          }
        });

        if (_callId == null && !_hasInitiatedCall) {
          _initiateOutgoingCall();
        }
      } else {
        _isConnectingCall = false;
        _isCallAccepted = true;
        _hasStartedTimer = true;
        _startTimer();

        final rawToken = widget.initialSessionData?['receiver_token'] ??
            widget.initialSessionData?['token'] ??
            widget.initialSessionData?['livekit_token'] ??
            widget.initialSessionData?['data']?['receiver_token'] ??
            widget.initialSessionData?['data']?['token'] ??
            widget.initialSessionData?['data']?['livekit_token'];
        final lkUrl = widget.initialSessionData?['livekit_url'] ??
            widget.initialSessionData?['data']?['livekit_url'];

        if (rawToken != null && rawToken.toString().isNotEmpty) {
          _connectLiveKitRoom(token: rawToken.toString(), url: lkUrl?.toString());
        }
      }

      _initWebRTCMediaAndFlow();
    }

    _loadUserBalance();
    _loadFeaturedPackage();
    _loadCallConfig();
    _subscribeSignalingEvents();
  }

  Future<void> _connectLiveKitRoom({required String token, String? url}) async {
    try {
      _isLiveKitCall = true;
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}

      await PermissionHelper.requestCallPermissions();

      _liveKitRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            params: VideoParameters(
              dimensions: VideoDimensionsPresets.h720_169,
              encoding: VideoEncoding(
                maxBitrate: 2500 * 1000,
                maxFramerate: 30,
              ),
            ),
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: false,
            videoCodec: 'H264',
            videoEncoding: VideoEncoding(
              maxBitrate: 2500 * 1000,
              maxFramerate: 30,
            ),
          ),
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
          ),
        ),
      );

      _liveKitListener = _liveKitRoom!.createListener();
      _liveKitListener!
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteVideoTrack) {
            if (mounted) {
              setState(() {
                _remoteLiveKitVideoTrack = event.track as RemoteVideoTrack;
                _isConnectingCall = false;
              });
            }
          }
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (event.track is RemoteVideoTrack) {
            if (mounted) {
              setState(() {
                if (_remoteLiveKitVideoTrack == event.track) {
                  _remoteLiveKitVideoTrack = null;
                }
              });
            }
          }
        })
        ..on<ParticipantConnectedEvent>((event) => _updateLiveKitRemoteTrack())
        ..on<ParticipantDisconnectedEvent>((event) => _updateLiveKitRemoteTrack());

      _liveKitRoom!.addListener(() {
        _updateLiveKitRemoteTrack();
      });

      String livekitUrl = url?.trim() ?? 'wss://chinchins.live/livekit';
      if (livekitUrl.isEmpty || livekitUrl.contains('localhost') || livekitUrl.contains('127.0.0.1')) {
        livekitUrl = 'wss://chinchins.live/livekit';
      }
      if (livekitUrl.startsWith('http://')) {
        livekitUrl = livekitUrl.replaceFirst('http://', 'ws://');
      } else if (livekitUrl.startsWith('https://')) {
        livekitUrl = livekitUrl.replaceFirst('https://', 'wss://');
      }
      await _liveKitRoom!.connect(livekitUrl, token);

      // ⚡ Mandate 1: Immediately enable and publish microphone and camera tracks
      await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
      await _liveKitRoom!.localParticipant?.setCameraEnabled(true);

      _localLiveKitVideoTrack = _liveKitRoom!.localParticipant?.videoTrackPublications.firstOrNull?.track as LocalVideoTrack?;

      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}

      _updateLiveKitRemoteTrack();
      _onMediaConnected();
    } catch (e) {
      debugPrint('[VideoCallScreen] LiveKit connect error: $e');
    }
  }

  void _updateLiveKitRemoteTrack() {
    if (_liveKitRoom == null) return;
    final remote = _liveKitRoom!.remoteParticipants.values.firstOrNull;
    final track = remote?.videoTrackPublications.firstOrNull?.track;
    if (track != null && track is VideoTrack) {
      if (mounted && _remoteLiveKitVideoTrack != track) {
        setState(() {
          _remoteLiveKitVideoTrack = track;
          if (_isCallAccepted || widget.isIncoming) {
            _isConnectingCall = false;
          }
        });
      }
    }
  }

  Future<void> _initiateOutgoingCall() async {
    if (_hasInitiatedCall || _isEndingCall || widget.isIncoming) return;
    _hasInitiatedCall = true;

    final res = await CallApiService.initiateCall(
      receiverId: widget.model.id,
      receiverAccountId: widget.model.accountId,
      callType: 'video',
      channelName: _channelName,
    );

    if (!mounted || _isEndingCall) return;

    if (res['is_low_balance'] == true || res['code'] == 'INSUFFICIENT_BALANCE') {
      await CallSoundManager.stopRingtone();
      if (mounted) {
        Navigator.pop(context);
        InCallRechargeGemsSheet.show(
          context,
          model: widget.model,
          userGems: _userGems,
          ratePerMinute: _ratePerMinute,
        );
      }
      return;
    }

    if (res['is_offline'] == true || res['is_busy'] == true || res['success'] == false) {
      await CallSoundManager.stopRingtone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Call could not be connected'),
            backgroundColor: AppColors.cardDarkElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final newCallId = res['call_id'] ?? (res['data'] is Map ? res['data']['call_id'] ?? res['data']['id'] : null);
    final newChannel = res['channel_name'] ?? (res['data'] is Map ? res['data']['channel_name'] : null);

    if (newCallId != null) {
      _callId = newCallId is int ? newCallId : int.tryParse(newCallId.toString());
    }
    if (newChannel != null && newChannel.toString().isNotEmpty) {
      _channelName = newChannel.toString();
    }

    if (_callId != null) {
      SignalingService().subscribeToCallRoom(_callId.toString());
    }
    if (_channelName != null && _channelName!.isNotEmpty) {
      SignalingService().subscribeToCallRoom(_channelName!);
    }

    final lkToken = res['livekit_token'] ?? res['token'] ?? res['data']?['livekit_token'] ?? res['data']?['token'];
    if (lkToken != null && lkToken.toString().isNotEmpty) {
      final lkUrl = res['livekit_url'] ?? res['data']?['livekit_url'];
      await _connectLiveKitRoom(token: lkToken.toString(), url: lkUrl?.toString());
    } else {
      _checkAndStartWebRTCCaller();
    }
  }

  void _checkAndStartWebRTCCaller() {
    if (widget.isIncoming || _hasStartedWebRTC || _isEndingCall) return;
    final effectiveCallId = _callId ?? widget.callId;
    final effectiveChannel = _channelName ?? widget.channelName;

    if (effectiveCallId != null && _isCameraReady) {
      _hasStartedWebRTC = true;
      _startCallStatusPolling();
      _webrtcService.startCallAsCaller(
        callId: effectiveCallId,
        channelName: effectiveChannel,
        onRemoteStreamConnected: (stream) {
          _onMediaConnected(stream);
        },
        onCallEnded: () {
          if (mounted && !_isEndingCall) {
            _terminateCallSession('Call ended');
          }
        },
      );
    }
  }

  void _subscribeSignalingEvents() {
    final signaling = SignalingService();
    final cId = _callId ?? widget.callId;
    final chName = _channelName ?? widget.channelName;
    if (cId != null) {
      signaling.subscribeToCallRoom(cId.toString());
    }
    if (chName != null && chName.isNotEmpty && chName != cId?.toString()) {
      signaling.subscribeToCallRoom(chName);
    }

    _wsAcceptedSub = signaling.onCallAccepted.listen((data) {
      debugPrint('[VideoCallScreen] 🚀 WebSocket Call Accepted event received: $data');
      _handleCallAccepted(data);
    });

    _wsEndedSub = signaling.onCallEnded.listen((data) {
      _terminateCallSession('Call ended by partner');
    });
    _wsRejectedSub = signaling.onCallRejected.listen((data) {
      _terminateCallSession('Call declined by host');
    });
    _wsCancelledSub = signaling.onCallCancelled.listen((data) {
      _terminateCallSession('Call was cancelled');
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

  /// 🛑 Mandate 2: Centralized Call Session Disposal (Loop Killer)
  void disposeCallSession() {
    _isEndingCall = true;
    _hasInitiatedCall = true;
    StreamingService.isCallActive = false;
    _timer?.cancel();
    _timer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _wsAcceptedSub?.cancel();
    _wsAcceptedSub = null;
    _wsEndedSub?.cancel();
    _wsEndedSub = null;
    _wsRejectedSub?.cancel();
    _wsRejectedSub = null;
    _wsCancelledSub?.cancel();
    _wsCancelledSub = null;
    _wsInCallMsgSub?.cancel();
    _wsInCallMsgSub = null;
    _wsGiftSub?.cancel();
    _wsGiftSub = null;
    CallSoundManager.stopRingtone();
    if (_liveKitRoom != null) {
      try {
        _liveKitListener?.dispose();
        _liveKitRoom?.disconnect();
        _liveKitRoom?.dispose();
      } catch (_) {}
      _liveKitRoom = null;
    }
    _webrtcService.dispose();
    final callIdStr = _callId?.toString() ?? widget.callId?.toString() ?? _channelName ?? widget.channelName;
    if (callIdStr != null && callIdStr.isNotEmpty) {
      SignalingService().leaveCallRoom(callIdStr);
    }
    _callId = null;
    _channelName = null;
  }

  /// 🛑 ৪৫ সেকেন্ড রিংগিং টাইমআউট হলে স্বয়ংক্রিয়ভাবে কল ক্যানসেল ও স্ক্রিন বন্ধ করা
  Future<void> _cancelCallOnTimeout() async {
    if (_isEndingCall || _isCallAccepted) return;
    _isEndingCall = true;

    final effectiveCallId = _callId ?? widget.callId;

    try {
      WakelockPlus.disable();
    } catch (_) {}

    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;
    disposeCallSession();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.model.name} did not answer (Missed)'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (effectiveCallId != null) {
      try {
        await CallApiService.cancelCall(callId: effectiveCallId);
      } catch (_) {}
    }
  }

  void terminateCallCompletely([String? reason]) {
    _terminateCallSession(reason);
  }

  void _terminateCallSession([String? reason]) {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      WakelockPlus.disable();
    } catch (_) {}

    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;
    disposeCallSession();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (reason != null && reason.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason),
            backgroundColor: AppColors.cardDarkElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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

  void _handleCallAccepted([Map<String, dynamic>? data]) {
    if (_isCallAccepted && _hasStartedTimer && _liveKitRoom != null) return;
    debugPrint('[VideoCallScreen] 🟢 Call Accepted confirmed by server/socket/polling: $data');

    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    CallSoundManager.stopRingtone();

    if (mounted) {
      setState(() {
        _isCallAccepted = true;
        _isConnectingCall = false;
      });
    }

    final lkToken = data != null
        ? (data['caller_token'] ??
            data['token'] ??
            data['livekit_token'] ??
            data['receiver_token'] ??
            data['data']?['caller_token'] ??
            data['data']?['token'] ??
            data['data']?['livekit_token'] ??
            data['data']?['receiver_token'])
        : null;
    final lkUrl = data != null
        ? (data['livekit_url'] ?? data['data']?['livekit_url'] ?? 'wss://chinchins.live/livekit')
        : 'wss://chinchins.live/livekit';

    if (lkToken != null && lkToken.toString().isNotEmpty && _liveKitRoom == null) {
      _connectLiveKitRoom(token: lkToken.toString(), url: lkUrl?.toString());
    } else {
      _onMediaConnected();
    }

    if (!_hasStartedTimer) {
      _hasStartedTimer = true;
      final cId = _callId ?? widget.callId;
      if (cId != null) {
        CallApiService.notifyCallConnected(
          callId: cId,
          mediaStatus: 'connected',
        );
      }
      _startTimer();
    }
  }

  void _onMediaConnected([MediaStream? stream]) {
    if (stream != null && _webrtcService.remoteRenderer.srcObject != stream) {
      _webrtcService.remoteRenderer.srcObject = stream;
    }

    // Ensure all audio tracks are active and unmuted
    _webrtcService.unmuteAllAudio();

    // Force maximum loud speakerphone audio
    _webrtcService.toggleSpeakerphone(true);
    Future.delayed(const Duration(milliseconds: 200), () {
      _webrtcService.unmuteAllAudio();
      _webrtcService.toggleSpeakerphone(true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _webrtcService.unmuteAllAudio();
      _webrtcService.toggleSpeakerphone(true);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _webrtcService.unmuteAllAudio();
      _webrtcService.toggleSpeakerphone(true);
    });

    // 🛑 STRICT GUARD: Timer and connected state transition ONLY when server confirmation / acceptance has happened!
    if (_isCallAccepted || widget.isIncoming) {
      CallSoundManager.stopRingtone();
      if (mounted) {
        setState(() {
          _isConnectingCall = false;
        });
      }
      if (!_hasStartedTimer) {
        _hasStartedTimer = true;
        final cId = _callId ?? widget.callId;
        if (cId != null) {
          CallApiService.notifyCallConnected(
            callId: cId,
            mediaStatus: 'connected',
          );
        }
        _startTimer();
      }
    }
  }

  Future<void> _initWebRTCMediaAndFlow() async {
    final success = await _webrtcService.initializeMedia();
    if (!mounted) return;
    setState(() {
      _isCameraReady = success;
    });

    _webrtcService.remoteRenderer.onFirstFrameRendered = () {
      if (mounted && (_isCallAccepted || widget.isIncoming)) {
        setState(() {
          _isConnectingCall = false;
        });
      }
    };
    _webrtcService.remoteRenderer.onResize = () {
      if (mounted) setState(() {});
    };

    final effectiveCallId = _callId ?? widget.callId;
    final effectiveChannel = _channelName ?? widget.channelName;

    if (effectiveCallId != null) {
      _startCallStatusPolling();
    }

    if (widget.isIncoming) {
      if (effectiveCallId != null && !_hasStartedWebRTC) {
        _hasStartedWebRTC = true;
        await _webrtcService.startCallAsReceiver(
          callId: effectiveCallId,
          channelName: effectiveChannel,
          onRemoteStreamConnected: (stream) {
            _onMediaConnected(stream);
          },
          onCallEnded: () {
            if (mounted && !_isEndingCall) {
              _terminateCallSession('Call ended');
            }
          },
        );
      }
    } else {
      _checkAndStartWebRTCCaller();
    }
  }

  void _startCallStatusPolling() {
    final pollCallId = _callId ?? widget.callId;
    if (pollCallId == null || _isEndingCall) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      if (!mounted || _isEndingCall) {
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      // If call is accepted and WebSockets is connected, cancel status polling
      if (_isCallAccepted && !_isConnectingCall && SignalingService().isConnected) {
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      // 1. Check incoming signals via /api/call/signal/receive
      try {
        final signals = await CallApiService.receiveSignals(
          callId: pollCallId,
          autoRead: false,
        );
        if (!mounted || _isEndingCall) return;

        for (final signal in signals) {
          dynamic rawPayload = signal['payload'];
          if (rawPayload is String) {
            try {
              rawPayload = jsonDecode(rawPayload);
            } catch (_) {}
          }
          final Map<String, dynamic> payload = (rawPayload is Map)
              ? Map<String, dynamic>.from(rawPayload)
              : Map<String, dynamic>.from(signal);

          final sigType = (signal['type'] ?? payload['type'] ?? '').toString().toLowerCase();
          final action = (payload['action'] ?? payload['event'] ?? '').toString().toLowerCase();
          final status = (payload['status'] ?? payload['call_status'] ?? '').toString().toLowerCase();

          debugPrint('[VideoCallScreen] 📡 Signal Polling: type=$sigType, action=$action, status=$status');

          if (sigType == 'accepted' ||
              sigType == 'accept' ||
              action == 'call_accepted' ||
              action == 'call.accepted' ||
              status == 'connected' ||
              status == 'accepted') {
            debugPrint('[VideoCallScreen] 🟢 CALL ACCEPTED detected via signal polling!');
            timer.cancel();
            _pollingTimer = null;
            _handleCallAccepted(payload.isNotEmpty ? payload : Map<String, dynamic>.from(signal));
            return;
          } else if (sigType == 'rejected' || action == 'call_rejected' || action == 'call.rejected' || status == 'rejected') {
            timer.cancel();
            _pollingTimer = null;
            _terminateCallSession('Call declined by host');
            return;
          } else if (sigType == 'cancelled' ||
              sigType == 'ended' ||
              sigType == 'hangup' ||
              sigType == 'bye' ||
              action == 'call_cancelled' ||
              action == 'call_ended' ||
              status == 'cancelled' ||
              status == 'ended') {
            timer.cancel();
            _pollingTimer = null;
            _terminateCallSession('Call was ended');
            return;
          }
        }
      } catch (e) {
        debugPrint('[VideoCallScreen] receiveSignals error: $e');
      }

      // 2. Fallback: Check via /api/calls/{id}/status
      try {
        final statusData = await CallApiService.getCallStatus(pollCallId);
        if (!mounted || statusData == null || _isEndingCall) return;

        final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
        final isTerminated = statusData['is_terminated'] == true || statusData['data']?['is_terminated'] == true;

        if (status == 'rejected') {
          timer.cancel();
          _pollingTimer = null;
          _terminateCallSession('Host declined the call');
        } else if (status == 'cancelled') {
          timer.cancel();
          _pollingTimer = null;
          _terminateCallSession('Call was cancelled');
        } else if (status == 'ended' || isTerminated) {
          timer.cancel();
          _pollingTimer = null;
          _terminateCallSession('Call ended');
        } else if (status == 'connected' || status == 'active' || status == 'accepted') {
          timer.cancel();
          _pollingTimer = null;
          _handleCallAccepted(statusData);
        }
      } catch (e) {
        debugPrint('[VideoCallScreen] getCallStatus error: $e');
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

  /// 🔴 Mandate 3: Immediate Call End & Cancel Action
  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      WakelockPlus.disable();
    } catch (_) {}

    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;

    final effectiveCallId = _callId ?? widget.callId;
    final channelName = _channelName ?? widget.channelName;
    final isConnecting = _isConnectingCall;
    final callSecs = _callSeconds;

    // ⚡ 1. Immediately dispose all timers, players, livekit/webrtc room (Mandate 2)
    disposeCallSession();

    // ⚡ 2. Instantly close screen (0.00ms delay) (Mandate 3)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // ⚡ 3. Fire POST /api/call/end (or cancel) to server (Mandate 3)
    if (effectiveCallId != null) {
      Future.microtask(() async {
        try {
          if (isConnecting || callSecs <= 0) {
            await CallApiService.cancelCall(callId: effectiveCallId);
          } else {
            await CallApiService.endCall(
              callId: effectiveCallId,
              channelName: channelName,
              durationSeconds: callSecs,
            );
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}

    if (PiPCallOverlay.isMinimized && _activeSession != null) {
      debugPrint('[VideoCallScreen] Preserving active WebRTC session for PiP overlay');
    } else {
      _isEndingCall = true;
      disposeCallSession();
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

      final effectiveCallId = _callId ?? widget.callId;
      if (trialJustEnded) {
        // 16s Free preview expired
        if (_userGems < _ratePerMinute) {
          setState(() {
            _isVideoBlurred = true;
          });
          _webrtcService.setCallMuted(true);
          _showInCallRechargeSheet();
        } else if (effectiveCallId != null) {
          _sendInCallPulse();
        }
      } else if (effectiveCallId != null && _callSeconds % 60 == 0 && !_isFreeTrialActive) {
        _sendInCallPulse();
      }
    });
  }

  Future<void> _sendInCallPulse() async {
    final effectiveCallId = _callId ?? widget.callId;
    if (_isPulseInProgress || effectiveCallId == null || _isRechargeSheetOpen) return;
    _isPulseInProgress = true;

    try {
      final res = await CallApiService.deductIntervalPulse(
        callId: effectiveCallId,
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

              // ৩. টপ হেডার বার: ব্যাক/ডাউন অ্যারো + হোস্ট প্রোফাইল ক্যাপসুল (টপ-লেফটে) এবং PiP উইন্ডো (টপ-রাইটে) - কেবল কল অ্যাকসেপ্ট হলে দৃশ্যমান
              if (_isCallAccepted || widget.isIncoming)
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
                                      // Call Duration Timer Label (only visible when call is accepted/connected)
                                      if (_isCallAccepted)
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

              // ৪. রাইট সাইডবারে ইন-কল কুইক অ্যাকশন বোতাম (ফিল্টার, লাইভ চ্যাট ও গিফট) - কেবল কল অ্যাকসেপ্ট হওয়ার পর
              if (_isCallAccepted || widget.isIncoming)
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

                    // 🛠️ WebRTC / Call Debug HUD Diagnostics Button
                    _buildFloatingActionButton(
                      icon: Icons.bug_report_rounded,
                      label: 'Debug',
                      color: const Color(0xFF00E676),
                      onTap: () {
                        WebRTCDebugModal.show(
                          context,
                          webrtcService: _webrtcService,
                          callId: _callId ?? widget.callId,
                          isIncoming: widget.isIncoming,
                          callerOrReceiverName: widget.model.name,
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

              // ৫. ইন-কল লাইভ চ্যাট, কুইক মেসেজ এবং বটম কন্ট্রোল (একক রেসপনসিভ কলাম) - কেবল কল অ্যাকসেপ্ট হওয়ার পর
              if (_isCallAccepted || widget.isIncoming)
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

                          // 🔴 লাল কল এন্ড বাটন (End Call Button)
                          GestureDetector(
                            onTap: _handleUserHangup,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF2D55),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x88FF2D55),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ৬. কলার রিংগিং / কলিং ফুলস্ক্রিন ওভারলে (সার্ভার থেকে CallAccepted কনফার্ম না হওয়া পর্যন্ত)
              if (!_isCallAccepted && !widget.isIncoming)
                _buildCallingRingingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallingRingingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Big Host Avatar with Outer Glow
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonPink.withValues(alpha: 0.2),
                      ),
                    ),
                    AvatarWithFrame(
                      avatarUrl: widget.model.avatarUrl,
                      frameUrl: widget.model.avatarFrameUrl,
                      level: widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level,
                      badgeColor: widget.model.badgeColor,
                      glowColor: widget.model.glowColor,
                      size: 110,
                      showLevelBadge: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.model.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              // Ringing Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.neonPink.withValues(alpha: 0.8),
                      const Color(0xFF6A1B9A).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPink.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Ringing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Waiting for ${widget.model.name} to accept...',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const Spacer(flex: 3),
              // Big Red Cancel Call Button
              GestureDetector(
                onTap: _endCall,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF2D55),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88FF2D55),
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cancel Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
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
    if (_isLiveKitCall && _liveKitRoom != null) {
      if (!_isSwappedVideo) {
        if (_remoteLiveKitVideoTrack != null) {
          videoWidget = VideoTrackRenderer(
            _remoteLiveKitVideoTrack!,
            fit: VideoViewFit.cover,
          );
        } else {
          videoWidget = CachedImageLoader(
            imageUrl: widget.model.avatarUrl,
            fit: BoxFit.cover,
          );
        }
      } else {
        if (_localLiveKitVideoTrack != null) {
          videoWidget = VideoTrackRenderer(
            _localLiveKitVideoTrack!,
            fit: VideoViewFit.cover,
          );
        } else {
          videoWidget = const Center(
            child: CircularProgressIndicator(color: AppColors.neonPink),
          );
        }
      }
    } else {
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
    if (_isLiveKitCall && _liveKitRoom != null) {
      if (!_isSwappedVideo) {
        if (_localLiveKitVideoTrack != null) {
          pipWidget = VideoTrackRenderer(
            _localLiveKitVideoTrack!,
            fit: VideoViewFit.cover,
          );
        } else {
          pipWidget = const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
          );
        }
      } else {
        if (_remoteLiveKitVideoTrack != null) {
          pipWidget = VideoTrackRenderer(
            _remoteLiveKitVideoTrack!,
            fit: VideoViewFit.cover,
          );
        } else {
          pipWidget = CachedImageLoader(
            imageUrl: widget.model.avatarUrl,
            fit: BoxFit.cover,
          );
        }
      }
    } else {
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
    }

    return RepaintBoundary(
      child: BeautyFilterEngine.applyFilterToWidget(
        child: pipWidget,
        filter: _currentFilter,
      ),
    );
  }
}
