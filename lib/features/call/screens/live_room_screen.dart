import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
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
  final RtcEngine rtcEngine;
  final int? hostUid;
  final int? guestUid;
  final int myUid;
  final bool isGuestConnected;
  final int viewerCount;
  final int diamondsEarned;

  ActiveLiveSession({
    required this.liveId,
    required this.channelName,
    required this.rtcEngine,
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
  int _viewerCount = 120;
  int _likeCount = 1580;
  int _diamondsEarned = 0;
  dynamic _activeLiveId;
  String _activeChannelName = '';
  
  // Agora RTC Engine state
  RtcEngine? _rtcEngine;
  bool _isEngineReady = false;
  int? _hostUid;
  int? _guestUid;
  int _myUid = 0;
  bool _isGuestConnected = false;
  bool _isGuestConnecting = false;

  // Real-time Stream Subscriptions
  StreamSubscription? _msgSub;
  StreamSubscription? _giftSub;
  StreamSubscription? _joinReqSub;
  StreamSubscription? _joinRespSub;
  StreamSubscription? _guestKickedSub;
  StreamSubscription? _streamEndedSub;
  StreamSubscription? _cohostStatusSub;
  StreamSubscription? _muteSub;
  StreamSubscription? _likeSub;
  StreamSubscription? _viewerSub;
  bool _isAudioMuted = false;

  @override
  void initState() {
    super.initState();
    _activeLiveId = widget.liveId;
    _activeChannelName = widget.channelName ?? 'live_${widget.host.id}_${DateTime.now().millisecondsSinceEpoch}';
    _viewerCount = 100 + _rnd.nextInt(150);

    _liveComments.addAll([
      {'user': 'Sara', 'text': 'Hello everyone! ❤️', 'color': Colors.pinkAccent},
      {'user': 'Alex', 'text': 'Welcome to live stream! 🔥', 'color': Colors.amberAccent},
      {'user': 'Rohan', 'text': 'You look stunning! ✨', 'color': Colors.cyanAccent},
    ]);

    if (_activeSession != null &&
        (_activeSession!.liveId == widget.liveId || _activeSession!.channelName == _activeChannelName)) {
      _rtcEngine = _activeSession!.rtcEngine;
      _hostUid = _activeSession!.hostUid;
      _guestUid = _activeSession!.guestUid;
      _myUid = _activeSession!.myUid;
      _isGuestConnected = _activeSession!.isGuestConnected;
      _viewerCount = _activeSession!.viewerCount;
      _diamondsEarned = _activeSession!.diamondsEarned;
      _isEngineReady = true;
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
    _guestKickedSub?.cancel();
    _streamEndedSub?.cancel();
    _cohostStatusSub?.cancel();
    _muteSub?.cancel();
    _likeSub?.cancel();
    _viewerSub?.cancel();

    if (PiPCallOverlay.isMinimized && _activeSession != null) {
      debugPrint('[LiveRoomScreen] Preserving RTC engine in background for PiP');
    } else {
      if (_activeLiveId != null) {
        SignalingService().leaveLiveRoom(_activeLiveId);
        LiveStreamingApiService.leaveLiveStream(roomId: _activeLiveId);
      }
      _destroyAgoraEngine();
      _activeSession = null;
    }

    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _destroyAgoraEngine() async {
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

      String agoraAppId = 'aab8b8f39d24490b8f4a13d7d792b95b'; // Default fallback or dynamically loaded
      String rtcToken = '';

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

          final agoraData = session['session']?['agora'] ?? session['agora'];
          if (agoraData is Map) {
            agoraAppId = agoraData['app_id']?.toString() ?? agoraAppId;
            rtcToken = agoraData['token']?.toString() ?? '';
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

            final agoraData = joinData['session']?['agora'] ?? joinData['agora'];
            if (agoraData is Map) {
              agoraAppId = agoraData['app_id']?.toString() ?? agoraAppId;
              rtcToken = agoraData['token']?.toString() ?? '';
              _myUid = agoraData['uid'] is int ? agoraData['uid'] : (int.tryParse(agoraData['uid']?.toString() ?? '') ?? _myUid);
            }
          }
        }
      }

      // 3. Initialize Agora RTC Engine
      await _setupAgoraRTC(
        appId: agoraAppId,
        token: rtcToken,
        channelName: _activeChannelName,
        uid: _myUid,
        isBroadcaster: widget.isHost,
      );

      // 4. Subscribe to Reverb WebSocket Channel
      if (_activeLiveId != null) {
        await SignalingService().subscribeToLiveRoom(_activeLiveId);
        _subscribeWebSocketEvents();
      }
    } catch (e, st) {
      AppLogger.error('InitLiveRoomError', e, st);
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
              setState(() => _isEngineReady = true);
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
          setState(() => _isEngineReady = true);
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
    final liveRoomKey = _activeLiveId?.toString() ?? widget.host.id;
    signaling.subscribeToLiveRoom(liveRoomKey);
    if (_activeChannelName.isNotEmpty && _activeChannelName != liveRoomKey) {
      signaling.subscribeToLiveRoom(_activeChannelName);
    }

    // 1. Live Chat Comments (.message.sent)
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

    // 2. Live Gifts Broadcast (.message.sent with type: gift)
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

        // Trigger dynamic high-motion gift animation overlay
        _giftAnimKey.currentState?.playGiftAnimationDynamic(
          giftName: giftName,
          animationUrl: animUrl,
          senderName: senderName,
          coins: coins is int ? coins : (int.tryParse('$coins') ?? 100),
        );
      }
    });

    // 3. Co-Host Status Changed (.cohost.status.changed)
    _cohostStatusSub = signaling.onCoHostStatusChanged.listen((data) async {
      final action = data['action']?.toString();
      final targetUserId = data['target_user_id'] ?? data['target_user']?['id'] ?? data['user_id'];

      if (action == 'invited' && targetUserId != null && targetUserId.toString() == _myUid.toString()) {
        // Show invitation dialog to guest
        _showCoHostInviteReceivedDialog(data);
      } else if (action == 'invite' && widget.isHost) {
        final reqId = data['request_id'] ?? data['id'];
        final guestName = data['target_user']?['display_name'] ?? data['user_name'] ?? 'Viewer';
        _showCoHostRequestDialog(requestId: reqId, guestName: guestName, targetUserId: targetUserId);
      } else if (action == 'accepted' || action == 'accept') {
        if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
          // Connected as co-host
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
              _guestUid = targetUserId is int ? targetUserId : int.tryParse('$targetUserId');
              _isGuestConnected = true;
            });
          }
        }
      } else if (action == 'removed' || action == 'reject' || action == 'rejected') {
        if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
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

    // 4. Audio Mute / Unmute (.audio.mute.toggled)
    _muteSub = signaling.onAudioMuteToggled.listen((data) async {
      final targetUserId = data['target_user_id'] ?? data['user_id'];
      final isMuted = data['is_muted'] == true;

      if (targetUserId != null && targetUserId.toString() == _myUid.toString()) {
        setState(() => _isAudioMuted = isMuted);
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

    // 5. Live Stream Ended
    _streamEndedSub = signaling.onLiveStreamEnded.listen((data) {
      if (mounted && !widget.isHost) {
        _showStreamEndedDialog(data);
      }
    });

    // 6. Real-Time Live Likes / Floating Hearts (.live.like)
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

    // 7. Real-Time Live Viewer Count Updated (.viewer.updated)
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
            onPressed: () {
              Navigator.pop(ctx);
              LiveStreamingApiService.cohostAction(
                roomId: _activeLiveId ?? widget.host.id,
                targetUserId: _myUid,
                action: 'accept',
              );
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
              if (targetUserId != null) {
                LiveStreamingApiService.cohostAction(
                  roomId: _activeLiveId ?? widget.host.id,
                  targetUserId: targetUserId,
                  action: 'reject',
                );
              }
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
              if (targetUserId != null) {
                LiveStreamingApiService.cohostAction(
                  roomId: _activeLiveId ?? widget.host.id,
                  targetUserId: targetUserId,
                  action: 'accept',
                );
              }
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

  void _handleCoHostAction() async {
    if (widget.isHost) {
      // Host kicking connected guest
      if (_isGuestConnected && _guestUid != null) {
        await LiveStreamingApiService.cohostAction(
          roomId: _activeLiveId ?? widget.host.id,
          targetUserId: _guestUid!,
          action: 'remove',
        );
        setState(() {
          _isGuestConnected = false;
          _guestUid = null;
        });
      }
    } else {
      // Viewer requesting Co-Host
      if (_isGuestConnected) {
        // Disconnect self from co-host
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
        final res = await LiveStreamingApiService.cohostAction(
          roomId: _activeLiveId ?? widget.host.id,
          targetUserId: _myUid,
          action: 'invite',
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

  static void _endActiveLiveSession({dynamic liveId, bool isHost = false}) async {
    if (_activeSession != null) {
      try {
        await _activeSession!.rtcEngine.leaveChannel();
        await _activeSession!.rtcEngine.release();
      } catch (_) {}
      _activeSession = null;
    }
    if (isHost && liveId != null) {
      try {
        await LiveStreamingApiService.endLiveStream(liveStreamId: liveId);
      } catch (_) {}
    }
  }

  void _minimizeToPiP() {
    if (_rtcEngine == null) return;
    _activeSession = ActiveLiveSession(
      liveId: _activeLiveId,
      channelName: _activeChannelName,
      rtcEngine: _rtcEngine!,
      hostUid: _hostUid,
      guestUid: _guestUid,
      myUid: _myUid,
      isGuestConnected: _isGuestConnected,
      viewerCount: _viewerCount,
      diamondsEarned: _diamondsEarned,
    );

    PiPCallOverlay.showMiniWindow(
      context,
      remoteVideoView: RepaintBoundary(child: _buildLiveVideoContent()),
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
        _endActiveLiveSession(liveId: _activeLiveId, isHost: widget.isHost);
      },
    );
    Navigator.of(context).pop();
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
          body: GestureDetector(
            onDoubleTap: _addHeart,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Live Video Broadcaster / Viewer Surface
                _buildLiveVideoContent(),

                // 2. Subtle Gradient Overlay
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xBB000000),
                          Colors.transparent,
                          Color(0xDD000000),
                        ],
                        stops: [0.0, 0.4, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // 3. Multi-Guest Floating Video Box (Co-Hosting Grid)
                if (_isGuestConnected)
                  Positioned(
                    right: 14,
                    top: 140,
                    child: Container(
                      width: 115,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1435),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Guest Camera Preview (Agora or Avatar)
                            _buildGuestVideoContent(),

                            // Guest Tag
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.mic_rounded, color: AppColors.onlineGreen, size: 10),
                                    SizedBox(width: 2),
                                    Text('Guest', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),

                            // Kick / Disconnect Button
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _handleCoHostAction,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. Top Bar: Host Capsule, Viewer Count, Close / PiP
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Host Profile Capsule
                        GestureDetector(
                          onTap: () {
                            InCallProfileSheet.show(context, model: widget.host);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24, width: 1),
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
                                  size: 32,
                                  showLevelBadge: false,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.host.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 11),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$_viewerCount',
                                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        if (_diamondsEarned > 0) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 11),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$_diamondsEarned',
                                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),

                                // Follow Host Button
                                if (!widget.isHost)
                                  GestureDetector(
                                    onTap: _toggleFollow,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: _isFollowing
                                            ? const LinearGradient(colors: [Color(0xFF455A64), Color(0xFF37474F)])
                                            : AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        _isFollowing ? 'Joined' : '+ Follow',
                                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Right: Minimize / PiP & Close Button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // PiP Minimize Button
                            IconButton(
                              icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                              onPressed: _minimizeToPiP,
                            ),
                            // Close / End Button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                              onPressed: _handleExitLive,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Floating Likes / Heart Burst Animations
                Positioned(
                  right: 20,
                  bottom: 140,
                  width: 80,
                  height: 220,
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

                // 6. Floating Live Comments Overlay
                Positioned(
                  left: 12,
                  bottom: 80,
                  right: 70,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _liveComments.length,
                      itemBuilder: (context, index) {
                        final c = _liveComments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12, width: 0.8),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${c['user']}: ',
                                      style: TextStyle(
                                        color: c['color'] as Color? ?? AppColors.neonPink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: c['text']?.toString() ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 7. Right Action Column: Co-Host Connect, Beauty Filters, Gift, Likes
                Positioned(
                  right: 14,
                  bottom: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Multi-Guest Co-Host Button
                      _buildLiveActionButton(
                        icon: _isGuestConnected ? Icons.phone_disabled_rounded : Icons.video_call_rounded,
                        label: widget.isHost
                            ? (_isGuestConnected ? 'Kick Guest' : 'Co-Host')
                            : (_isGuestConnected ? 'Disconnect' : 'Connect'),
                        color: _isGuestConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                        isLoading: _isGuestConnecting,
                        onTap: _handleCoHostAction,
                      ),
                      const SizedBox(height: 12),

                      // Mic Mute / Unmute Button (For Host and Co-Hosts)
                      if (widget.isHost || _isGuestConnected) ...[
                        _buildLiveActionButton(
                          icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _isAudioMuted ? 'Muted' : 'Mic On',
                          color: _isAudioMuted ? Colors.redAccent : AppColors.onlineGreen,
                          onTap: _toggleAudioMute,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Beauty Filter Button
                      _buildLiveActionButton(
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

                      // Gift Button
                      if (!widget.isHost)
                        _buildLiveActionButton(
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
                              onGiftSent: (anim) {
                                _giftAnimKey.currentState?.playGiftAnimation(anim);
                              },
                            );
                          },
                        ),
                      if (!widget.isHost) const SizedBox(height: 12),

                      // Heart Like Tap Button
                      _buildLiveActionButton(
                        icon: Icons.favorite_rounded,
                        label: '$_likeCount',
                        color: const Color(0xFFFF007F),
                        onTap: _addHeart,
                      ),
                    ],
                  ),
                ),

                // 8. Bottom Live Comment Input Bar
                Positioned(
                  bottom: 16,
                  left: 14,
                  right: 14,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Say something nice...',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendComment,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveVideoContent() {
    if (_rtcEngine != null && _isEngineReady) {
      if (widget.isHost) {
        // Local Host Camera Preview
        return BeautyFilterEngine.applyFilterToWidget(
          filter: _currentFilter,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _rtcEngine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        );
      } else if (_hostUid != null) {
        // Remote Host Stream for Viewers
        return BeautyFilterEngine.applyFilterToWidget(
          filter: _currentFilter,
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _rtcEngine!,
              canvas: VideoCanvas(uid: _hostUid!),
              connection: RtcConnection(channelId: _activeChannelName),
            ),
          ),
        );
      }
    }

    // High Quality Stream Cover / Fallback
    return RepaintBoundary(
      child: BeautyFilterEngine.applyFilterToWidget(
        filter: _currentFilter,
        child: CachedImageLoader(
          imageUrl: widget.host.avatarUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildGuestVideoContent() {
    if (_rtcEngine != null && _isEngineReady) {
      if (!widget.isHost && _isGuestConnected) {
        // Local guest preview
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _rtcEngine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      } else if (widget.isHost && _guestUid != null) {
        // Remote guest stream for host
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _rtcEngine!,
            canvas: VideoCanvas(uid: _guestUid!),
            connection: RtcConnection(channelId: _activeChannelName),
          ),
        );
      }
    }

    return CachedImageLoader(
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      fit: BoxFit.cover,
    );
  }

  Widget _buildLiveActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    ),
                  )
                : Icon(icon, color: color, size: 22),
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
