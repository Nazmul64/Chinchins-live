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
  VideoTrack? _remoteHostVideoTrack;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectToHostStream();
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
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() {
            _remoteHostVideoTrack = event.track as VideoTrack;
            _isLoading = false;
          });
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() {
            _remoteHostVideoTrack = null;
          });
        }
      });

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

      // 5. If host already published video before viewer connected
      for (var participant in _room!.remoteParticipants.values) {
        for (var pub in participant.videoTrackPublications) {
          if (pub.track != null && pub.track is VideoTrack) {
            setState(() {
              _remoteHostVideoTrack = pub.track as VideoTrack;
              _isLoading = false;
            });
            break;
          }
        }
      }
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
          // Video Renderer Layer
          Positioned.fill(
            child: _remoteHostVideoTrack != null
                ? VideoTrackRenderer(
                    _remoteHostVideoTrack!,
                    fit: VideoViewFit.cover,
                  )
                : Stack(
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
