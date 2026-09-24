import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveStreamingRoomPage extends StatefulWidget {
  final String roomName;
  final String liveKitToken; // Laravel API থেকে পাওয়া টোকেন
  final bool isHost;
  final String currentUserName;

  const LiveStreamingRoomPage({
    super.key,
    required this.roomName,
    required this.liveKitToken,
    required this.isHost,
    required this.currentUserName,
  });

  @override
  State<LiveStreamingRoomPage> createState() => _LiveStreamingRoomPageState();
}

class _LiveStreamingRoomPageState extends State<LiveStreamingRoomPage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  
  final List<VideoTrack> _remoteVideoTracks = [];
  VideoTrack? _localVideoTrack;
  
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _msgController = TextEditingController();
  bool _isCoHost = false;

  final String liveKitUri = 'wss://chinchins.live/livekit';

  @override
  void initState() {
    super.initState();
    _connectToLiveKit();
  }

  Future<void> _connectToLiveKit() async {
    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParameters(
            dimensions: VideoDimensionsPresets.h720_169,
            encoding: VideoEncoding(
              maxBitrate: 2500 * 1000,
              maxFramerate: 30,
            ),
          ),
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
          videoCodec: 'VP8',
          videoEncoding: VideoEncoding(
            maxBitrate: 2500 * 1000,
            maxFramerate: 30,
          ),
        ),
        defaultAudioPublishOptions: AudioPublishOptions(name: 'mic'),
      ),
    );
    _listener = _room!.createListener();

    _setupLiveKitListeners();

    try {
      // ১. লাইভকিট রুমে কানেক্ট হওয়া
      await _room!.connect(
        liveKitUri,
        widget.liveKitToken,
      );

      // ২. হোস্ট হলে সাথে সাথে ক্যামেরা এবং মাইক চালু করা (সবাই যেন কথা শুনতে পায়)
      if (widget.isHost) {
        await _room!.localParticipant?.setCameraEnabled(true);
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        
        // লোকাল ভিডিও ট্র্যাক ধরা
        final pub = _room!.localParticipant?.videoTrackPublications.firstOrNull;
        if (pub?.track != null) {
          setState(() {
            _localVideoTrack = pub!.track as VideoTrack;
          });
        }
      }
    } catch (e) {
      debugPrint("LiveKit Connection Error: $e");
    }
  }

  void _setupLiveKitListeners() {
    _listener!
      // যখন কোনো রিমোট ইউজার বা হোস্টের ভিডিও পাবলিশ হয়
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() {
            _remoteVideoTracks.add(event.track as VideoTrack);
          });
        }
      })
      // ভিডিও বন্ধ হলে
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() {
            _remoteVideoTracks.remove(event.track);
          });
        }
      })
      // লাইভকিট ডাটা চ্যানেলে মেসেজ বা গিফট আসলে
      ..on<DataReceivedEvent>((event) {
        final decoded = utf8.decode(event.data);
        final data = jsonDecode(decoded);

        if (data['type'] == 'chat') {
          setState(() {
            _chatMessages.add({
              'user': data['user'] ?? 'User',
              'message': data['message'] ?? '',
            });
          });
        } else if (data['type'] == 'gift') {
          _showGiftPopup(data['user'], data['gift_name']);
        }
      });
  }

  // কো-হোস্ট বা লাইভে কথা বলার জন্য জয়েন করা
  Future<void> _joinAsCoHost() async {
    try {
      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      final pub = _room!.localParticipant?.videoTrackPublications.firstOrNull;
      setState(() {
        _isCoHost = true;
        if (pub?.track != null) _localVideoTrack = pub!.track as VideoTrack;
      });
    } catch (e) {
      debugPrint("Co-host publish error: $e");
    }
  }

  // লাইভ চ্যাট মেসেজ সেন্ড করা
  void _sendChatMessage() {
    if (_msgController.text.trim().isEmpty || _room == null) return;

    final payload = jsonEncode({
      'type': 'chat',
      'user': widget.currentUserName,
      'message': _msgController.text.trim(),
    });

    _room!.localParticipant?.publishData(utf8.encode(payload));

    setState(() {
      _chatMessages.add({
        'user': 'Me',
        'message': _msgController.text.trim(),
      });
      _msgController.clear();
    });
  }

  // গিফট সেন্ড করা
  void _sendGift(String giftName) {
    if (_room == null) return;

    final payload = jsonEncode({
      'type': 'gift',
      'user': widget.currentUserName,
      'gift_name': giftName,
    });

    _room!.localParticipant?.publishData(utf8.encode(payload));
    _showGiftPopup('Me', giftName);
  }

  void _showGiftPopup(String sender, String gift) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🎁 $sender sent a $gift!"),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allVideos = [
      if (_localVideoTrack != null) _localVideoTrack as VideoTrack,
      ..._remoteVideoTracks,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ১. উপরের অংশ: ভিডিও গ্রিড (হোস্ট + কো-হোস্ট)
            Expanded(
              flex: 6,
              child: allVideos.isEmpty
                  ? const Center(
                      child: Text(
                        "Connecting Video Stream...",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : GridView.builder(
                      itemCount: allVideos.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: allVideos.length > 1 ? 2 : 1,
                        childAspectRatio: allVideos.length > 1 ? 1.0 : 9 / 16,
                      ),
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.all(2),
                          color: Colors.grey[900],
                          child: VideoTrackRenderer(allVideos[index]),
                        );
                      },
                    ),
            ),

            // ২. নিচের অংশ: লাইভ মেসেজ ও অ্যাকশন বাটন
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: [
                    // চ্যাট লিস্ট
                    Expanded(
                      child: ListView.builder(
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _chatMessages[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              "${msg['user']}: ${msg['message']}",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          );
                        },
                      ),
                    ),

                    // মেসেজ ইনপুট ও কন্ট্রোল বার
                    Row(
                      children: [
                        if (!widget.isHost && !_isCoHost)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                            onPressed: _joinAsCoHost,
                            child: const Text("Join Mic/Video"),
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Say something...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.grey[850],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: _sendChatMessage,
                        ),
                        IconButton(
                          icon: const Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                          onPressed: () => _sendGift("Rose 🌹"),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.redAccent),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
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
