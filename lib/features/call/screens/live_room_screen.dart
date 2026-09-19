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
import '../../../core/services/gifts_api_service.dart';

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
  int _roseComboCount = 0;
  Timer? _roseComboTimer;
  dynamic _activeLiveId;
  String _activeChannelName = '';
  
  // LiveKit RTC State
  Room? _liveKitRoom;
  List<VideoTrack> _activeVideos = [];
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
  StreamSubscription? _seatRequestSub;
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
    _roseComboTimer?.cancel();
    _msgSub?.cancel();
    _giftSub?.cancel();
    _joinReqSub?.cancel();
    _joinRespSub?.cancel();
    _seatRequestSub?.cancel();
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


  void _updateActiveVideoTracks() {
    if (_liveKitRoom == null) {
      if (mounted) setState(() => _activeVideos = []);
      return;
    }

    final List<VideoTrack> tracks = [];

    // Local video track (if published & not muted)
    for (var pub in _liveKitRoom!.localParticipant?.videoTrackPublications ?? []) {
      if (pub.track != null && pub.track is VideoTrack && !pub.muted) {
        tracks.add(pub.track as VideoTrack);
      }
    }

    // Remote participants' video tracks (host + co-hosts)
    for (var participant in _liveKitRoom!.remoteParticipants.values) {
      for (var pub in participant.videoTrackPublications) {
        if (pub.track != null && pub.track is VideoTrack && !pub.muted) {
          tracks.add(pub.track as VideoTrack);
        }
      }
    }

    if (mounted) {
      setState(() {
        _activeVideos = tracks;
      });
    }
  }

  Future<void> _publishGuestCameraAndMic() async {
    try {
      await [Permission.camera, Permission.microphone].request();
      if (_liveKitRoom != null) {
        try {
          await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
          await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
        } catch (e) {
          debugPrint('[LiveRoomScreen] Direct guest publish failed: $e');
        }

        final hasVideo = _liveKitRoom!.localParticipant?.videoTrackPublications.any((p) => p.track != null && !p.muted) ?? false;
        if (!hasVideo && _activeChannelName.isNotEmpty) {
          final tokenRes = await LiveStreamingApiService.generateLiveKitToken(
            roomName: _activeChannelName,
            role: 'co_host',
          );
          if (tokenRes != null && tokenRes['livekit_token'] != null) {
            await _liveKitRoom!.disconnect();
            await _liveKitRoom!.connect('wss://chinchins.live/livekit', tokenRes['livekit_token']!);
            await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
            await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
          }
        }
      }
      _updateActiveVideoTracks();
    } catch (e) {
      debugPrint('[LiveRoomScreen] _publishGuestCameraAndMic error: $e');
    }
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
          _activeChannelName = session['channel_name']?.toString() ?? 
                               session['room_name']?.toString() ?? 
                               _activeChannelName;

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
        final targetStreamId = _activeLiveId ?? widget.channelName ?? widget.host.id;
        final joinData = await LiveStreamingApiService.joinLiveStream(liveStreamId: targetStreamId);
        if (joinData != null) {
          _activeLiveId = joinData['live_stream_id'] ?? joinData['id'] ?? _activeLiveId;
          _activeChannelName = joinData['channel_name']?.toString() ?? 
                               joinData['room_name']?.toString() ?? 
                               _activeChannelName;
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

      // If LiveKit token is not in start/join payload, generate from POST /api/live/get-token
      if (liveKitToken.isEmpty) {
        final queryRoom = _activeChannelName.isNotEmpty 
            ? _activeChannelName 
            : (widget.channelName ?? widget.host.id.toString());

        final tokenRes = await LiveStreamingApiService.generateLiveKitToken(
          roomName: queryRoom,
          role: widget.isHost ? 'host' : 'viewer',
        );
        if (tokenRes != null) {
          liveKitToken = tokenRes['livekit_token']?.toString() ?? tokenRes['token']?.toString() ?? '';
          liveKitUrl = tokenRes['livekit_url']?.toString() ?? liveKitUrl;
          if (tokenRes['channel_name'] != null && tokenRes['channel_name'].toString().isNotEmpty) {
            _activeChannelName = tokenRes['channel_name'].toString();
          } else if (tokenRes['room_name'] != null && tokenRes['room_name'].toString().isNotEmpty) {
            _activeChannelName = tokenRes['room_name'].toString();
          }
        }
      }

      // 3. Connect LiveKit RTC Engine immediately
      if (liveKitToken.isNotEmpty) {
        debugPrint('[LiveRoomScreen] Connecting LiveKit for room: $_activeChannelName');
        await _setupLiveKitRTC(
          token: liveKitToken,
          serverUrl: liveKitUrl,
          isHost: widget.isHost,
        );
      } else {
        debugPrint('[LiveRoomScreen] Warning: LiveKit token is empty!');
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
      // 1. Force audio through loud speakerphone for live stream
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('[LiveRoomScreen] Speakerphone init error: $e');
      }

      if (isHost || _isGuestConnected) {
        await [Permission.camera, Permission.microphone].request();
      }

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
        ..on<TrackSubscribedEvent>((event) => _updateActiveVideoTracks())
        ..on<TrackUnsubscribedEvent>((event) => _updateActiveVideoTracks())
        ..on<LocalTrackPublishedEvent>((event) => _updateActiveVideoTracks())
        ..on<LocalTrackUnpublishedEvent>((event) => _updateActiveVideoTracks())
        ..on<TrackMutedEvent>((event) => _updateActiveVideoTracks())
        ..on<TrackUnmutedEvent>((event) => _updateActiveVideoTracks())
        ..on<ParticipantConnectedEvent>((event) => _updateActiveVideoTracks())
        ..on<ParticipantDisconnectedEvent>((event) => _updateActiveVideoTracks());

      await _liveKitRoom!.connect(serverUrl, token);
      _isLiveKitConnected = true;

      // Ensure speakerphone is maintained after connect
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (_) {}

      // Host or Co-Host publishes camera and microphone automatically
      if (isHost || _isGuestConnected) {
        await _liveKitRoom!.localParticipant?.setCameraEnabled(true);
        await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
      }

      _updateActiveVideoTracks();
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

    // 0. Seat Request Listener for Host
    _seatRequestSub = signaling.onSeatRequest.listen((data) {
      if (mounted && widget.isHost) {
        final guestName = data['user_name'] ?? data['name'] ?? 'Viewer';
        final seatIndex = data['seat_index'] ?? 1;
        final reqId = data['invitation_id'] ?? data['id'] ?? data['request_id'];
        final targetUid = data['user_id'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E2E),
            behavior: SnackBarBehavior.floating,
            content: Text(
              "$guestName requested to join Seat #$seatIndex",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            action: SnackBarAction(
              label: 'ACCEPT',
              textColor: const Color(0xFFFF2D55),
              onPressed: () {
                _showCoHostRequestDialog(
                  requestId: reqId,
                  guestName: guestName,
                  targetUserId: targetUid,
                );
              },
            ),
          ),
        );
      }
    });

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
        await _publishGuestCameraAndMic();
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
    if (widget.isHost) {
      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1435),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'End Live Broadcast?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to end this live streaming session for all viewers?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End Broadcast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (shouldEnd != true) return;
    }

    PiPCallOverlay.hideMiniWindow();
    _activeSession = null;
    if (widget.isHost && _activeLiveId != null) {
      await LiveStreamingApiService.endLiveStream(liveStreamId: _activeLiveId);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _sendQuickRoseGift() async {
    setState(() {
      _roseComboCount++;
      _likeCount += 5;
    });

    _roseComboTimer?.cancel();
    _roseComboTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _roseComboCount = 0);
    });

    _addHeart();

    final now = DateTime.now();
    final timeStr = "${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    setState(() {
      _liveComments.add({
        'user': 'You',
        'avatar': '',
        'text': 'sent 1 Rose 🌹',
        'giftName': 'Rose',
        'isGift': true,
        'time': timeStr,
        'color': const Color(0xFFFF1744),
      });
    });
    _scrollToBottom();

    try {
      final res = await GiftsApiService.sendGift(
        receiverId: widget.host.id,
        giftId: 1,
        quantity: 1,
        context: 'live',
        streamId: _activeLiveId?.toString(),
        callSessionId: _activeLiveId,
      );

      final dynamic giftData = res['gift_data'] ?? res['data'];
      final animUrl = (giftData is Map ? (giftData['animation_asset_url'] ?? giftData['icon_url']) : null) ??
          res['animation_url']?.toString();

      _giftAnimKey.currentState?.playGiftAnimationDynamic(
        giftName: 'Rose',
        animationUrl: animUrl,
        senderName: 'You',
        coins: 10,
        combo: _roseComboCount > 0 ? _roseComboCount : 1,
      );
    } catch (_) {}
  }

  void _shareLiveStream() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Live stream link for ${widget.host.name} copied to clipboard! 🔗'),
        backgroundColor: const Color(0xFFFF1744),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMoreControlsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Live Controls & Settings',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Co-Host
                    _buildModalControlItem(
                      icon: (widget.isHost && _isGuestConnected) ? Icons.person_remove_rounded : Icons.video_call_rounded,
                      label: widget.isHost ? (_isGuestConnected ? 'Kick Co-Host' : 'Co-Host Live') : (_isGuestConnected ? 'Leave Co-Host' : 'Join Co-Host'),
                      color: _isGuestConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleCoHostAction();
                      },
                    ),

                    // Mic
                    if (widget.isHost || _isGuestConnected)
                      _buildModalControlItem(
                        icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isAudioMuted ? 'Unmute' : 'Mute Mic',
                        color: _isAudioMuted ? Colors.redAccent : const Color(0xFF00E676),
                        onTap: () {
                          _toggleAudioMute();
                          setModalState(() {});
                        },
                      ),

                    // Camera
                    if (widget.isHost || _isGuestConnected)
                      _buildModalControlItem(
                        icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        label: _isCameraOff ? 'Turn Cam On' : 'Turn Cam Off',
                        color: _isCameraOff ? Colors.redAccent : const Color(0xFF00E5FF),
                        onTap: () {
                          _toggleCamera();
                          setModalState(() {});
                        },
                      ),

                    // Beauty Filter
                    _buildModalControlItem(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Beauty Glow',
                      color: const Color(0xFFFF1744),
                      onTap: () {
                        Navigator.pop(ctx);
                        CameraFilterTray.show(
                          context,
                          currentFilter: _currentFilter,
                          onFilterSelected: (p) => setState(() => _currentFilter = p),
                        );
                      },
                    ),

                    // PiP Mini
                    _buildModalControlItem(
                      icon: Icons.picture_in_picture_alt_rounded,
                      label: 'Mini Window',
                      color: Colors.amberAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _minimizeToPiP();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalControlItem({
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
              // 1. Fullscreen Live Video Stream
              _buildVideoGrid(),

              // 2. Subtle Gradient Overlay for Top Header and Bottom Chat readability
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x99000000),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xDD000000),
                        ],
                        stops: [0.0, 0.2, 0.62, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Top Floating Header: Host Capsule, Viewer Count, LIVE Badge, Follow, Top 1 Fan, Avatar Stack, Options, Close
              _buildTopFloatingHeader(),

              // 4. Live Chat Floating Stream (Bottom-Left)
              _buildFloatingChatStream(),

              // 5. Floating Rising Love Hearts Overlay (Right side)
              _buildFloatingHeartsOverlay(),

              // 6. Rose Combo Multiplier Badge
              if (_roseComboCount > 0) _buildRoseComboBadge(),

              // 7. Bottom Floating Action Bar: Emoji + "Type a message..." + Send + Gift + Rose + Share
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Floating Bar matching Screenshot 2 (100% responsive across all screens)
  Widget _buildTopFloatingHeader() {
    return Positioned(
      top: 6,
      left: 8,
      right: 8,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // 1. Host Profile Capsule (Flexible to avoid overflowing right side buttons)
                Flexible(
                  child: GestureDetector(
                    onTap: () => InCallProfileSheet.show(context, model: widget.host),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Host Avatar with Pink/Crimson Ring
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFF1744), width: 1.5),
                            ),
                            child: ClipOval(
                              child: CachedImageLoader(
                                imageUrl: widget.host.avatarUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.host.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFFFF1744), size: 10),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 9),
                                    const SizedBox(width: 2),
                                    Text(
                                      _viewerCount > 999 ? "${(_viewerCount / 1000).toStringAsFixed(1)}K" : '$_viewerCount',
                                      style: const TextStyle(color: Colors.white70, fontSize: 8.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Red LIVE Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1744),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 4),
                                SizedBox(width: 2),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (!widget.isHost) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: _isFollowing
                                      ? const LinearGradient(colors: [Color(0xFF455A64), Color(0xFF37474F)])
                                      : const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF007F)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _isFollowing ? 'Joined' : '+ Follow',
                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // 2. Right Side Controls (Viewers, 3-dots, Close) - Fixed, won't overflow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Viewer Avatars Stack
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 34,
                            height: 18,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: _buildMiniAvatar(widget.host.avatarUrl),
                                ),
                                Positioned(
                                  left: 8,
                                  child: _buildMiniAvatar('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
                                ),
                                Positioned(
                                  left: 16,
                                  child: _buildMiniAvatar('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _viewerCount > 999 ? "${(_viewerCount / 1000).toStringAsFixed(1)}K" : '$_viewerCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),

                    // Options Menu Button (3-dots)
                    GestureDetector(
                      onTap: _showMoreControlsSheet,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 3),

                    // Close Button (Always visible on all screens)
                    GestureDetector(
                      onTap: _handleExitLive,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Gold Top 1 Badge Capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4), width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👑', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 4),
                  Text(
                    'Top 1',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar(String url) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: ClipOval(
        child: CachedImageLoader(imageUrl: url, fit: BoxFit.cover),
      ),
    );
  }

  /// Live Chat Floating Stream (Bottom-Left, Semi-Transparent, matching Screenshot 2)
  Widget _buildFloatingChatStream() {
    return Positioned(
      left: 12,
      bottom: 74,
      width: MediaQuery.of(context).size.width * 0.72,
      height: 240,
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black],
            stops: [0.0, 0.18, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _liveComments.length,
          itemBuilder: (context, index) {
            final c = _liveComments[index];
            return _buildCommentItem(c);
          },
        ),
      ),
    );
  }

  /// Comment row bubble matching Screenshot 2
  Widget _buildCommentItem(Map<String, dynamic> c) {
    final isGift = c['isGift'] == true;
    final isMe = c['isMe'] == true;
    final avatarUrl = c['avatar']?.toString() ?? '';
    final userName = c['user']?.toString() ?? 'Viewer';
    final messageText = c['text']?.toString() ?? '';
    final timeStr = c['time']?.toString() ?? '';

    if (isGift) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6A1B29).withValues(alpha: 0.85),
              const Color(0xFF2E0C16).withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              userName,
              style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                messageText,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Text('🌹', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar Circle
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isMe ? const Color(0xFFFF1744) : Colors.white24,
                width: 1.0,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? CachedImageLoader(imageUrl: avatarUrl, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF2A2438),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 7),

          // Name + Time & Message
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: isMe ? const Color(0xFFFF5252) : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  messageText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Love Hearts Overlay
  Widget _buildFloatingHeartsOverlay() {
    return Positioned(
      right: 14,
      bottom: 120,
      width: 70,
      height: 220,
      child: IgnorePointer(
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
    );
  }

  /// Rose Combo Counter Badge matching Screenshot 2
  Widget _buildRoseComboBadge() {
    return Positioned(
      right: 68,
      bottom: 74,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.15),
        duration: const Duration(milliseconds: 150),
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF1744), Color(0xFFFF007F)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌹', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
                Text(
                  'x$_roseComboCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom Floating Action Bar matching Screenshot 2
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Emoji / Comment Input Pill
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  children: [
                    // Emoji Icon
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white70, size: 20),
                      onPressed: () {
                        _commentController.text += '❤️';
                        _sendComment();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 2),

                    // Input Text
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 11.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),

                    // Send Button
                    GestureDetector(
                      onTap: _sendComment,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF1744), Color(0xFFFF007F)],
                          ),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Gift Button
            _buildCircleActionItem(
              icon: Icons.card_giftcard_rounded,
              label: 'Gift',
              color: const Color(0xFFFF1744),
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
            const SizedBox(width: 6),

            // Rose Quick Gift Button
            _buildCircleActionItem(
              emoji: '🌹',
              label: 'Rose',
              color: const Color(0xFFFF1744),
              onTap: _sendQuickRoseGift,
            ),
            const SizedBox(width: 6),

            // Share Button
            _buildCircleActionItem(
              icon: Icons.reply_rounded,
              label: 'Share',
              color: Colors.white70,
              onTap: _shareLiveStream,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleActionItem({
    IconData? icon,
    String? emoji,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Center(
              child: emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 18))
                  : Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Dynamic Multi-Video Grid (Host + Co-Hosts)
    /// 5-User Dynamic Grid Layout (Top 2 users with flex 3, Bottom up to 3 users with flex 2)
  Widget buildFiveUserGrid(List<VideoTrack> videoTracks) {
    if (videoTracks.length == 1) {
      return BeautyFilterEngine.applyFilterToWidget(
        filter: _currentFilter,
        child: VideoTrackRenderer(
          videoTracks[0],
          fit: VideoViewFit.cover,
        ),
      );
    }

    if (videoTracks.length == 2) {
      return Row(
        children: [
          Expanded(
            child: VideoTrackRenderer(
              videoTracks[0],
              fit: VideoViewFit.cover,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: VideoTrackRenderer(
              videoTracks[1],
              fit: VideoViewFit.cover,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Upper Row: Host & 1st Co-Host (2 users, flex 3)
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  child: VideoTrackRenderer(
                    videoTracks[0],
                    fit: VideoViewFit.cover,
                  ),
                ),
              ),
              if (videoTracks.length > 1)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    child: VideoTrackRenderer(
                      videoTracks[1],
                      fit: VideoViewFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lower Row: Remaining Co-Hosts (up to 3 users, flex 2)
        if (videoTracks.length > 2)
          Expanded(
            flex: 2,
            child: Row(
              children: videoTracks
                  .sublist(2, videoTracks.length > 5 ? 5 : videoTracks.length)
                  .map((track) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    child: VideoTrackRenderer(
                      track,
                      fit: VideoViewFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

Widget _buildVideoGrid({bool isMini = false}) {
    // 1. Check LiveKit Tracks
    if (_liveKitRoom != null && _isLiveKitConnected) {
      if (_activeVideos.isNotEmpty) {
        return buildFiveUserGrid(_activeVideos);
      }
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x33000000),
                  Color(0x66000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.neonPink,
                  strokeWidth: 2.2,
                ),
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
