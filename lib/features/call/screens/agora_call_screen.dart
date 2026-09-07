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
  final bool isTempToken;
  final bool isVideo;

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
  bool _isVideoBlurred = false;

  String _lastAgoraError = 'None';
  String _agoraConnectionState = 'Connecting...';

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
  int _featuredPackageCoins = 0;

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
    _loadCallConfig();
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

      // Enable verbose debug logging for live troubleshooting
      await _engine!.setLogLevel(LogLevel.logLevelDebug);

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
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint('[AgoraCallScreen] Token privilege will expire');
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

      // Crystal-clear loud voice profile with automatic echo cancellation
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );

      await _engine!.setEnableSpeakerphone(true);
      await _engine!.adjustRecordingSignalVolume(100);
      await _engine!.adjustPlaybackSignalVolume(100);

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

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _pollCallStatus();
    });
  }

  Future<void> _pollCallStatus() async {
    if (widget.callId == null || _isEndingCall) return;
    try {
      final statusData = await CallApiService.getCallStatus(widget.callId!);
      if (!mounted || statusData == null) return;
      final status = (statusData['status'] ?? statusData['data']?['status'])?.toString().toLowerCase();
      final isTerminated = statusData['is_terminated'] == true || statusData['data']?['is_terminated'] == true;
      if (status == 'ended' || status == 'rejected' || status == 'cancelled' || isTerminated) {
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

    if (widget.callId != null) {
      CallApiService.sendQuickMessage(
        callId: widget.callId!,
        receiverId: widget.model.id,
        message: message,
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

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    CallSoundManager.stopRingtone();
    _timer?.cancel();
    _pollingTimer?.cancel();

    if (widget.callId != null) {
      if (_isConnecting || _callSeconds <= 0) {
        await CallApiService.cancelCall(callId: widget.callId!);
      } else {
        await CallApiService.endCall(
          callId: widget.callId!,
          durationSeconds: _callSeconds,
        );
      }
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  // Host Badge
                  Container(
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
                    const SizedBox(height: 8),
                    // Dev Mode Button for Agora
                    GestureDetector(
                      onTap: _showAgoraDevModeModal,
                      child: Container(
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
                    onTap: _showInCallRechargeSheet,
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

  Widget _buildVideoView({required bool isMain}) {
    if (_engine == null) return const SizedBox.shrink();

    // If swapped: main shows local (uid 0), pip shows remote (_remoteUid)
    // If not swapped: main shows remote (_remoteUid), pip shows local (uid 0)
    final bool showLocal = isMain ? _isSwappedVideo : !_isSwappedVideo;

    if (showLocal) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
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
              const SizedBox(height: 12),
              // Clean calling status pill (NO BACKEND/ENGINE NAME SHOWN)
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
