import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';
import '../core/theme/app_colors.dart';

class LiveStreamScreen extends StatefulWidget {
  final String roomToken;
  final bool isHost;
  final String? title;
  final String? hostName;
  final String? hostAvatar;

  const LiveStreamScreen({
    super.key,
    required this.roomToken,
    required this.isHost,
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

  final List<Map<String, String>> _liveMessages = [
    {'user': 'Sara', 'text': 'Welcome to the live stream! 🌟'},
    {'user': 'Alex', 'text': 'Super crystal clear video! 🔥'},
  ];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isCoHost = widget.isHost;
    _initLiveKit();
  }

  void _initLiveKit() async {
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
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) setState(() {});
        });
      setState(() {});
    }
  }

  @override
  void dispose() {
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

    // Collect all active video tracks (local + remote)
    final videoTracks = <VideoTrack>[];

    // Local video track
    final localVideo = _room!.localParticipant?.videoTrackPublications
        .where((t) => t.track != null && t.track is VideoTrack)
        .map((t) => t.track as VideoTrack)
        .toList();
    if (localVideo != null) videoTracks.addAll(localVideo);

    // Remote video tracks from host and co-hosts
    for (var participant in _room!.remoteParticipants.values) {
      for (var publication in participant.videoTrackPublications) {
        if (publication.track != null && publication.track is VideoTrack) {
          videoTracks.add(publication.track as VideoTrack);
        }
      }
    }

    final isBroadcasting = widget.isHost || _isCoHost;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Grid View (1 = Fullscreen, Multi = 2-column Grid)
          videoTracks.isEmpty
              ? Container(
                  color: const Color(0xFF130D21),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.neonPink, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPink.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Waiting for live broadcast video...',
                          style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              : (videoTracks.length == 1
                  ? SizedBox.expand(
                      child: VideoTrackRenderer(videoTracks.first),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: videoTracks.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 9 / 16,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: VideoTrackRenderer(videoTracks[index]),
                        );
                      },
                    )),

          // 2. Top Bar (Host Info, Viewer Count & Close Button)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Host Profile Pill
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
                            radius: 16,
                            backgroundColor: AppColors.neonPink,
                            child: Text(
                              (widget.hostName?.isNotEmpty == true) ? widget.hostName![0].toUpperCase() : 'H',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.hostName ?? 'Live Host',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_room!.remoteParticipants.length + 1} Viewers',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Close / Exit Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. In-Stream Live Chat Overlay
          Positioned(
            left: 14,
            right: 80,
            bottom: 90,
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: _liveMessages.length,
                itemBuilder: (context, index) {
                  final msg = _liveMessages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${msg['user']}: ',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: msg['text'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Bottom Action Bar (Chat Input, Mic/Cam Toggle, Co-Host Join)
          Positioned(
            bottom: 20,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Chat Input Field
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Say something in live...',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 8),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.neonPink, size: 18),
                          onPressed: _sendMessage,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // If Broadcaster: Mic & Camera Toggle
                if (isBroadcasting) ...[
                  GestureDetector(
                    onTap: _toggleMic,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isMicMuted ? const Color(0xFFFF1744) : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(_isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _toggleCamera,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isCameraOff ? const Color(0xFFFF1744) : Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(_isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // If Audience: Request / Join Co-Host Button
                if (!widget.isHost && !_isCoHost)
                  GestureDetector(
                    onTap: () async {
                      await _liveKitService.enableBroadcasting(isAudioOnly: false);
                      setState(() => _isCoHost = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Co-Host', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
