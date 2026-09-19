import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';
import '../core/theme/app_colors.dart';

class VoiceChatRoomScreen extends StatefulWidget {
  final String roomToken;
  final bool isHost;
  final String? roomTitle;
  final int totalSeats;

  const VoiceChatRoomScreen({
    super.key,
    required this.roomToken,
    required this.isHost,
    this.roomTitle = 'Group Voice Room (8-16 Seats)',
    this.totalSeats = 16,
  });

  @override
  State<VoiceChatRoomScreen> createState() => _VoiceChatRoomScreenState();
}

class _VoiceChatRoomScreenState extends State<VoiceChatRoomScreen> {
  final LiveKitService _liveKitService = LiveKitService();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool isMuted = false;
  bool _amIOnSeat = false;

  final List<String> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amIOnSeat = widget.isHost;
    _connectVoiceRoom();
  }

  void _connectVoiceRoom() async {
    _room = await _liveKitService.connectToRoom(
      token: widget.roomToken,
      isHost: widget.isHost,
      isAudioOnly: true,
    );

    if (_room != null && mounted) {
      _listener = _room!.createListener();
      _listener!
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<TrackMutedEvent>((event) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnmutedEvent>((event) {
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

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _chatMessages.add('💬 $text');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF130D21),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.gemYellow),
              SizedBox(height: 16),
              Text(
                'Connecting Voice Chat Room...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final participants = <Participant>[];
    if (_room!.localParticipant != null) {
      participants.add(_room!.localParticipant!);
    }
    participants.addAll(_room!.remoteParticipants.values);

    return Scaffold(
      backgroundColor: const Color(0xFF130D21),
      appBar: AppBar(
        title: Text(
          widget.roomTitle ?? 'Voice Party Room',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1F1735),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, color: AppColors.gemYellow, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${participants.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 8 to 16 Seats Grid (4 columns)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.totalSeats,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                if (index < participants.length) {
                  final p = participants[index];
                  final hasMic = p.isMicrophoneEnabled();
                  final isLocal = p is LocalParticipant;

                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                p.identity.isNotEmpty ? p.identity[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: hasMic ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Icon(
                              hasMic ? Icons.mic : Icons.mic_off,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isLocal ? 'You' : (p.identity.length > 8 ? p.identity.substring(0, 8) : p.identity),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }

                // Empty Seat (Click to take seat & enable mic)
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _liveKitService.enableBroadcasting(isAudioOnly: true);
                        setState(() => _amIOnSeat = true);
                      },
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF251E36),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white38, size: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seat ${index + 1}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Chat messages strip
          Container(
            height: 90,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _chatMessages[index],
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                );
              },
            ),
          ),

          // 3. Bottom Toolbar (Mic toggle, Chat input, Leave)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1F1735),
              border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Mic Mute / Unmute Toggle Button
                  if (_amIOnSeat)
                    GestureDetector(
                      onTap: () async {
                        final nextMute = !isMuted;
                        setState(() => isMuted = nextMute);
                        await _liveKitService.setMicrophoneEnabled(!nextMute);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMuted ? const Color(0xFFFF1744) : const Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  if (_amIOnSeat) const SizedBox(width: 10),

                  // Chat Input Field
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Send message...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 8),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.gemYellow, size: 16),
                            onPressed: _sendMessage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Leave Room Button
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Leave'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
