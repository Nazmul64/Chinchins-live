import 'dart:async';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/widgets/in_call_recharge_gems_sheet.dart';
import '../services/call_api_service.dart';
import '../services/call_sound_manager.dart';

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
  final bool isVideo;

  const AgoraCallScreen({
    super.key,
    required this.model,
    this.callId,
    required this.channelName,
    required this.appId,
    required this.token,
    required this.uid,
    this.isFreeTrial = false,
    this.freeDurationSeconds = 16,
    this.ratePerMinute = 100,
    this.isIncoming = false,
    this.dialToneUrl,
    this.isVideo = true,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isConnecting = true;
  bool _isEndingCall = false;

  bool _isAudioMuted = false;
  bool _isVideoOff = false;
  bool _isSwappedVideo = false;

  int _callSeconds = 0;
  Timer? _timer;
  Timer? _pollingTimer;
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

  @override
  void initState() {
    super.initState();
    _isFreeTrialActive = true;
    _freeTrialRemaining = widget.freeDurationSeconds > 0 ? widget.freeDurationSeconds : 16;
    _ratePerMinute = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100);

    if (!widget.isIncoming) {
      _isConnecting = true;
      CallSoundManager.playOutgoingRingtone(widget.dialToneUrl);
    } else {
      _isConnecting = false;
    }

    _initAgoraEngine();
    _loadUserBalance();
    _loadFeaturedPackage();
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

  Future<void> _loadUserBalance() async {
    try {
      final balanceData = await WalletApiService.getUserBalance();
      if (balanceData != null && mounted) {
        setState(() {
          _userGems = (balanceData['balance'] as num?)?.toInt() ??
              (balanceData['diamonds'] as num?)?.toInt() ??
              (balanceData['gems'] as num?)?.toInt() ??
              0;
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

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) {
              setState(() {
                _localUserJoined = true;
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (mounted) {
              CallSoundManager.stopRingtone();
              setState(() {
                _remoteUid = remoteUid;
                _isConnecting = false;
              });
              _startCallTimer();
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (mounted) {
              setState(() {
                _remoteUid = null;
              });
              _endCall();
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AgoraCallScreen] Error $err: $msg');
          },
        ),
      );

      if (widget.isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      await _engine!.setEnableSpeakerphone(true);

      await _engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: widget.uid,
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
    }
  }

  void _startCallTimer() {
    if (_hasStartedTimer) return;
    _hasStartedTimer = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callSeconds++;
        if (_isFreeTrialActive && _freeTrialRemaining > 0) {
          _freeTrialRemaining--;
          if (_freeTrialRemaining <= 0) {
            _isFreeTrialActive = false;
          }
        }
      });

      // Every 60s trigger server billing pulse
      if (_callSeconds > 0 && _callSeconds % 60 == 0) {
        _pulseBilling();
      }
    });

    // Start fallback status polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollCallStatus();
    });
  }

  Future<void> _pollCallStatus() async {
    if (widget.callId == null || _isEndingCall) return;
    try {
      final res = await CallApiService.pollCallStatus(widget.callId!);
      if (res != null && mounted) {
        final status = res['status']?.toString().toLowerCase();
        if (status == 'ended' || status == 'rejected' || status == 'cancelled') {
          _endCall();
        }
      }
    } catch (_) {}
  }

  Future<void> _pulseBilling() async {
    if (_isPulseInProgress || widget.callId == null) return;
    _isPulseInProgress = true;

    try {
      final res = await CallApiService.pulseBilling(
        callId: widget.callId!,
        channelName: widget.channelName,
      );

      if (res['success'] == true && mounted) {
        final remainingGems = (res['remaining_gems'] as num?)?.toInt() ??
            (res['balance'] as num?)?.toInt() ??
            (_userGems - _ratePerMinute);
        setState(() {
          _userGems = remainingGems > 0 ? remainingGems : 0;
        });

        if (res['should_hangup'] == true || _userGems <= 0) {
          _showRechargeSheet();
        }
      } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        _showRechargeSheet();
      }
    } catch (_) {
    } finally {
      _isPulseInProgress = false;
    }
  }

  void _showRechargeSheet() {
    if (_isRechargeSheetOpen || !mounted) return;
    _isRechargeSheetOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InCallRechargeGemsSheet(
        hostName: widget.model.name,
        hostAvatar: widget.model.avatarUrl,
        currentBalance: _userGems,
        requiredCoins: _ratePerMinute,
        onRechargeSuccess: () {
          _loadUserBalance();
          Navigator.pop(ctx);
        },
      ),
    ).then((_) {
      _isRechargeSheetOpen = false;
    });
  }

  void _sendQuickMessage(String message) {
    if (_freeMessageChances <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No free message chances left. Use Chat drawer.')),
      );
      return;
    }

    setState(() {
      _freeMessageChances--;
      _sentMessageFeedback = message;
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _sentMessageFeedback = null;
        });
      }
    });
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    CallSoundManager.stopRingtone();
    _timer?.cancel();
    _pollingTimer?.cancel();

    if (widget.callId != null) {
      CallApiService.endCall(callId: widget.callId!);
    }

    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    CallSoundManager.stopRingtone();
    _timer?.cancel();
    _pollingTimer?.cancel();
    if (_engine != null) {
      _engine!.leaveChannel();
      _engine!.release();
    }
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return false;
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
                      ? AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUid),
                            connection: RtcConnection(channelId: widget.channelName),
                          ),
                        )
                      : _buildVoiceAudioState()),
            ),

            // 2. Top Bar (Host Profile Info & Balance / Coins Packages)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  // Host Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        AvatarWithFrame(
                          imageUrl: widget.model.avatarUrl,
                          radius: 18,
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
                  const Spacer(),

                  // Featured Coin Package / Recharge Button
                  GestureDetector(
                    onTap: _showRechargeSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_userGems Gems',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Local Camera PiP Preview (Top Right)
            if (widget.isVideo && _localUserJoined && _engine != null && !_isVideoOff)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: 16,
                width: 105,
                height: 150,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSwappedVideo = !_isSwappedVideo;
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white38, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. In-call Sent Quick Message Overlay
            if (_sentMessageFeedback != null)
              Positioned(
                left: 20,
                bottom: 140,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: AppColors.neonPink, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _sentMessageFeedback!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. In-call Quick Messages Bar
            Positioned(
              left: 14,
              right: 14,
              bottom: 95,
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final msg = _quickMessages[idx];
                    return GestureDetector(
                      onTap: () => _sendQuickMessage(msg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 6. Bottom Toolbar Controls (Mute, Camera, Flip, Hangup, Recharge)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
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
                    onTap: _endCall,
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
                    onTap: _showRechargeSheet,
                  ),
                ],
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

  Widget _buildConnectingState() {
    return Stack(
      children: [
        CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWithFrame(
                imageUrl: widget.model.avatarUrl,
                radius: 50,
              ),
              const SizedBox(height: 16),
              Text(
                widget.model.name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Connecting via Agora Cloud Engine...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceAudioState() {
    return Stack(
      children: [
        CachedImageLoader(
          imageUrl: widget.model.avatarUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.65)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWithFrame(
                imageUrl: widget.model.avatarUrl,
                radius: 60,
              ),
              const SizedBox(height: 16),
              Text(
                widget.model.name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_callSeconds),
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
