import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide VideoDimensions;
import 'package:permission_handler/permission_handler.dart';
import '../../../main.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../services/beauty_filter_engine.dart';
import '../services/call_api_service.dart';
import '../services/live_streaming_api_service.dart';
import '../services/pip_call_overlay.dart';
import '../services/streaming_service.dart';
import '../widgets/camera_filter_tray.dart';
import '../widgets/in_call_profile_sheet.dart';
import '../widgets/in_call_gift_sheet.dart';
import '../widgets/gift_animation_overlay.dart';

class ActiveLiveSession {
  final dynamic liveId;
  final String channelName;
  final RtcEngine? rtcEngine;
  final Room? liveKitRoom;
  final int? hostUid;
  final int? guestUid;
  final int myUid;
  final bool isGuestConnected;
  final int viewerCount;
  final int diamondsEarned;

  ActiveLiveSession({
    required this.liveId,
    required this.channelName,
    this.rtcEngine,
    this.liveKitRoom,
    this.hostUid,
    this.guestUid,
    required this.myUid,
    required this.isGuestConnected,
    required this.viewerCount,
    required this.diamondsEarned,
  });
}

class LiveHeart {
  final Key key;
  final double left;
  final Color color;

  LiveHeart({required this.key, required this.left, required this.color});
}

class LiveRoomScreen extends StatefulWidget {
  final ModelProfile host;
  final dynamic liveId;
  final String? channelName;
  final String? title;
  final bool isHost;
  final Map<String, dynamic>? initialSessionData;

