import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectToHostStream();
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
        _isLoading = tracks.isEmpty;
      });
    }
  }

  Future<void> _connectToHostStream() async {
    // 1. Ensure loud speakerphone is on
    try {
      await Hardware.instance.setSpeakerphoneOn(true);
    } catch (e) {
      debugPrint('LiveKit Hardware Speakerphone Error: $e');
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
        await Hardware.instance.setSpeakerphoneOn(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Renderer Layer (1 video -> Full Screen; 2+ videos -> 50/50 Split Screen Grid)
          Positioned.fill(
            child: _activeVideos.isEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.hostImageUrl.isNotEmpty)
                        Image.network(
                          widget.hostImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                        )
                      else
                        Container(color: Colors.black),
                      Container(color: Colors.black45),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.pinkAccent,
                          ),
                        ),
                    ],
                  )
                : _activeVideos.length == 1
                    ? VideoTrackRenderer(
                        _activeVideos.first,
                        fit: VideoViewFit.cover,
                      )
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _activeVideos.length,
                        itemBuilder: (context, index) {
                          return Container(
                            color: Colors.black,
                            child: VideoTrackRenderer(
                              _activeVideos[index],
                              fit: VideoViewFit.cover,
                            ),
                          );
                        },
                      ),
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
