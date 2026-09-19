import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';
import '../core/theme/app_colors.dart';
import '../core/services/signaling_service.dart';
import '../features/auth/services/auth_api_service.dart';
import '../features/call/services/live_streaming_api_service.dart';

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
  final LiveKitService _liveKitService = LiveKitService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isCoHost = false;
  dynamic _myUserId;

  final List<Map<String, String>> _liveMessages = [];
  final TextEditingController _chatController = TextEditingController();
  StreamSubscription? _coHostAcceptedSub;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _isCoHost = widget.isHost;
    _initLiveKit();
    _setupSignalingListeners();
  }

  void _initLiveKit() async {
    final savedUser = await AuthApiService.getSavedUser();
    _myUserId = savedUser?['id'] ?? savedUser?['account_id'];

    // Ensure speakerphone is on
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
      setState(() {});
    }
  }

  void _setupSignalingListeners() {
    // 1. Reverb WebSocket Listener for Co-Host Accept (.cohost.accepted)
    _coHostAcceptedSub = SignalingService().onCoHostAccepted.listen((data) async {
      final guestUserId = data['guest_user_id'] ?? data['target_user_id'] ?? data['user_id'];
      if (guestUserId != null && _myUserId != null && guestUserId.toString() == _myUserId.toString()) {
        await _liveKitService.enableBroadcasting(isAudioOnly: false);
        if (mounted) {
          setState(() {
            _isCoHost = true;
          });
        }
      }
    });

    // 2. Reverb WebSocket Listener for Live Chat (.chat.message, .message.sent)
    _msgSub = SignalingService().onLiveMessage.listen((data) {
      if (mounted) {
        setState(() {
          _liveMessages.add({
            'user': data['sender_name'] ?? data['user_name'] ?? data['user']?['display_name'] ?? 'Viewer',
            'text': data['message'] ?? '',
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _coHostAcceptedSub?.cancel();
    _msgSub?.cancel();
    _listener?.dispose();
    _liveKitService.disconnect();
    _chatController.dispose();
    super.dispose();
  }

  void _toggleMic() async {
    final next = !_isMicMuted;
    setState(() => _isMicMuted = next);
    await _liveKitService.setMicrophoneEnabled(!next);
  }

  void _toggleCamera() async {
    final next = !_isCameraOff;
    setState(() => _isCameraOff = next);
    await _liveKitService.setCameraEnabled(!next);
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _liveMessages.add({'user': 'You', 'text': text});
    });

    if (widget.roomId != null) {
      LiveStreamingApiService.sendLiveMessage(roomId: widget.roomId, message: text);
    }
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

    final localVideoTrack = _room!.localParticipant?.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    final remoteTracks = <VideoTrack>[];
    for (var p in _room!.remoteParticipants.values) {
      for (var pub in p.videoTrackPublications) {
        if (pub.track != null && pub.track is VideoTrack) {
          remoteTracks.add(pub.track as VideoTrack);
        }
      }
    }

    final isBroadcasting = widget.isHost || _isCoHost;
    final List<Widget> videoWidgets = [];

    if (isBroadcasting) {
      if (localVideoTrack != null) {
        videoWidgets.add(
          VideoTrackRenderer(
            localVideoTrack,
            fit: VideoViewFit.cover,
          ),
        );
      }
      for (var track in remoteTracks) {
        videoWidgets.add(
          VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
          ),
        );
      }
    } else {
      // Viewer mode: only show remote tracks
      for (var track in remoteTracks) {
        videoWidgets.add(
          VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // UPPER SECTION: 60% Multi-Video Grid (Host + Co-Hosts)
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: videoWidgets.isEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              if (widget.hostAvatar != null && widget.hostAvatar!.isNotEmpty)
                                Image.network(
                                  widget.hostAvatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
                                )
                              else
                                Container(color: Colors.grey[900]),
                              Container(color: Colors.black45),
                              const Center(
                                child: CircularProgressIndicator(color: AppColors.neonPink),
                              ),
                            ],
                          )
                        : videoWidgets.length == 1
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: videoWidgets.first,
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(4),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: videoWidgets.length,
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: videoWidgets[index],
                                  );
                                },
                              ),
                  ),

                  // Top Header Overlay
                  Positioned(
                    top: 6,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.neonPink,
                                child: Text(
                                  (widget.hostName?.isNotEmpty == true) ? widget.hostName![0].toUpperCase() : 'H',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.hostName ?? 'Live Host',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_room!.remoteParticipants.length + 1} Viewers',
                                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // LOWER SECTION: 40% Live Chat & Controls
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF140F22),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    // Chat Messages List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _liveMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _liveMessages[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${msg['user']}: ",
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                  TextSpan(
                                    text: msg['text'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Controls & Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      color: Colors.grey[950],
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              decoration: const InputDecoration(
                                hintText: "Send a public comment...",
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.neonPink, size: 20),
                            onPressed: _sendMessage,
                          ),

                          // Mic / Cam toggles for Host & Co-Hosts
                          if (widget.isHost || _isCoHost) ...[
                            IconButton(
                              icon: Icon(_isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white70, size: 20),
                              onPressed: _toggleMic,
                            ),
                            IconButton(
                              icon: Icon(_isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, color: Colors.white70, size: 20),
                              onPressed: _toggleCamera,
                            ),
                          ] else ...[
                            // Join Request Button for Viewers
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.neonPink,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                              label: const Text('Join Mic', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                if (widget.roomId != null) {
                                  await LiveStreamingApiService.requestJoinCoHost(roomId: widget.roomId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Join request sent to Host!'), duration: Duration(seconds: 2)),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
