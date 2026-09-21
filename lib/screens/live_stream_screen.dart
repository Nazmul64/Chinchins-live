import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';
import '../core/theme/app_colors.dart';
import '../core/services/signaling_service.dart';
import '../features/auth/services/auth_api_service.dart';
import '../features/call/services/live_streaming_api_service.dart';
import '../features/call/widgets/in_call_gift_sheet.dart';
import '../features/call/widgets/gift_animation_overlay.dart';

class LiveStreamScreen extends StatefulWidget {
  final String roomToken;
  final bool isHost;
  final String? roomId;
  final String? title;
  final String? hostName;
  final String? hostAvatar;

  const LiveStreamScreen({
    super.key,
    required this.roomToken,
    required this.isHost,
    this.roomId,
    this.title,
    this.hostName,
    this.hostAvatar,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final GlobalKey<GiftAnimationOverlayState> _giftAnimKey = GlobalKey<GiftAnimationOverlayState>();
  final LiveKitService _liveKitService = LiveKitService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  List<VideoTrack> _activeVideos = [];
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isCoHost = false;
  dynamic _myUserId;

  final List<Map<String, String>> _liveMessages = [
    {'user': 'Arif', 'text': 'Wow! Great stream! 🔥'},
    {'user': 'Maya', 'text': 'Hi everyone! 👏'},
    {'user': 'Tuhin', 'text': 'Joined the live room'},
    {'user': 'Nusrat', 'text': 'This is so cool! 💖'},
    {'user': 'Rafi', 'text': 'Nice vibes!'},
  ];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<Map<String, dynamic>> _cohostRequests = [];
  StreamSubscription? _cohostStatusSub;
  StreamSubscription? _coHostAcceptedSub;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _isCoHost = widget.isHost;
    _initLiveKit();
    _setupSignalingListeners();
  }

  void _updateVideoTracks() {
    if (_room == null) {
      if (mounted) setState(() => _activeVideos = []);
      return;
    }

    final List<VideoTrack> tracks = [];

    // Local video track (if published & not muted)
    for (var pub in _room!.localParticipant?.videoTrackPublications ?? []) {
      if (pub.track != null && pub.track is VideoTrack && !pub.muted) {
        tracks.add(pub.track as VideoTrack);
      }
    }

    // Remote participants' video tracks (host + co-hosts)
    for (var participant in _room!.remoteParticipants.values) {
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

  void _initLiveKit() async {
    final savedUser = await AuthApiService.getSavedUser();
    _myUserId = savedUser?['id'] ?? savedUser?['account_id'];

    // Ensure loudspeaker is on
    try {
      await Hardware.instance.setSpeakerphoneOn(true);
    } catch (e) {
      debugPrint('LiveStreamScreen speakerphone error: $e');
    }

    _room = await _liveKitService.connectToRoom(
      token: widget.roomToken,
      isHost: widget.isHost,
      isAudioOnly: false,
    );

    if (_room != null && mounted) {
      _listener = _room!.createListener();
      _listener!
        ..on<TrackSubscribedEvent>((event) => _updateVideoTracks())
        ..on<TrackUnsubscribedEvent>((event) => _updateVideoTracks())
        ..on<LocalTrackPublishedEvent>((event) => _updateVideoTracks())
        ..on<LocalTrackUnpublishedEvent>((event) => _updateVideoTracks())
        ..on<TrackMutedEvent>((event) => _updateVideoTracks())
        ..on<TrackUnmutedEvent>((event) => _updateVideoTracks())
        ..on<ParticipantConnectedEvent>((event) => _updateVideoTracks())
        ..on<ParticipantDisconnectedEvent>((event) => _updateVideoTracks());

      _updateVideoTracks();
    }
  }

  void _setupSignalingListeners() {
    // 1. Reverb WebSocket Listener for Co-Host Accept (.cohost.accepted)
    _coHostAcceptedSub = SignalingService().onCoHostAccepted.listen((data) async {
      final guestUserId = data['guest_user_id'] ?? data['target_user_id'] ?? data['user_id'];
      if (guestUserId != null && _myUserId != null && guestUserId.toString() == _myUserId.toString()) {
        await _room?.localParticipant?.setCameraEnabled(true);
        await _room?.localParticipant?.setMicrophoneEnabled(true);
        await _liveKitService.enableBroadcasting(isAudioOnly: false);
        if (mounted) {
          setState(() {
            _isCoHost = true;
          });
        }
        _updateVideoTracks();
      }
    });

    // 2. Co-Host Request / Status Changed (.cohost.status.changed, .request.received)
    _cohostStatusSub = SignalingService().onCoHostStatusChanged.listen((data) {
      if (widget.isHost && mounted) {
        final reqId = data['request_id'] ?? data['id'] ?? DateTime.now().millisecondsSinceEpoch;
        final guestName = data['guest_name'] ?? data['user_name'] ?? data['sender_name'] ?? 'Viewer';
        final guestAvatar = data['guest_avatar'] ?? data['avatar'] ?? '';
        final targetUserId = data['guest_user_id'] ?? data['user_id'] ?? data['target_user_id'];

        setState(() {
          final existing = _cohostRequests.indexWhere((r) => (r['target_user_id'] ?? r['user_id'])?.toString() == targetUserId?.toString());
          if (existing == -1) {
            _cohostRequests.add({
              'request_id': reqId,
              'user_name': guestName,
              'avatar': guestAvatar,
              'target_user_id': targetUserId,
            });
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 $guestName requested to join co-host!'),
            backgroundColor: AppColors.neonPink,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _showJoinRequestsBottomSheet(context),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // 3. Reverb WebSocket Listener for Live Chat (.chat.message, .message.sent)
    _msgSub = SignalingService().onLiveMessage.listen((data) {
      if (mounted) {
        setState(() {
          _liveMessages.add({
            'user': data['sender_name'] ?? data['user_name'] ?? data['user']?['display_name'] ?? 'Viewer',
            'text': data['message'] ?? '',
          });
        });
        _scrollChatToBottom();
      }
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 40,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _coHostAcceptedSub?.cancel();
    _cohostStatusSub?.cancel();
    _msgSub?.cancel();
    _listener?.dispose();
    _liveKitService.disconnect();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _showJoinRequestsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1735),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int participantsCount = (_room?.remoteParticipants.length ?? 0) + 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group_rounded, color: AppColors.neonPink, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Live Participants ($participantsCount)',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),

                  if (widget.isHost && _cohostRequests.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Join Requests (${_cohostRequests.length})',
                        style: const TextStyle(color: AppColors.gemYellow, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cohostRequests.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final req = _cohostRequests[index];
                        final name = req['user_name'] ?? 'Viewer';
                        final targetId = req['target_user_id'] ?? req['user_id'];
                        final reqId = req['request_id'];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.neonPink,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: const Text('Requested to join video grid', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await LiveStreamingApiService.respondJoinCoHost(
                                    requestId: reqId,
                                    action: 'accept',
                                    roomId: widget.roomId,
                                    targetUserId: targetId,
                                  );
                                  setState(() => _cohostRequests.removeAt(index));
                                  setModalState(() {});
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await LiveStreamingApiService.respondJoinCoHost(
                                    requestId: reqId,
                                    action: 'reject',
                                    roomId: widget.roomId,
                                    targetUserId: targetId,
                                  );
                                  setState(() => _cohostRequests.removeAt(index));
                                  setModalState(() {});
                                },
                                child: const Text('Reject', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(color: Colors.white12),
                  ],

                  // Viewers / Co-hosts list
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Audience in Room',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.neonPink,
                      child: Text(widget.hostName?.isNotEmpty == true ? widget.hostName![0].toUpperCase() : 'H', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text('${widget.hostName ?? "Host"} (Host)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    trailing: const Icon(Icons.verified_rounded, color: AppColors.gemYellow, size: 18),
                  ),
                  if (_room != null)
                    for (var p in _room!.remoteParticipants.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1),
                          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : (p.identity.isNotEmpty ? p.identity[0].toUpperCase() : 'U'), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(p.name.isNotEmpty ? p.name : p.identity, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(p.isMicrophoneEnabled() ? 'Speaking 🎤' : 'Audience', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: widget.isHost
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  await LiveStreamingApiService.kickGuest(roomId: widget.roomId, guestUserId: p.identity);
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getParticipantName(int index) {
    if (_room == null) {
      final sampleNames = ['Arif', 'Maya', 'Tuhin', 'Nusrat'];
      return index - 1 < sampleNames.length ? sampleNames[index - 1] : 'User ${index + 1}';
    }
    final remoteList = _room!.remoteParticipants.values.toList();
    if (widget.isHost) {
      if (index - 1 >= 0 && index - 1 < remoteList.length) {
        final p = remoteList[index - 1];
        return p.name.isNotEmpty ? p.name : (p.identity.isNotEmpty ? p.identity : 'User ${index + 1}');
      }
    } else {
      if (index == 0) return widget.hostName ?? 'Host';
      if (index - 1 >= 0 && index - 1 < remoteList.length) {
        final p = remoteList[index - 1];
        return p.name.isNotEmpty ? p.name : (p.identity.isNotEmpty ? p.identity : 'User ${index + 1}');
      }
    }
    final sampleNames = ['Arif', 'Maya', 'Tuhin', 'Nusrat'];
    return (index - 1 >= 0 && index - 1 < sampleNames.length) ? sampleNames[index - 1] : 'User ${index + 1}';
  }

  Widget _buildBadge({required String title, required bool isHost}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHost ? AppColors.neonPink.withValues(alpha: 0.6) : Colors.white24,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost) ...[
            const Text('👑 ', style: TextStyle(fontSize: 10)),
            const Text(
              'Host ',
              style: TextStyle(
                color: AppColors.neonPink,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ] else ...[
            const Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            title.length > 8 ? '${title.substring(0, 8)}..' : title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.mic_rounded, color: Color(0xFF00E676), size: 10),
        ],
      ),
    );
  }


  Widget buildMultiHostGrid(List<VideoTrack> activeTracks) {
    if (activeTracks.isEmpty) {
      return (widget.hostAvatar != null && widget.hostAvatar!.isNotEmpty)
          ? Image.network(
              widget.hostAvatar!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF140F22)),
            )
          : Container(color: const Color(0xFF140F22));
    }

    if (activeTracks.length == 1) {
      return Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(
            activeTracks.first,
            fit: VideoViewFit.cover,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _buildBadge(title: widget.hostName ?? 'Riya', isHost: true),
          ),
        ],
      );
    }

    // Multi-Host Responsive Square 2-Column Grid
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: activeTracks.length,
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black,
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoTrackRenderer(
              activeTracks[i],
              fit: VideoViewFit.cover,
            ),
            Positioned(
              top: 6,
              left: 6,
              child: _buildBadge(
                title: i == 0 ? (widget.hostName ?? 'Host') : _getParticipantName(i),
                isHost: i == 0,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMic() async {
    final next = !_isMicMuted;
    setState(() => _isMicMuted = next);
    await _liveKitService.setMicrophoneEnabled(!next);
  }

  void _handleStopVideo() async {
    if (widget.isHost) {
      final next = !_isCameraOff;
      setState(() => _isCameraOff = next);
      await _liveKitService.setCameraEnabled(!next);
      _updateVideoTracks();
    } else if (_isCoHost) {
      // Co-host leaves video grid & returns to regular viewer
      await _liveKitService.setCameraEnabled(false);
      await _liveKitService.setMicrophoneEnabled(false);
      setState(() {
        _isCoHost = false;
      });
      _updateVideoTracks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the video co-host grid.'), duration: Duration(seconds: 2)),
        );
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _liveMessages.add({'user': 'You', 'text': text});
    });
    _scrollChatToBottom();

    if (widget.roomId != null) {
      LiveStreamingApiService.sendLiveMessage(roomId: widget.roomId, message: text);
    }
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0E17),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.neonPink),
              SizedBox(height: 16),
              Text(
                'Connecting LiveKit Broadcast...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final int viewersCount = (_room?.remoteParticipants.length ?? 0) + 1;

    return GiftAnimationOverlay(
      key: _giftAnimKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0813),
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER BAR (Matching Screenshot)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // LIVE Badge & Viewers Count
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.circle, color: Colors.white, size: 6),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              '$viewersCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Room Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title ?? 'Good Vibes Only 🔥',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            "Let's talk • Make friends • Share moments",
                            style: TextStyle(color: Colors.white54, fontSize: 9.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Joined Avatars & Badge + Close Button
                    GestureDetector(
                      onTap: () => _showJoinRequestsBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '$viewersCount joined',
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. MAIN VIDEO GRID (5-Host Multi-Grid: Left Host 50%, Right 2x2 Co-hosts 50%)
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: buildMultiHostGrid(_activeVideos),
                      ),
                    ),

                    // Floating Live Chat Stream over bottom-left of video
                    Positioned(
                      left: 14,
                      bottom: 8,
                      width: MediaQuery.of(context).size.width * 0.44,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          controller: _chatScrollController,
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: _liveMessages.length,
                          itemBuilder: (context, index) {
                            final msg = _liveMessages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${msg['user']}: ",
                                        style: const TextStyle(
                                          color: Color(0xFF60A5FA),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg['text'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. BOTTOM CONTROLS & ACTIONS BAR (Matching Screenshot)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F0C1B),
                  border: Border(top: BorderSide(color: Colors.white10, width: 0.8)),
                ),
                child: Row(
                  children: [
                    // Chat Input Field
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1834),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white54, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action buttons: Mute, Stop Video, Participants, Gift, Share, More
                    _buildBottomActionButton(
                      icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: 'Mute',
                      color: _isMicMuted ? const Color(0xFFFF1744) : Colors.white70,
                      onTap: _toggleMic,
                    ),

                    _buildBottomActionButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      label: 'Stop Video',
                      color: _isCameraOff ? Colors.redAccent : Colors.white70,
                      onTap: _handleStopVideo,
                    ),

                    _buildBottomActionButton(
                      icon: Icons.people_outline_rounded,
                      label: 'Participants',
                      onTap: () => _showJoinRequestsBottomSheet(context),
                    ),

                    _buildBottomActionButton(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Gift',
                      color: AppColors.neonPink,
                      onTap: () {
                        InCallGiftSheet.show(
                          context,
                          receiverId: widget.roomId,
                          receiverName: widget.hostName ?? 'Host',
                          streamId: widget.roomId,
                          contextType: 'live',
                          onGiftSent: (anim) {
                            _giftAnimKey.currentState?.playGiftAnimation(anim);
                          },
                        );
                      },
                    ),

                    _buildBottomActionButton(
                      icon: Icons.reply_rounded,
                      label: 'Share',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Live stream link copied!'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),

                    _buildBottomActionButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      onTap: () => _showJoinRequestsBottomSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
