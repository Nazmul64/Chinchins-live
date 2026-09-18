import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import 'voice_party_seat_widget.dart';

class RoomSeatWidget extends StatelessWidget {
  final RoomSeat seat;
  final VoidCallback onTap;
  final bool isVideoGrid;

  const RoomSeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
    this.isVideoGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return VoicePartySeatWidget(
      seatIndex: seat.seatIndex + 1,
      userName: seat.isEmpty ? null : seat.userName,
      avatarUrl: seat.userAvatar,
      frameSvgUrl: seat.frameSvgUrl,
      isSpeaking: seat.isSpeaking,
      isMuted: seat.isMuted,
      isLocked: seat.status == 'locked',
      isHost: seat.isHost,
      coinsReceived: seat.coinsReceived,
      onTap: onTap,
    );
  }
}

