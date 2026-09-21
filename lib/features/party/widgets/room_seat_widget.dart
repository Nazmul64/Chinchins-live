import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import 'voice_party_seat_widget.dart';

class RoomSeatWidget extends StatelessWidget {
  final RoomSeat seat;
  final VoidCallback onTap;
  final bool isVideoGrid;
  final bool isTopGifter;

  const RoomSeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
    this.isVideoGrid = false,
    this.isTopGifter = false,
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
      isTopGifter: isTopGifter,
      level: seat.level,
      coinsReceived: seat.coinsReceived,
      onTap: onTap,
    );
  }
}