  const LiveRoomScreen({
    super.key,
    required this.host,
    this.liveId,
    this.channelName,
    this.title,
    this.isHost = false,
    this.initialSessionData,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin {
  static ActiveLiveSession? _activeSession;

  final GlobalKey<GiftAnimationOverlayState> _giftAnimKey = GlobalKey<GiftAnimationOverlayState>();
  final List<Map<String, dynamic>> _liveComments = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LiveHeart> _hearts = [];
  final Random _rnd = Random();

  FilterPreset _currentFilter = BeautyFilterEngine.presets[1]; // Beauty Glow
  bool _isFollowing = false;
  int _viewerCount = 1;
  int _likeCount = 120;
  int _diamondsEarned = 0;
  dynamic _activeLiveId;
  String _activeChannelName = '';
  
  // LiveKit RTC State
  Room? _liveKitRoom;
  EventsListener<RoomEvent>? _liveKitListener;
  bool _isLiveKitConnected = false;

  // Agora RTC Fallback State
  RtcEngine? _rtcEngine;
  bool _isAgoraReady = false;
  int? _hostUid;
  int? _guestUid;
  int _myUid = 0;
  bool _isGuestConnected = false;
  bool _isGuestConnecting = false;
  bool _isAudioMuted = false;
  bool _isCameraOff = false;

  // Real-time Stream Subscriptions
  StreamSubscription? _msgSub;
  StreamSubscription? _giftSub;
  StreamSubscription? _joinReqSub;
  StreamSubscription? _joinRespSub;
  StreamSubscription? _coHostAcceptedSub;
  StreamSubscription? _guestKickedSub;
  StreamSubscription? _streamEndedSub;
  StreamSubscription? _cohostStatusSub;
  StreamSubscription? _muteSub;
  StreamSubscription? _likeSub;
  StreamSubscription? _viewerSub;

  @override
  void initState() {
    super.initState();
    _activeLiveId = widget.liveId;
    _activeChannelName = widget.channelName ?? 'live_${widget.host.id}_${DateTime.now().millisecondsSinceEpoch}';

    if (_activeSession != null &&
        (_activeSession!.liveId == widget.liveId || _activeSession!.channelName == _activeChannelName)) {
      _rtcEngine = _activeSession!.rtcEngine;
      _liveKitRoom = _activeSession!.liveKitRoom;
      _hostUid = _activeSession!.hostUid;
      _guestUid = _activeSession!.guestUid;
      _myUid = _activeSession!.myUid;
      _isGuestConnected = _activeSession!.isGuestConnected;
      _viewerCount = _activeSession!.viewerCount;
      _diamondsEarned = _activeSession!.diamondsEarned;
      _isAgoraReady = _rtcEngine != null;
      _isLiveKitConnected = _liveKitRoom != null;
      _activeSession = null;
    } else {
      _initLiveRoom();
    }

    _checkFollowStatus();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _giftSub?.cancel();
    _joinReqSub?.cancel();
    _joinRespSub?.cancel();
    _coHostAcceptedSub?.cancel();
    _guestKickedSub?.cancel();
    _streamEndedSub?.cancel();
    _cohostStatusSub?.cancel();
    _muteSub?.cancel();
    _likeSub?.cancel();
    _viewerSub?.cancel();

    if (PiPCallOverlay.isMinimized && _activeSession != null) {
      debugPrint('[LiveRoomScreen] Preserving RTC engines in background for PiP');
    } else {
      if (_activeLiveId != null) {
        SignalingService().leaveLiveRoom(_activeLiveId);
        LiveStreamingApiService.leaveLiveStream(roomId: _activeLiveId);
      }
      _destroyEngines();
      _activeSession = null;
    }

    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _destroyEngines() async {
    try {
      _liveKitListener?.dispose();
      await _liveKitRoom?.disconnect();
      await _liveKitRoom?.dispose();
      _liveKitRoom = null;
    } catch (_) {}

    try {
      if (_rtcEngine != null) {
        await _rtcEngine!.leaveChannel();
        await _rtcEngine!.release();
        _rtcEngine = null;
      }
    } catch (_) {}
  }

  Future<void> _initLiveRoom() async {
    try {
      final savedUser = await AuthApiService.getSavedUser();
      final myIdRaw = savedUser?['id'] ?? savedUser?['account_id'];
      _myUid = myIdRaw is int ? myIdRaw : (int.tryParse(myIdRaw?.toString() ?? '0') ?? _rnd.nextInt(999999));

      String liveKitToken = '';
      String liveKitUrl = 'wss://chinchins.live/livekit';
      String agoraAppId = 'aab8b8f39d24490b8f4a13d7d792b95b';
      String agoraToken = '';

      if (widget.isHost) {
        // 1. Host starts live broadcast
        final session = widget.initialSessionData ??
            await LiveStreamingApiService.startLiveStream(
              title: widget.title ?? 'Welcome to my official live stream! 🌟',
              coverImageUrl: widget.host.avatarUrl,
            );

        if (session != null) {
          _activeLiveId = session['live_stream_id'] ?? session['id'] ?? _activeLiveId;
          _activeChannelName = session['channel_name']?.toString() ?? _activeChannelName;

          liveKitToken = session['livekit_token']?.toString() ??
              session['token']?.toString() ??
              session['session']?['livekit']?['token']?.toString() ??
              '';
          liveKitUrl = session['livekit_url']?.toString() ??
              session['session']?['livekit']?['url']?.toString() ??
              liveKitUrl;

          final agoraData = session['session']?['agora'] ?? session['agora'];
          if (agoraData is Map) {
            agoraAppId = agoraData['app_id']?.toString() ?? agoraAppId;
            agoraToken = agoraData['token']?.toString() ?? '';
            _myUid = agoraData['uid'] is int ? agoraData['uid'] : (int.tryParse(agoraData['uid']?.toString() ?? '') ?? _myUid);
          }
        }
      } else {
        // 2. Audience joins live broadcast
        if (_activeLiveId != null) {
          final joinData = await LiveStreamingApiService.joinLiveStream(liveStreamId: _activeLiveId);
          if (joinData != null) {
            _activeChannelName = joinData['channel_name']?.toString() ?? _activeChannelName;
            _viewerCount = joinData['viewer_count'] is int ? joinData['viewer_count'] as int : _viewerCount;

            liveKitToken = joinData['livekit_token']?.toString() ??
                joinData['token']?.toString() ??
                joinData['session']?['livekit']?['token']?.toString() ??
                '';
            liveKitUrl = joinData['livekit_url']?.toString() ??
                joinData['session']?['livekit']?['url']?.toString() ??
                liveKitUrl;

            final agoraData = joinData['session']?['agora'] ?? joinData['agora'];
            if (agoraData is Map) {
              agoraAppId = agoraData['app_id']?.toString() ?? agoraAppId;
              agoraToken = agoraData['token']?.toString() ?? '';
              _myUid = agoraData['uid'] is int ? agoraData['uid'] : (int.tryParse(agoraData['uid']?.toString() ?? '') ?? _myUid);
            }
          }
        }
      }

      // If LiveKit token is not in start/join payload, generate from POST /api/live/get-token
      if (liveKitToken.isEmpty && _activeChannelName.isNotEmpty) {
        final tokenRes = await LiveStreamingApiService.generateLiveKitToken(
          roomName: _activeChannelName,
          role: widget.isHost ? 'host' : 'viewer',
        );
        if (tokenRes != null) {
          liveKitToken = tokenRes['token']?.toString() ?? '';
          liveKitUrl = tokenRes['livekit_url']?.toString() ?? liveKitUrl;
        }
      }

      // 3. Connect LiveKit RTC Engine
      if (liveKitToken.isNotEmpty) {
        await _setupLiveKitRTC(
          token: liveKitToken,
          serverUrl: liveKitUrl,
          isHost: widget.isHost,
        );
      }

      // 4. Setup Agora RTC as fallback/dual engine if token available
      if (agoraToken.isNotEmpty || !_isLiveKitConnected) {
        await _setupAgoraRTC(
          appId: agoraAppId,
          token: agoraToken,
          channelName: _activeChannelName,
          uid: _myUid,
          isBroadcaster: widget.isHost,
        );
      }

      // 5. Subscribe to Reverb WebSocket Channel
      final liveRoomKey = _activeLiveId?.toString() ?? widget.host.id;
      await SignalingService().subscribeToLiveRoom(liveRoomKey);
      if (_activeChannelName.isNotEmpty && _activeChannelName != liveRoomKey) {
        await SignalingService().subscribeToLiveRoom(_activeChannelName);
      }
      _subscribeWebSocketEvents();
    } catch (e, st) {
      AppLogger.error('InitLiveRoomError', e, st);
    }
  }

  Future<void> _setupLiveKitRTC({
    required String token,
    required String serverUrl,
    required bool isHost,
  }) async {
    try {
      await [Permission.camera, Permission.microphone].request();

      _liveKitRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );

      _liveKitListener = _liveKitRoom!.createListener();
      _liveKitListener!
        ..on<TrackSubscribedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<LocalTrackPublishedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<LocalTrackUnpublishedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) setState(() {});
        });

      await _liveKitRoom!.connect(serverUrl, token);
      _isLiveKitConnected = true;

      // Host publishes camera and microphone automatically
      if (isHost) {
        await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
        await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[LiveRoomScreen] LiveKit connect error: $e');
    }
  }

  Future<void> _setupAgoraRTC({
    required String appId,
    required String token,
    required String channelName,
    required int uid,
    required bool isBroadcaster,
  }) async {
    try {
      await [Permission.camera, Permission.microphone].request();

      _rtcEngine = createAgoraRtcEngine();
      await _rtcEngine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _rtcEngine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[LiveRoomScreen] Joined Agora Channel: ${connection.channelId} as UID: ${connection.localUid}');
            if (mounted) {
              setState(() => _isAgoraReady = true);
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[LiveRoomScreen] Remote User Joined UID: $remoteUid');
            if (mounted) {
              setState(() {
                if (widget.isHost) {
                  _guestUid = remoteUid;
                  _isGuestConnected = true;
                } else {
                  _hostUid = remoteUid;
                }
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[LiveRoomScreen] Remote User Offline UID: $remoteUid ($reason)');
            if (mounted) {
              setState(() {
                if (_guestUid == remoteUid) {
                  _guestUid = null;
                  _isGuestConnected = false;
                }
                if (_hostUid == remoteUid && !widget.isHost) {
                  _hostUid = null;
                }
              });
            }
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
            final newToken = await StreamingService.refreshAgoraToken(
              channelName: channelName,
              uid: uid,
              role: isBroadcaster ? 'publisher' : 'subscriber',
            );
            if (newToken.isNotEmpty && _rtcEngine != null) {
              await _rtcEngine!.renewToken(newToken);
            }
          },
        ),
      );

      await _rtcEngine!.enableVideo();
      await _rtcEngine!.enableAudio();
      await _rtcEngine!.setDefaultAudioRouteToSpeakerphone(true);
      await _rtcEngine!.setClientRole(
        role: isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      );

      if (isBroadcaster) {
        await _rtcEngine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 30,
            bitrate: 2000,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
        await _rtcEngine!.startPreview();
        if (mounted) {
          setState(() => _isAgoraReady = true);
        }
      }

      await _rtcEngine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          publishCameraTrack: isBroadcaster,
          publishMicrophoneTrack: isBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          enableAudioRecordingOrPlayout: true,
          clientRoleType: isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        ),
      );
    } catch (e) {
      debugPrint('[LiveRoomScreen] Agora setup error: $e');
    }
  }

