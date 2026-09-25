import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../core/widgets/cached_image_loader.dart';

class LiveViewerScreen extends StatefulWidget {
  final String roomName;
  final String liveKitToken;
  final String hostImageUrl;
  final String? hostName;

  const LiveViewerScreen({
    super.key,
    required this.roomName,
    required this.liveKitToken,
    required this.hostImageUrl,
    this.hostName,
  });

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  List<VideoTrack> _activeVideos = [];

  @override
  void initState() {
    super.initState();
    _connectToHostStream();
  }

  void _updateVideoTracks() {
    if (_room == null) {
      if (mounted) {
        setState(() => _activeVideos = []);
      }
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

  Future<void> _connectToHostStream() async {
    // 1. Ensure loud speakerphone is on
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    } catch (e) {
      debugPrint('LiveKit Audio Speakerphone Error: $e');
    }

    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _listener = _room!.createListener();

    // 2. Setup track listeners
    _listener!
      ..on<TrackSubscribedEvent>((event) => _updateVideoTracks())
      ..on<TrackUnsubscribedEvent>((event) => _updateVideoTracks())
      ..on<LocalTrackPublishedEvent>((event) => _updateVideoTracks())
      ..on<LocalTrackUnpublishedEvent>((event) => _updateVideoTracks())
      ..on<TrackMutedEvent>((event) => _updateVideoTracks())
      ..on<TrackUnmutedEvent>((event) => _updateVideoTracks())
      ..on<ParticipantConnectedEvent>((event) => _updateVideoTracks())
      ..on<ParticipantDisconnectedEvent>((event) => _updateVideoTracks());

    try {
      // 3. Connect to LiveKit server
      await _room!.connect(
        'wss://chinchins.live/livekit',
        widget.liveKitToken,
      );

      // 4. Double check speakerphone after connection
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}

      // 5. Update existing tracks
      _updateVideoTracks();
    } catch (e) {
      debugPrint('LiveKit Viewer Connection Error: $e');
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  Widget _buildMultiHostGrid(List<VideoTrack> activeTracks) {
    if (activeTracks.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred Background Cover
          if (widget.hostImageUrl.isNotEmpty)
            CachedImageLoader(
              imageUrl: widget.hostImageUrl,
              fit: BoxFit.cover,
            )
          else
            Container(color: const Color(0xFF0D0B14)),

          // 2. Glass Blur Effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          // 3. Central Host Avatar with Glowing Ring
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pinkAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.hostImageUrl.isNotEmpty
                        ? CachedImageLoader(imageUrl: widget.hostImageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.person, size: 48, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.hostName != null && widget.hostName!.isNotEmpty)
                  Text(
                    widget.hostName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.pinkAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Connecting HD Stream...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (activeTracks.length == 1) {
      return VideoTrackRenderer(
        activeTracks.first,
        fit: VideoViewFit.cover,
      );
    }

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
          borderRadius: BorderRadius.circular(8),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: VideoTrackRenderer(activeTracks[i], fit: VideoViewFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Renderer Layer (4-5 Participants Multi-Host Grid)
          Positioned.fill(
            child: _buildMultiHostGrid(_activeVideos),
          ),

          // Overlay UI (Header & Comments)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Bottom Chat & Gift
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const TextField(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Say something...',
                              hintStyle: TextStyle(color: Colors.white60),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 28),
                        onPressed: () {},
                      ),
                    ],
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