  void _subscribeWebSocketEvents() {
    final signaling = SignalingService();

    // 1. Live Chat Comments (.chat.message, .message.sent)
    _msgSub = signaling.onLiveMessage.listen((data) {
      if (mounted) {
        setState(() {
          _liveComments.add({
            'user': data['sender_name'] ?? data['user_name'] ?? data['user']?['display_name'] ?? 'Viewer',
            'text': data['message'] ?? '',
            'color': const Color(0xFF00E5FF),
          });
        });
        _scrollToBottom();
      }
    });

    // 2. Live Gifts Broadcast (LiveGiftSentEvent)
    _giftSub = signaling.onLiveGift.listen((data) {
      if (mounted) {
        final giftData = data['gift_data'] ?? data['gift'];
        final giftName = (giftData is Map ? giftData['name'] : null) ?? data['gift_name'] ?? 'Super Gift';
        final senderName = (data['sender'] is Map ? data['sender']['name'] : null) ?? data['sender_name'] ?? data['user_name'] ?? 'Viewer';
        final coins = data['total_coins'] ?? (giftData is Map ? giftData['coin_price'] : null) ?? data['coins'] ?? 100;
        final animUrl = (giftData is Map ? (giftData['animation_asset_url'] ?? giftData['icon_url']) : null) ?? data['animation_url']?.toString() ?? data['animation_asset_url']?.toString() ?? data['image_url']?.toString();

        setState(() {
          _diamondsEarned += (coins is int ? coins : (int.tryParse('$coins') ?? 100));
          _liveComments.add({
            'user': 'System',
            'text': '🎁 $senderName sent a $giftName ($coins 💎)!',
            'color': const Color(0xFFFFD54F),
          });
        });
        _scrollToBottom();

        _giftAnimKey.currentState?.playGiftAnimationDynamic(
          giftName: giftName,
          animationUrl: animUrl,
          senderName: senderName,
          coins: coins is int ? coins : (int.tryParse('$coins') ?? 100),
        );
      }
    });

    // 3. CoHostAcceptedEvent (.cohost.accepted) -> CRITICAL: Auto-publish camera & mic for guest!
    _coHostAcceptedSub = signaling.onCoHostAccepted.listen((data) async {
      final guestUserId = data['guest_user_id'] ?? data['target_user_id'] ?? data['user_id'];
      if (guestUserId != null && guestUserId.toString() == _myUid.toString()) {
        // Guest automatically enables camera & mic on LiveKit without black screen
        if (_liveKitRoom != null) {
          await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
          await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
        }
        if (_rtcEngine != null) {
          await _rtcEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
          await _rtcEngine!.startPreview();
          await _rtcEngine!.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isGuestConnected = true;
            _isGuestConnecting = false;
            _liveComments.add({
              'user': 'System',
              'text': '🎉 Connected as live co-host! 🎙️📹',
              'color': const Color(0xFF00E5FF),
            });
          });
          _scrollToBottom();
        }
      } else if (widget.isHost) {
        if (mounted) {
          setState(() {
            _guestUid = guestUserId is int ? guestUserId : int.tryParse('$guestUserId');
            _isGuestConnected = true;
          });
        }
      }
    });

    // 4. Co-Host Status Changed (.cohost.status.changed)
    _cohostStatusSub = signaling.onCoHostStatusChanged.listen((data) async {
      final action = data['action']?.toString();
      final targetUserId = data['target_user_id'] ?? data['target_user']?['id'] ?? data['user_id'];

      if (action == 'invited' && targetUserId != null && targetUserId.toString() == _myUid.toString()) {
        _showCoHostInviteReceivedDialog(data);
      } else if (action == 'invite' && widget.isHost) {
        final reqId = data['request_id'] ?? data['id'];
        final guestName = data['target_user']?['display_name'] ?? data['user_name'] ?? 'Viewer';
        _showCoHostRequestDialog(requestId: reqId, guestName: guestName, targetUserId: targetUserId);
      } else if (action == 'accepted' || action == 'accept') {
        if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
          if (_liveKitRoom != null) {
            await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
            await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
          }
          if (_rtcEngine != null) {
            await _rtcEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
            await _rtcEngine!.startPreview();
          }
          if (mounted) {
            setState(() {
              _isGuestConnected = true;
              _isGuestConnecting = false;
            });
          }
        } else if (widget.isHost) {
          if (mounted) {
            setState(() {
              _guestUid = targetUserId is int ? targetUserId : int.tryParse('$targetUserId');
              _isGuestConnected = true;
            });
          }
        }
      } else if (action == 'removed' || action == 'reject' || action == 'rejected') {
        if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
          if (_liveKitRoom != null) {
            await _liveKitRoom!.localParticipant?.setCameraEnabled(false);
            await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(false);
          }
          if (_rtcEngine != null) {
            await _rtcEngine!.setClientRole(role: ClientRoleType.clientRoleAudience);
            await _rtcEngine!.stopPreview();
          }
          if (mounted) {
            setState(() {
              _isGuestConnected = false;
              _isGuestConnecting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Co-host session ended.'), backgroundColor: Colors.orange),
            );
          }
        } else if (widget.isHost) {
          if (mounted) {
            setState(() {
              _guestUid = null;
              _isGuestConnected = false;
            });
          }
        }
      }
    });

    // 5. Audio Mute / Unmute (.audio.mute.toggled)
    _muteSub = signaling.onAudioMuteToggled.listen((data) async {
      final targetUserId = data['target_user_id'] ?? data['user_id'];
      final isMuted = data['is_muted'] == true;

      if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
        setState(() => _isAudioMuted = isMuted);
        if (_liveKitRoom != null) {
          await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(!isMuted);
        }
        if (_rtcEngine != null) {
          await _rtcEngine!.muteLocalAudioStream(isMuted);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMuted ? 'Microphone muted.' : 'Microphone unmuted.'),
              backgroundColor: isMuted ? Colors.redAccent : const Color(0xFF00E5FF),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    // 6. Live Stream Ended
    _streamEndedSub = signaling.onLiveStreamEnded.listen((data) {
      if (mounted && !widget.isHost) {
        _showStreamEndedDialog(data);
      }
    });

    // 7. Real-Time Live Likes / Floating Hearts (.live.like)
    _likeSub = signaling.onLiveLike.listen((data) {
      if (mounted) {
        final totalLikes = data['likes_count'] ?? data['total_likes'];
        setState(() {
          if (totalLikes != null) {
            _likeCount = (totalLikes is int) ? totalLikes : (int.tryParse('$totalLikes') ?? _likeCount);
          } else {
            _likeCount++;
          }
          final heart = LiveHeart(
            key: UniqueKey(),
            left: 20.0 + _rnd.nextDouble() * 60.0,
            color: [
              Colors.pinkAccent,
              Colors.redAccent,
              Colors.purpleAccent,
              Colors.amber,
              Colors.cyanAccent,
            ][_rnd.nextInt(5)],
          );
          _hearts.add(heart);
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) {
              setState(() => _hearts.removeWhere((h) => h.key == heart.key));
            }
          });
        });
      }
    });

    // 8. Real-Time Live Viewer Count Updated (.viewer.updated)
    _viewerSub = signaling.onViewerCountUpdated.listen((data) {
      if (mounted) {
        final count = data['viewer_count'] ?? data['count'];
        final action = data['action']?.toString();
        final userObj = data['user'];
        final userName = (userObj is Map ? (userObj['display_name'] ?? userObj['name']) : null) ?? data['user_name'];

        setState(() {
          if (count != null) {
            _viewerCount = (count is int) ? count : (int.tryParse('$count') ?? _viewerCount);
          }
          if (action == 'joined' && userName != null && userName.isNotEmpty) {
            _liveComments.add({
              'user': 'System',
              'text': '🌟 $userName joined the live stream',
              'color': const Color(0xFF69F0AE),
            });
            _scrollToBottom();
          }
        });
      }
    });
  }

  void _showCoHostInviteReceivedDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.video_call_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Co-Host Invitation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Host invited you to join the video broadcast grid as a co-host!',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LiveStreamingApiService.cohostAction(
                roomId: _activeLiveId ?? widget.host.id,
                targetUserId: _myUid,
                action: 'reject',
              );
            },
            child: const Text('Decline', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await LiveStreamingApiService.cohostAction(
                roomId: _activeLiveId ?? widget.host.id,
                targetUserId: _myUid,
                action: 'accept',
              );
              if (_liveKitRoom != null) {
                await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
                await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
              }
              setState(() => _isGuestConnected = true);
            },
            child: const Text('Accept & Join Grid', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCoHostRequestDialog({required dynamic requestId, required String guestName, dynamic targetUserId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.video_call_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Co-Host Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$guestName wants to join your live broadcast as a video co-host.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LiveStreamingApiService.respondJoinCoHost(
                requestId: requestId,
                action: 'reject',
                roomId: _activeLiveId ?? widget.host.id,
                targetUserId: targetUserId,
              );
            },
            child: const Text('Decline', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              LiveStreamingApiService.respondJoinCoHost(
                requestId: requestId,
                action: 'accept',
                roomId: _activeLiveId ?? widget.host.id,
                targetUserId: targetUserId,
              );
            },
            child: const Text('Accept & Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStreamEndedDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Live Stream Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'The host has concluded this live broadcast. Thank you for watching!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkFollowStatus() async {
    try {
      final status = await CallApiService.getFollowStatus(widget.host.id);
      if (mounted) {
        setState(() {
          _isFollowing = status['is_following'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final prev = _isFollowing;
    setState(() => _isFollowing = !prev);
    try {
      if (!prev) {
        await CallApiService.followUser(widget.host.id, source: 'live');
      } else {
        await CallApiService.unfollowUser(widget.host.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = prev);
    }
  }

  void _addHeart() {
    final heart = LiveHeart(
      key: UniqueKey(),
      left: 20.0 + _rnd.nextDouble() * 60.0,
      color: [
        Colors.pinkAccent,
        Colors.redAccent,
        Colors.purpleAccent,
        Colors.amber,
        Colors.cyanAccent,
      ][_rnd.nextInt(5)],
    );

    setState(() {
      _likeCount++;
      _hearts.add(heart);
    });

    if (_activeLiveId != null) {
      LiveStreamingApiService.sendLiveLike(roomId: _activeLiveId, count: 1);
    }

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.key == heart.key);
        });
      }
    });
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();

    setState(() {
      _liveComments.add({
        'user': 'You',
        'text': text,
        'color': AppColors.neonPink,
        'isMe': true,
      });
    });
    _scrollToBottom();

    if (_activeLiveId != null) {
      LiveStreamingApiService.sendLiveMessage(roomId: _activeLiveId, message: text);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleAudioMute() async {
    final nextMute = !_isAudioMuted;
    setState(() => _isAudioMuted = nextMute);
    if (_liveKitRoom != null) {
      await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(!nextMute);
    }
    if (_rtcEngine != null) {
      await _rtcEngine!.muteLocalAudioStream(nextMute);
    }
    await LiveStreamingApiService.toggleMute(
      roomId: _activeLiveId ?? widget.host.id,
      targetUserId: _myUid,
      isMuted: nextMute,
      mutedByHost: widget.isHost,
    );
  }

  void _toggleCamera() async {
    final nextOff = !_isCameraOff;
    setState(() => _isCameraOff = nextOff);
    if (_liveKitRoom != null) {
      await _liveKitRoom!.localParticipant?.setCameraEnabled(!nextOff);
    }
    if (_rtcEngine != null) {
      await _rtcEngine!.muteLocalVideoStream(nextOff);
    }
  }

  void _handleCoHostAction() async {
    if (widget.isHost) {
      if (_isGuestConnected && _guestUid != null) {
        await LiveStreamingApiService.kickGuest(
          roomId: _activeLiveId ?? widget.host.id,
          guestUserId: _guestUid!,
        );
        setState(() {
          _isGuestConnected = false;
          _guestUid = null;
        });
      }
    } else {
      if (_isGuestConnected) {
        // Disconnect self from co-host
        if (_liveKitRoom != null) {
          await _liveKitRoom!.localParticipant?.setCameraEnabled(false);
          await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(false);
        }
        if (_rtcEngine != null) {
          await _rtcEngine!.setClientRole(role: ClientRoleType.clientRoleAudience);
          await _rtcEngine!.stopPreview();
        }
        await LiveStreamingApiService.cohostAction(
          roomId: _activeLiveId ?? widget.host.id,
          targetUserId: _myUid,
          action: 'remove',
        );
        setState(() => _isGuestConnected = false);
      } else {
        setState(() => _isGuestConnecting = true);
        final res = await LiveStreamingApiService.requestJoinCoHost(
          roomId: _activeLiveId ?? widget.host.id,
        );
        if (res != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Co-Host request sent! Waiting for host approval...'),
              backgroundColor: Color(0xFF00E5FF),
            ),
          );
        } else if (mounted) {
          setState(() => _isGuestConnecting = false);
        }
      }
    }
  }

  void _minimizeToPiP() {
    _activeSession = ActiveLiveSession(
      liveId: _activeLiveId,
      channelName: _activeChannelName,
      rtcEngine: _rtcEngine,
      liveKitRoom: _liveKitRoom,
      hostUid: _hostUid,
      guestUid: _guestUid,
      myUid: _myUid,
      isGuestConnected: _isGuestConnected,
      viewerCount: _viewerCount,
      diamondsEarned: _diamondsEarned,
    );

    PiPCallOverlay.showMiniWindow(
      context,
      remoteVideoView: RepaintBoundary(child: _buildVideoGrid(isMini: true)),
      peerName: widget.host.name,
      callDurationText: 'LIVE',
      callSessionId: _activeLiveId ?? 'live_${widget.host.id}',
      onTapRestore: () {
        final navState = ChinchinsLiveApp.navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
        navState.push(
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(
              host: widget.host,
              liveId: _activeLiveId,
              channelName: _activeChannelName,
              title: widget.title,
              isHost: widget.isHost,
              initialSessionData: widget.initialSessionData,
            ),
          ),
        );
      },
      onEndCall: () {
        _endLiveSession();
      },
    );
    Navigator.of(context).pop();
  }

  void _endLiveSession() async {
    if (_activeSession != null) {
      await _activeSession!.liveKitRoom?.disconnect();
      await _activeSession!.liveKitRoom?.dispose();
      await _activeSession!.rtcEngine?.leaveChannel();
      await _activeSession!.rtcEngine?.release();
      _activeSession = null;
    }
    if (widget.isHost && _activeLiveId != null) {
      await LiveStreamingApiService.endLiveStream(liveStreamId: _activeLiveId);
    }
  }

  void _handleExitLive() async {
    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;
    if (widget.isHost && _activeLiveId != null) {
      await LiveStreamingApiService.endLiveStream(liveStreamId: _activeLiveId);
    }
    if (mounted) {
      Navigator.pop(context);
    }
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
          body: SafeArea(
            child: Stack(
              children: [
                // Split Screen: 60% Upper Video Grid, 40% Lower Live Chat & Controls
                Column(
                  children: [
                    // 1. UPPER SECTION: Multi-Video Grid (60% Screen Height)
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: const Color(0xFF0F0E17),
                        child: _buildVideoGrid(),
                      ),
                    ),

                    // 2. LOWER SECTION: Live Chat & Controls (40% Screen Height)
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF140F22),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            // Comments List
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _liveComments.length,
                                itemBuilder: (context, index) {
                                  final c = _liveComments[index];
                                  final isMe = c['isMe'] == true;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "${c['user']}: ",
                                            style: TextStyle(
                                              color: isMe ? AppColors.neonPink : (c['color'] as Color? ?? const Color(0xFFFFD54F)),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          TextSpan(
                                            text: c['text']?.toString() ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Bottom Controls & Input Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D0A17),
                                border: Border(top: BorderSide(color: Colors.white10, width: 0.8)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Action Icon Buttons Tray
                                  Row(
                                    children: [
                                      // Co-Host Request / Kick Button
                                      _buildActionButton(
                                        icon: (widget.isHost && _isGuestConnected)
                                            ? Icons.person_remove_rounded
                                            : Icons.video_call_rounded,
                                        label: widget.isHost
                                            ? (_isGuestConnected ? 'Kick' : 'Live')
                                            : (_isGuestConnected ? 'Leave' : 'Join Co-Host'),
                                        color: _isGuestConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                                        isLoading: _isGuestConnecting,
                                        onTap: _handleCoHostAction,
                                      ),
                                      const SizedBox(width: 8),

                                      // Mic Toggle (Host and Co-Host)
                                      if (widget.isHost || _isGuestConnected) ...[
                                        _buildActionButton(
                                          icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                          label: _isAudioMuted ? 'Muted' : 'Mic',
                                          color: _isAudioMuted ? Colors.redAccent : AppColors.onlineGreen,
                                          onTap: _toggleAudioMute,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildActionButton(
                                          icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                          label: _isCameraOff ? 'Cam Off' : 'Camera',
                                          color: _isCameraOff ? Colors.redAccent : const Color(0xFF00E5FF),
                                          onTap: _toggleCamera,
                                        ),
                                        const SizedBox(width: 8),
                                      ],

                                      // Beauty Filter
                                      _buildActionButton(
                                        icon: Icons.auto_fix_high_rounded,
                                        label: 'Beauty',
                                        color: AppColors.neonPink,
                                        onTap: () {
                                          CameraFilterTray.show(
                                            context,
                                            currentFilter: _currentFilter,
                                            onFilterSelected: (p) => setState(() => _currentFilter = p),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),

                                      // Gift Button (Viewers)
                                      if (!widget.isHost) ...[
                                        _buildActionButton(
                                          icon: Icons.card_giftcard_rounded,
                                          label: 'Gift',
                                          color: const Color(0xFFFFD54F),
                                          onTap: () {
                                            InCallGiftSheet.show(
                                              context,
                                              receiverId: widget.host.id,
                                              receiverName: widget.host.name,
                                              callSessionId: _activeLiveId,
                                              streamId: _activeLiveId,
                                              contextType: 'live',
                                              onGiftSent: (anim) => _giftAnimKey.currentState?.playGiftAnimation(anim),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                      ],

                                      // Heart Like Button
                                      _buildActionButton(
                                        icon: Icons.favorite_rounded,
                                        label: '$_likeCount',
                                        color: const Color(0xFFFF007F),
                                        onTap: _addHeart,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Comment Text Input Bar
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 38,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: TextField(
                                            controller: _commentController,
                                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                            decoration: const InputDecoration(
                                              hintText: "Send a public comment...",
                                              hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.only(bottom: 6),
                                            ),
                                            onSubmitted: (_) => _sendComment(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: _sendComment,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.primaryGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Top Floating Header: Host Capsule, Viewer Count, Diamonds, Follow, Close/PiP
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Host Profile Capsule
                      GestureDetector(
                        onTap: () => InCallProfileSheet.show(context, model: widget.host),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarWithFrame(
                                avatarUrl: widget.host.avatarUrl,
                                frameUrl: widget.host.avatarFrameUrl,
                                level: widget.host.currentLevel > 0 ? widget.host.currentLevel : widget.host.level,
                                badgeColor: widget.host.badgeColor,
                                glowColor: widget.host.glowColor,
                                size: 30,
                                showLevelBadge: false,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.host.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 10),
                                      const SizedBox(width: 2),
                                      Text('$_viewerCount', style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                                      if (_diamondsEarned > 0) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 10),
                                        const SizedBox(width: 2),
                                        Text('$_diamondsEarned', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              if (!widget.isHost)
                                GestureDetector(
                                  onTap: _toggleFollow,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: _isFollowing
                                          ? const LinearGradient(colors: [Color(0xFF455A64), Color(0xFF37474F)])
                                          : AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _isFollowing ? 'Joined' : '+ Follow',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // PiP & Close Action Buttons
                      IconButton(
                        icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 20),
                        onPressed: _minimizeToPiP,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onPressed: _handleExitLive,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),

                // Floating Hearts Overlay
                Positioned(
                  right: 20,
                  bottom: 120,
                  width: 80,
                  height: 200,
                  child: Stack(
                    children: _hearts.map((h) {
                      return Positioned(
                        bottom: 0,
                        right: h.left,
                        child: _FloatingHeartWidget(heart: h),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dynamic Multi-Video Grid (Host + Co-Hosts)
  Widget _buildVideoGrid({bool isMini = false}) {
    // 1. Check LiveKit Tracks
    if (_liveKitRoom != null && _isLiveKitConnected) {
      final remoteParticipants = _liveKitRoom!.remoteParticipants.values.toList();
      final localVideoTrack = _liveKitRoom!.localParticipant?.videoTrackPublications.firstOrNull?.track as VideoTrack?;
      final isCoHosting = remoteParticipants.isNotEmpty || _isGuestConnected;

      // Single stream view
      if (!isCoHosting && (widget.isHost || remoteParticipants.isEmpty)) {
        if (widget.isHost && localVideoTrack != null) {
          return BeautyFilterEngine.applyFilterToWidget(
            filter: _currentFilter,
            child: VideoTrackRenderer(localVideoTrack),
          );
        }
        if (remoteParticipants.isNotEmpty) {
          final firstRemoteTrack = remoteParticipants.first.videoTrackPublications.firstOrNull?.track as VideoTrack?;
          if (firstRemoteTrack != null) {
            return BeautyFilterEngine.applyFilterToWidget(
              filter: _currentFilter,
              child: VideoTrackRenderer(firstRemoteTrack),
            );
          }
        }
      }

      // Multi-Stream Grid View (1 Host + Co-Hosts)
      final totalParticipants = 1 + remoteParticipants.length;
      return GridView.builder(
        padding: const EdgeInsets.all(4),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: totalParticipants > 1 ? 2 : 1,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: totalParticipants > 1 ? 1.0 : (9 / 16),
        ),
        itemCount: totalParticipants,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Local Participant (Host or self Co-Host)
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: localVideoTrack != null
                  ? BeautyFilterEngine.applyFilterToWidget(
                      filter: _currentFilter,
                      child: VideoTrackRenderer(localVideoTrack),
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarWithFrame(
                              avatarUrl: widget.host.avatarUrl,
                              size: 48,
                              showLevelBadge: false,
                            ),
                            const SizedBox(height: 6),
                            Text(widget.isHost ? 'Host' : 'You (Co-Host)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
            );
          }

          // Remote Participants (Host or other Co-Hosts)
          final remoteP = remoteParticipants[index - 1];
          final remoteTrack = remoteP.videoTrackPublications.firstOrNull?.track as VideoTrack?;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: remoteTrack != null
                ? VideoTrackRenderer(remoteTrack)
                : Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, color: Colors.white54, size: 36),
                          const SizedBox(height: 4),
                          Text(remoteP.name.isNotEmpty ? remoteP.name : 'Connecting...', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
          );
        },
      );
    }

    // 2. Agora RTC Engine Fallback Grid
    if (_rtcEngine != null && _isAgoraReady) {
      if (widget.isHost) {
        if (!_isGuestConnected) {
          return BeautyFilterEngine.applyFilterToWidget(
            filter: _currentFilter,
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _rtcEngine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          );
        } else {
          return Row(
            children: [
              Expanded(
                child: BeautyFilterEngine.applyFilterToWidget(
                  filter: _currentFilter,
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _rtcEngine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _guestUid != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _rtcEngine!,
                          canvas: VideoCanvas(uid: _guestUid!),
                          connection: RtcConnection(channelId: _activeChannelName),
                        ),
                      )
                    : Container(color: Colors.grey[900], child: const Center(child: Text('Connecting Guest...', style: TextStyle(color: Colors.white70)))),
              ),
            ],
          );
        }
      } else {
        if (!_isGuestConnected) {
          return _hostUid != null
              ? BeautyFilterEngine.applyFilterToWidget(
                  filter: _currentFilter,
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _rtcEngine!,
                      canvas: VideoCanvas(uid: _hostUid!),
                      connection: RtcConnection(channelId: _activeChannelName),
                    ),
                  ),
                )
              : _buildCoverFallback();
        } else {
          return Row(
            children: [
              Expanded(
                child: _hostUid != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _rtcEngine!,
                          canvas: VideoCanvas(uid: _hostUid!),
                          connection: RtcConnection(channelId: _activeChannelName),
                        ),
                      )
                    : _buildCoverFallback(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _rtcEngine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ],
          );
        }
      }
    }

    // 3. Fallback placeholder cover
    return _buildCoverFallback();
  }

  Widget _buildCoverFallback() {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          BeautyFilterEngine.applyFilterToWidget(
            filter: _currentFilter,
            child: CachedImageLoader(
              imageUrl: widget.host.avatarUrl,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black45,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.neonPink, strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Connecting Live Broadcast...', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            else
              Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeartWidget extends StatefulWidget {
  final LiveHeart heart;
  const _FloatingHeartWidget({required this.heart});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _translateY = Tween<double>(begin: 0, end: -180).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)));
    _scale = Tween<double>(begin: 0.4, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Icon(Icons.favorite_rounded, color: widget.heart.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
